const TRANSITIONS = {
  PLACED:           ['CONFIRMED', 'CANCELLED'],
  CONFIRMED:        ['PACKED', 'CANCELLED'],
  PACKED:           ['OUT_FOR_DELIVERY'],
  OUT_FOR_DELIVERY: ['DELIVERED'],
  DELIVERED:        [],
  CANCELLED:        []
};

function canTransition(from, to) {
  return (TRANSITIONS[from] || []).includes(to);
}

function getValidTransitions(from) {
  return TRANSITIONS[from] || [];
}

module.exports = { canTransition, getValidTransitions, TRANSITIONS };
