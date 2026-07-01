const {
  ORDER_STATES,
  canTransition,
  getValidTransitions,
} = require('../src/utils/enhancedOrderStateMachine');

describe('enhancedOrderStateMachine FAILED_DELIVERY', () => {
  test('allows admin recovery paths from FAILED_DELIVERY', () => {
    expect(canTransition(ORDER_STATES.FAILED_DELIVERY, ORDER_STATES.PACKED)).toBe(true);
    expect(canTransition(ORDER_STATES.FAILED_DELIVERY, ORDER_STATES.REFUNDED)).toBe(true);
    expect(canTransition(ORDER_STATES.FAILED_DELIVERY, ORDER_STATES.CANCELLED)).toBe(true);
  });

  test('allows FAILED_DELIVERY from in-transit states', () => {
    expect(canTransition(ORDER_STATES.OUT_FOR_DELIVERY, ORDER_STATES.FAILED_DELIVERY)).toBe(
      true
    );
    expect(canTransition(ORDER_STATES.RIDER_NEARBY, ORDER_STATES.FAILED_DELIVERY)).toBe(true);
  });

  test('exposes recovery transitions via getValidTransitions', () => {
    expect(getValidTransitions(ORDER_STATES.FAILED_DELIVERY)).toEqual(
      expect.arrayContaining([
        ORDER_STATES.PACKED,
        ORDER_STATES.REFUNDED,
        ORDER_STATES.CANCELLED,
      ])
    );
  });
});

describe('enhancedOrderStateMachine RIDER_ASSIGNED', () => {
  test('allows admin assignment lifecycle from PACKED and RIDER_ASSIGNED', () => {
    expect(canTransition(ORDER_STATES.PACKED, ORDER_STATES.RIDER_ASSIGNED)).toBe(true);
    expect(canTransition(ORDER_STATES.RIDER_ASSIGNED, ORDER_STATES.RIDER_ACCEPTED)).toBe(
      true
    );
    expect(canTransition(ORDER_STATES.RIDER_ASSIGNED, ORDER_STATES.RIDER_REJECTED)).toBe(
      true
    );
    expect(canTransition(ORDER_STATES.RIDER_ASSIGNED, ORDER_STATES.PACKED)).toBe(true);
  });

  test('exposes RIDER_ASSIGNED transitions via getValidTransitions', () => {
    expect(getValidTransitions(ORDER_STATES.RIDER_ASSIGNED)).toEqual(
      expect.arrayContaining([
        ORDER_STATES.RIDER_ACCEPTED,
        ORDER_STATES.RIDER_REJECTED,
        ORDER_STATES.PACKED,
      ])
    );
  });
});
