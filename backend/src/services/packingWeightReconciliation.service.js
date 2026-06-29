/**
 * Packing-time weight reconciliation orchestration.
 * Runs before an order becomes PACKED / dispatchable.
 */

const { withTransaction } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { reconcileLineItemWeight } = require('./weightReconciliation.service');
const {
  WEIGHT_ACTION,
  WEIGHT_RECONCILIATION_STATUS,
  PARTIAL_REFUND_REASON,
  PARTIAL_REFUND_STATUS,
} = require('../constants/weightReconciliation.constants');
const {
  isWeightBasedProduct,
  orderedWeightGramsForLine,
  nextCutAvailableGrams,
  supplementStockDeductionUnits,
} = require('../utils/weightBasedProduct.util');
const { resolveUnitSalePrice } = require('../utils/productPricing.util');
const {
  publishOperationalEventAsync,
  OPERATIONAL_EVENT_TYPES,
  resolveActorType,
} = require('../utils/operationalEvents.util');

const PACKABLE_STATUSES = new Set(['CONFIRMED', 'PACKING_STARTED']);

const normalizeLineWeights = (lineWeights) => {
  const map = new Map();
  const list = Array.isArray(lineWeights) ? lineWeights : [];
  for (const entry of list) {
    const orderItemId = Number(entry?.orderItemId ?? entry?.order_item_id ?? entry?.id);
    const actualWeightG = Number(entry?.actualWeightG ?? entry?.actual_weight_g);
    if (Number.isFinite(orderItemId) && orderItemId > 0) {
      map.set(orderItemId, actualWeightG);
    }
  }
  return map;
};

const recordInventoryMovement = async (client, {
  productId,
  orderId,
  orderItemId,
  movementType,
  quantityGrams,
  metadata = {},
}) => {
  await client.query(
    `INSERT INTO inventory_movements
       (product_id, order_id, order_item_id, movement_type, quantity_grams, metadata)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb)`,
    [
      productId,
      orderId,
      orderItemId,
      movementType,
      quantityGrams,
      JSON.stringify(metadata),
    ]
  );
};

const createPartialRefund = async (client, {
  orderId,
  orderItemId,
  amount,
  paymentMode,
  metadata = {},
}) => {
  if (!(amount > 0)) return null;
  const normalizedMode = String(paymentMode || '').trim().toUpperCase();
  const isOnline = normalizedMode === 'ONLINE';
  const idempotencyKey = isOnline
    ? `wr${orderId}i${orderItemId}`.replace(/[^a-zA-Z0-9]/g, '').slice(0, 40)
    : null;
  const initialStatus = isOnline
    ? PARTIAL_REFUND_STATUS.PENDING
    : PARTIAL_REFUND_STATUS.RECORDED;

  const { rows } = await client.query(
    `INSERT INTO order_partial_refunds
       (order_id, order_item_id, amount, reason, status, payment_mode, idempotency_key, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)
     RETURNING id, amount, status`,
    [
      orderId,
      orderItemId,
      amount,
      PARTIAL_REFUND_REASON,
      initialStatus,
      paymentMode,
      idempotencyKey,
      JSON.stringify(metadata),
    ]
  );
  return rows[0];
};

/**
 * Execute weight reconciliation for all weight-based lines and persist results.
 * Does not transition order status — caller must move to PACKED after success.
 */
