/**
 * Integration tests — packing weight reconciliation workflow.
 */
require('dotenv').config();

const {
  ensureSchema,
  query,
  seedUser,
  seedWeightProduct,
  seedPieceProduct,
  seedOrderWithItems,
  getOrder,
  getOrderItems,
  getReconciliationLog,
  getPartialRefunds,
  getInventoryMovements,
  getProductStock,
  cleanupTestData,
  packOrderWithWeightReconciliation,
  assignOrderToPartner,
  WEIGHT_ACTION,
  TEST_PREFIX,
} = require('./helpers/weightReconciliationHarness');

describe('packing weight reconciliation integration', () => {
  const ids = { orderIds: [], userIds: [], productIds: [] };
  let admin;
  let customer;

  beforeAll(async () => {
    await ensureSchema();
    admin = await seedUser({
      phone: `${TEST_PREFIX}_admin`,
      role: 'admin',
      name: 'WR Admin',
    });
    customer = await seedUser({
      phone: `${TEST_PREFIX}_cust`,
      role: 'customer',
      name: 'WR Customer',
    });
    ids.userIds.push(admin.id, customer.id);
  });

  afterAll(async () => {
    await cleanupTestData(ids);
    const { pool } = require('../src/db/postgres');
    await pool.end();
  });

  test('exact weight — ACCEPT with no refund', async () => {
    const product = await seedWeightProduct({
      name: `${TEST_PREFIX}_exact`,
      basePricePerKg: 400,
      weightVariants: [1000],
      stock: 5,
    });
    ids.productIds.push(product.id);

    const { order, items } = await seedOrderWithItems({
      customerId: customer.id,
      items: [{ productId: product.id, quantity: 1, price: 400, orderedWeightG: 1000 }],
      totalAmount: 400,
    });
    ids.orderIds.push(order.id);

    const result = await packOrderWithWeightReconciliation({
      orderId: order.id,
      lineWeights: [{ orderItemId: items[0].id, actualWeightG: 1000 }],
      actor: admin.id,
      actorRole: 'admin',
    });

    expect(result.reconciliation.lineResults[0].action).toBe(WEIGHT_ACTION.ACCEPT);
    expect(result.reconciliation.totalRefund).toBe(0);

    const updated = await getOrder(order.id);
    expect(updated.status).toBe('PACKED');
    expect(updated.weight_reconciliation_status).toBe('COMPLETED');
    expect(Number(updated.total_amount)).toBe(400);

    const line = (await getOrderItems(order.id))[0];
    expect(Number(line.actual_weight_g)).toBe(1000);
    expect(Number(line.weight_refund_amount)).toBe(0);

    const assignment = await assignOrderToPartner({ orderId: order.id });
    expect(assignment.reason).not.toBe('weight_reconciliation_pending');
  });

  test('within ±50g tolerance — ACCEPT without refund', async () => {
    const product = await seedWeightProduct({
      name: `${TEST_PREFIX}_tolerance`,
      basePricePerKg: 500,
      weightVariants: [1000],
      stock: 5,
    });
    ids.productIds.push(product.id);

    const { order, items } = await seedOrderWithItems({
      customerId: customer.id,
      items: [{ productId: product.id, quantity: 1, price: 500, orderedWeightG: 1000 }],
      totalAmount: 500,
    });
    ids.orderIds.push(order.id);

    const result = await packOrderWithWeightReconciliation({
      orderId: order.id,
      lineWeights: [{ orderItemId: items[0].id, actualWeightG: 980 }],
      actor: admin.id,
      actorRole: 'admin',
    });

    expect(result.reconciliation.lineResults[0].action).toBe(WEIGHT_ACTION.ACCEPT);
    expect(result.reconciliation.totalRefund).toBe(0);
    expect((await getPartialRefunds(order.id)).length).toBe(0);
  });

  test('automatic top-up from next cut when short beyond tolerance', async () => {
    const product = await seedWeightProduct({
      name: `${TEST_PREFIX}_supplement`,
      basePricePerKg: 500,
      weightVariants: [500],
      stock: 4,
    });
    ids.productIds.push(product.id);
    const stockBefore = await getProductStock(product.id);

    const { order, items } = await seedOrderWithItems({
      customerId: customer.id,
      items: [{ productId: product.id, quantity: 1, price: 250, orderedWeightG: 1000 }],
      totalAmount: 500,
    });
    ids.orderIds.push(order.id);

    const result = await packOrderWithWeightReconciliation({
      orderId: order.id,
      lineWeights: [{ orderItemId: items[0].id, actualWeightG: 900 }],
      actor: admin.id,
      actorRole: 'admin',
    });

    expect(result.reconciliation.lineResults[0].action).toBe(
      WEIGHT_ACTION.SUPPLEMENT_FROM_NEXT_CUT
    );
    expect(result.reconciliation.lineResults[0].supplementG).toBe(100);
    expect(result.reconciliation.totalRefund).toBe(0);

    const stockAfter = await getProductStock(product.id);
    expect(stockAfter).toBeLessThan(stockBefore);

    const movements = await getInventoryMovements(order.id);
    expect(movements.some((m) => m.movement_type === 'SUPPLEMENT_DEDUCTION')).toBe(true);
  });

  test('automatic partial refund when stock cannot cover shortfall', async () => {
    const product = await seedWeightProduct({
      name: `${TEST_PREFIX}_refund`,
      basePricePerKg: 500,
      weightVariants: [500],
      stock: 0,
    });
    ids.productIds.push(product.id);

    const { order, items } = await seedOrderWithItems({
      customerId: customer.id,
      items: [{ productId: product.id, quantity: 1, price: 500, orderedWeightG: 1000 }],
      totalAmount: 500,
    });
    ids.orderIds.push(order.id);

    const result = await packOrderWithWeightReconciliation({
      orderId: order.id,
      lineWeights: [{ orderItemId: items[0].id, actualWeightG: 900 }],
      actor: admin.id,
      actorRole: 'admin',
    });

    expect(result.reconciliation.lineResults[0].action).toBe(WEIGHT_ACTION.AUTO_REFUND);
    expect(result.reconciliation.lineResults[0].refundAmount).toBe(40);
    expect(result.reconciliation.totalRefund).toBe(40);

    const updated = await getOrder(order.id);
    expect(Number(updated.total_amount)).toBe(460);
    expect(Number(updated.weight_reconciliation_total_refund)).toBe(40);

    const refunds = await getPartialRefunds(order.id);
    expect(refunds.length).toBe(1);
    expect(Number(refunds[0].amount)).toBe(40);

    const log = await getReconciliationLog(order.id);
    expect(log.length).toBe(1);
    expect(log[0].reconciliation_action).toBe(WEIGHT_ACTION.AUTO_REFUND);
    expect(log[0].reconciled_at).toBeTruthy();
  });

  test('mixed weight + piece order — only weight lines require actual grams', async () => {
    const meat = await seedWeightProduct({
      name: `${TEST_PREFIX}_mixed_meat`,
      basePricePerKg: 600,
      weightVariants: [500],
      stock: 3,
    });
    const eggs = await seedPieceProduct({
      name: `${TEST_PREFIX}_mixed_eggs`,
      price: 80,
      stock: 20,
    });
    ids.productIds.push(meat.id, eggs.id);

    const { order, items } = await seedOrderWithItems({
      customerId: customer.id,
      items: [
        { productId: meat.id, quantity: 1, price: 300, orderedWeightG: 500 },
        { productId: eggs.id, quantity: 1, price: 80, orderedWeightG: null },
      ],
      totalAmount: 380,
    });
    ids.orderIds.push(order.id);

    const meatItem = items.find((i) => Number(i.product_id) === Number(meat.id));

    const result = await packOrderWithWeightReconciliation({
      orderId: order.id,
      lineWeights: [{ orderItemId: meatItem.id, actualWeightG: 500 }],
      actor: admin.id,
      actorRole: 'admin',
    });

    expect(result.reconciliation.lineResults.length).toBe(2);
    const weightLine = result.reconciliation.lineResults.find((l) => l.weightBased);
    const pieceLine = result.reconciliation.lineResults.find((l) => !l.weightBased);
    expect(weightLine.action).toBe(WEIGHT_ACTION.ACCEPT);
    expect(pieceLine.weightBased).toBe(false);

    const updated = await getOrder(order.id);
    expect(updated.status).toBe('PACKED');
    expect(updated.weight_reconciliation_status).toBe('COMPLETED');
  });

  test('blocks dispatch until reconciliation completes', async () => {
    const product = await seedWeightProduct({
      name: `${TEST_PREFIX}_blocked`,
      basePricePerKg: 500,
      weightVariants: [500],
      stock: 2,
    });
    ids.productIds.push(product.id);

    const { order } = await seedOrderWithItems({
      customerId: customer.id,
      items: [{ productId: product.id, quantity: 1, price: 250, orderedWeightG: 500 }],
      totalAmount: 250,
    });
    ids.orderIds.push(order.id);

    await query(
      `UPDATE orders SET status = 'PACKED', weight_reconciliation_status = 'PENDING' WHERE id = $1`,
      [order.id]
    );

    const assignment = await assignOrderToPartner({ orderId: order.id });
    expect(assignment.assigned).toBe(false);
    expect(assignment.reason).toBe('weight_reconciliation_pending');
  });

  test('rejects pack without actual weights for weight-based items', async () => {
    const product = await seedWeightProduct({
      name: `${TEST_PREFIX}_missing_weight`,
      basePricePerKg: 500,
      weightVariants: [500],
      stock: 2,
    });
    ids.productIds.push(product.id);

    const { order } = await seedOrderWithItems({
      customerId: customer.id,
      items: [{ productId: product.id, quantity: 1, price: 250, orderedWeightG: 500 }],
      totalAmount: 250,
    });
    ids.orderIds.push(order.id);

    await expect(
      packOrderWithWeightReconciliation({
        orderId: order.id,
        lineWeights: [],
        actor: admin.id,
        actorRole: 'admin',
      })
    ).rejects.toThrow(/actual weight is required/i);

    const pending = await getOrder(order.id);
    expect(pending.status).toBe('CONFIRMED');
    expect(pending.weight_reconciliation_status).toBe('PENDING');
  });
});
