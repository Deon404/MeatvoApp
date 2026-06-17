const TRANSITIONS = {
  PLACED: ['CONFIRMED', 'CANCELLED'],
  CONFIRMED: ['PACKING_STARTED', 'PACKED', 'CANCELLED'],
  PACKING_STARTED: ['PACKED', 'CANCELLED'],
  PACKED: ['OUT_FOR_DELIVERY', 'CANCELLED'],
  OUT_FOR_DELIVERY: ['DELIVERED'],
  DELIVERED: [],
  CANCELLED: [],
};

function canTransition(from, to) {
  if (!from || !to) return false;
  if (String(from).toUpperCase() === String(to).toUpperCase()) return true;
  return (TRANSITIONS[from] || []).includes(to);
}

function getValidTransitions(from) {
  return TRANSITIONS[from] || [];
}

module.exports = { canTransition, getValidTransitions, TRANSITIONS };
