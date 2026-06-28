/**
 * Unit tests — operational event utilities.
 */
const {
  OPERATIONAL_EVENT_TYPES,
  ACTOR_TYPES,
  STATE_TRANSITION_EVENT_MAP,
  EVENT_TIMESTAMP_COLUMNS,
  resolveActorType,
} = require('../src/constants/operationalEvent.constants');

const {
  buildStandardPayload,
  resolveActorType: resolveActorFromUtil,
} = require('../src/utils/operationalEvents.util');

describe('operational event constants', () => {
  test('defines all required lifecycle event types', () => {
    const required = [
      'ORDER_CONFIRMED',
      'PACKING_STARTED',
      'WEIGHT_RECONCILIATION_STARTED',
      'WEIGHT_RECONCILIATION_COMPLETED',
      'ORDER_PACKED',
      'ENTERED_DISPATCH_QUEUE',
      'BATCH_CREATED',
      'RIDER_ASSIGNED',
      'RIDER_ACCEPTED',
      'OUT_FOR_DELIVERY',
      'DELIVERY_ATTEMPTED',
      'FAILED_DELIVERY',
      'RETURN_TO_STORE',
      'REDELIVERED',
      'DELIVERED',
      'REFUNDED',
      'CANCELLED',
      'STOCK_FAILURE',
      'OPERATIONAL_EXCEPTION',
    ];
    for (const key of required) {
      expect(OPERATIONAL_EVENT_TYPES[key]).toBe(key);
    }
  });

  test('maps order states to lifecycle events', () => {
    expect(STATE_TRANSITION_EVENT_MAP.CONFIRMED).toBe(
      OPERATIONAL_EVENT_TYPES.ORDER_CONFIRMED
    );
    expect(STATE_TRANSITION_EVENT_MAP.PACKED).toBe(
      OPERATIONAL_EVENT_TYPES.ORDER_PACKED
    );
    expect(STATE_TRANSITION_EVENT_MAP.DELIVERED).toBe(
      OPERATIONAL_EVENT_TYPES.DELIVERED
    );
  });

  test('maps events to timestamp columns', () => {
    expect(EVENT_TIMESTAMP_COLUMNS.ORDER_CONFIRMED).toBe('confirmed_at');
    expect(EVENT_TIMESTAMP_COLUMNS.ORDER_PACKED).toBe('packed_at');
    expect(EVENT_TIMESTAMP_COLUMNS.DELIVERED).toBe('delivered_at');
    expect(EVENT_TIMESTAMP_COLUMNS.REFUNDED).toBe('refunded_at');
  });

  test('resolveActorType maps roles', () => {
    expect(resolveActorType('admin')).toBe(ACTOR_TYPES.ADMIN);
    expect(resolveActorType('delivery')).toBe(ACTOR_TYPES.RIDER);
    expect(resolveActorType('system')).toBe(ACTOR_TYPES.SYSTEM);
    expect(resolveActorFromUtil('staff')).toBe(ACTOR_TYPES.STAFF);
  });
});

describe('buildStandardPayload', () => {
  test('includes required fields', () => {
    const payload = buildStandardPayload({
      eventType: OPERATIONAL_EVENT_TYPES.ORDER_CONFIRMED,
      orderId: 42,
      actorType: ACTOR_TYPES.SYSTEM,
      actorId: null,
      previousState: 'PLACED',
      newState: 'CONFIRMED',
      metadata: { paymentMode: 'COD' },
      timestamp: '2026-06-28T10:00:00.000Z',
    });

    expect(payload).toMatchObject({
      eventType: 'ORDER_CONFIRMED',
      orderId: 42,
      actorType: 'SYSTEM',
      previousState: 'PLACED',
      newState: 'CONFIRMED',
      metadata: { paymentMode: 'COD' },
      timestamp: '2026-06-28T10:00:00.000Z',
    });
    expect(payload.description).toBeTruthy();
  });
});