async function executePackingWeightReconciliation({
  orderId,
  lineWeights,
  actor,
  io = null,
  skipWeightValidation = false,
}) {
  const weightByItemId = normalizeLineWeights(lineWeights);

  const result = await withTransaction(async (client) => {
    const { rows: orderRows } = await client.query(
      `SELECT id, customer_id, status, total_amount, payment_mode, payment_status,
              weight_reconciliation_status
       FROM orders WHERE id = $1 FOR UPDATE`,
      [orderId]
    );
    const order = orderRows[0];
    if (!order) {
      const err = new Error('Order not found');
      err.statusCode = 404;
      throw err;
    }

    const status = String(order.status || '').toUpperCase();
    if (!PACKABLE_STATUSES.has(status)) {
      const err = new Error(
        `Order must be CONFIRMED or PACKING_STARTED to pack (current: ${status})`
      );
      err.statusCode = 400;
      throw err;
    }

    const reconStatus = String(order.weight_reconciliation_status || '').toUpperCase();
    if (reconStatus === WEIGHT_RECONCILIATION_STATUS.COMPLETED) {
      const err = new Error('Weight reconciliation already completed for this order');
      err.statusCode = 409;
      throw err;
    }

    publishOperationalEventAsync(io, {
      eventType: OPERATIONAL_EVENT_TYPES.WEIGHT_RECONCILIATION_STARTED,
      orderId,
      actorType: resolveActorType('admin'),
      actorId: actor,
      previousState: status,
      newState: status,
      metadata: {},
    });

    const { rows: itemRows } = await client.query(
      `SELECT oi.id, oi.product_id, oi.quantity, oi.price, oi.ordered_weight_g,
              p.name, p.unit, p.stock, p.base_price_per_kg, p.weight_variants, p.price AS product_price
       FROM order_items oi
       JOIN products p ON p.id = oi.product_id
       WHERE oi.order_id = $1
       FOR UPDATE OF oi, p`,
      [orderId]
    );

    if (!itemRows.length) {
      const err = new Error('Order has no line items');
      err.statusCode = 400;
      throw err;
    }

    const lineResults = [];
    let totalRefund = 0;
    let hasWeightLines = false;

    for (const item of itemRows) {
      const product = {
        unit: item.unit,
        stock: item.stock,
        base_price_per_kg: item.base_price_per_kg,
        weight_variants: item.weight_variants,
        price: item.product_price,
      };

      if (!isWeightBasedProduct(product)) {
        await client.query(
          `UPDATE order_items SET
             weight_reconciliation_action = $1,
             reconciled_at = NOW()
           WHERE id = $2`,
          [WEIGHT_ACTION.ACCEPT, item.id]
        );
        lineResults.push({
          orderItemId: Number(item.id),
          productId: Number(item.product_id),
          weightBased: false,
          action: WEIGHT_ACTION.ACCEPT,
          orderedWeightG: null,
          actualWeightG: null,
          refundAmount: 0,
          supplementG: 0,
        });
        continue;
      }

      hasWeightLines = true;

      const orderedWeightG =
        Number(item.ordered_weight_g) > 0
          ? Number(item.ordered_weight_g)
          : orderedWeightGramsForLine(product, item.quantity);

      let actualWeightG = weightByItemId.get(Number(item.id));
      if (!Number.isFinite(actualWeightG) || actualWeightG < 0) {
        if (skipWeightValidation) {
          actualWeightG = orderedWeightG;
        } else {
          const err = new Error(
            `Actual weight is required for weight-based item ${item.id} (${item.name})`
          );
          err.statusCode = 400;
          throw err;
        }
      }

      const unitPricePerKg =
        Number(item.base_price_per_kg) > 0
          ? Number(item.base_price_per_kg)
          : Number(item.product_price) || 0;

      const { rows: lockedProductRows } = await client.query(
        `SELECT stock, weight_variants, base_price_per_kg, price, unit
         FROM products WHERE id = $1 FOR UPDATE`,
        [item.product_id]
      );
      const lockedProduct = lockedProductRows[0];
      const availableG = nextCutAvailableGrams(lockedProduct);

      const reconciliation = reconcileLineItemWeight({
        orderedWeightG,
        actualWeightG,
        unitPricePerKg,
        nextCutAvailableG: availableG,
      });

      let supplementStockUnits = 0;
      if (reconciliation.action === WEIGHT_ACTION.SUPPLEMENT_FROM_NEXT_CUT) {
        supplementStockUnits = supplementStockDeductionUnits(
          reconciliation.supplementG,
          lockedProduct
        );
        if (supplementStockUnits > Number(lockedProduct.stock || 0)) {
          publishOperationalEventAsync(io, {
            eventType: OPERATIONAL_EVENT_TYPES.STOCK_FAILURE,
            orderId,
            actorType: resolveActorType('admin'),
            actorId: actor,
            metadata: {
              stockFailureReason: 'insufficient_stock_for_supplement',
              orderItemId: item.id,
              productId: item.product_id,
              requiredUnits: supplementStockUnits,
              availableStock: Number(lockedProduct.stock || 0),
            },
          });
          const err = new Error(`Insufficient stock to supplement item ${item.id}`);
          err.statusCode = 400;
          throw err;
        }
        const newStock = Number(lockedProduct.stock) - supplementStockUnits;
        await client.query('UPDATE products SET stock = $1 WHERE id = $2', [
          newStock,
          item.product_id,
        ]);
      } else if (
        reconciliation.action === WEIGHT_ACTION.AUTO_REFUND &&
        reconciliation.supplementG > 0
      ) {
        supplementStockUnits = supplementStockDeductionUnits(
          reconciliation.supplementG,
          lockedProduct
        );
        if (supplementStockUnits > 0) {
          const newStock = Math.max(
            0,
            Number(lockedProduct.stock) - supplementStockUnits
          );
          await client.query('UPDATE products SET stock = $1 WHERE id = $2', [
            newStock,
            item.product_id,
          ]);
        }
      }

      await client.query(
        `UPDATE order_items SET
           ordered_weight_g = $1,
           actual_weight_g = $2,
           weight_delta_g = $3,
           supplement_g = $4,
           weight_refund_amount = $5,
           weight_reconciliation_action = $6,
           reconciled_at = NOW()
         WHERE id = $7`,
        [
          reconciliation.orderedWeightG,
          reconciliation.actualWeightG,
          reconciliation.deltaG,
          reconciliation.supplementG,
          reconciliation.refundAmount,
          reconciliation.action,
          item.id,
        ]
      );

      await recordInventoryMovement(client, {
        productId: Number(item.product_id),
        orderId,
        orderItemId: Number(item.id),
        movementType: 'PACK_CONSUMPTION',
        quantityGrams: reconciliation.actualWeightG + reconciliation.supplementG,
        metadata: {
          orderedWeightG: reconciliation.orderedWeightG,
          actualWeightG: reconciliation.actualWeightG,
          supplementG: reconciliation.supplementG,
          action: reconciliation.action,
        },
      });

      if (reconciliation.supplementG > 0) {
        await recordInventoryMovement(client, {
          productId: Number(item.product_id),
          orderId,
          orderItemId: Number(item.id),
          movementType: 'SUPPLEMENT_DEDUCTION',
          quantityGrams: reconciliation.supplementG,
          metadata: { supplementStockUnits },
        });
      }

      await client.query(
        `INSERT INTO order_weight_reconciliations
           (order_id, order_item_id, ordered_weight_g, actual_weight_g, delta_g,
            supplement_g, refund_amount, reconciliation_action, reconciled_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [
          orderId,
          item.id,
          reconciliation.orderedWeightG,
          reconciliation.actualWeightG,
          reconciliation.deltaG,
          reconciliation.supplementG,
          reconciliation.refundAmount,
          reconciliation.action,
          actor,
        ]
      );

      if (reconciliation.refundAmount > 0) {
        await createPartialRefund(client, {
          orderId,
          orderItemId: Number(item.id),
          amount: reconciliation.refundAmount,
          paymentMode: order.payment_mode,
          metadata: {
            orderedWeightG: reconciliation.orderedWeightG,
            actualWeightG: reconciliation.actualWeightG,
            deltaG: reconciliation.deltaG,
            supplementG: reconciliation.supplementG,
          },
        });
        totalRefund += reconciliation.refundAmount;
      }

      lineResults.push({
        orderItemId: Number(item.id),
        productId: Number(item.product_id),
        productName: item.name,
        weightBased: true,
        ...reconciliation,
      });
    }

    const newTotal = Math.max(
      0,
      Math.round((Number(order.total_amount) - totalRefund) * 100) / 100
    );

    const finalReconStatus = hasWeightLines
      ? WEIGHT_RECONCILIATION_STATUS.COMPLETED
      : WEIGHT_RECONCILIATION_STATUS.NOT_REQUIRED;

    await client.query(
      `UPDATE orders SET
         total_amount = $1,
         weight_reconciliation_status = $2,
         weight_reconciliation_completed_at = NOW(),
         weight_reconciliation_total_refund = $3,
         packed_at = NOW(),
         updated_at = NOW()
       WHERE id = $4`,
      [newTotal, finalReconStatus, totalRefund, orderId]
    );

    return {
      orderId,
      lineResults,
      totalRefund,
      newTotal,
      weightReconciliationStatus: finalReconStatus,
      paymentMode: order.payment_mode,
      customerId: order.customer_id,
    };
  });

  logger.info('packing_weight_reconciliation_completed', {
    orderId,
    totalRefund: result.totalRefund,
    lineCount: result.lineResults.length,
    actor,
  });

  if (result.totalRefund > 0 && String(result.paymentMode || '').toUpperCase() === 'ONLINE') {
    const { processPendingRefundsForOrder } = require('./cashfreeRefund.service');
    processPendingRefundsForOrder(orderId).catch((err) => {
      logger.error('weight_reconciliation_refund_gateway_failed', {
        orderId,
        error: err.message,
      });
    });
  }

  publishOperationalEventAsync(io, {
    eventType: OPERATIONAL_EVENT_TYPES.WEIGHT_RECONCILIATION_COMPLETED,
    orderId,
    actorType: resolveActorType('admin'),
    actorId: actor,
    previousState: 'PACKING_STARTED',
    newState: 'PACKING_STARTED',
    metadata: {
      totalRefund: result.totalRefund,
      newTotal: result.newTotal,
      weightReconciliationStatus: result.weightReconciliationStatus,
      reconciliationAction: result.weightReconciliationStatus,
      lines: result.lineResults,
      refundAmount: result.totalRefund,
    },
  });

  return result;
}

/**
 * Full pack flow: reconcile weights then transition to PACKED.
 */
async function packOrderWithWeightReconciliation({
  orderId,
  lineWeights,
  actor,
  actorRole,
  io = null,
  context = {},
  skipWeightValidation = false,
}) {
  const reconciliation = await executePackingWeightReconciliation({
    orderId,
    lineWeights,
    actor,
    io,
    skipWeightValidation,
  });

  const { transitionOrderState } = require('./orderLifecycle.service');
  const { ORDER_STATES } = require('../utils/enhancedOrderStateMachine');

  const transition = await transitionOrderState({
    orderId,
    newState: ORDER_STATES.PACKED,
    actor,
    actorRole,
    context: {
      ...context,
      weightReconciliation: {
        totalRefund: reconciliation.totalRefund,
        newTotal: reconciliation.newTotal,
        lines: reconciliation.lineResults,
      },
    },
    io,
  });

  return { reconciliation, transition };
}

module.exports = {
  executePackingWeightReconciliation,
  packOrderWithWeightReconciliation,
  PACKABLE_STATUSES,
};
