/**
 * Customer-facing store availability states:
 *   Accepting Orders → Limited Capacity → Not Accepting Orders
 */

const STORE_ACCEPTANCE_MODE = {
  ACCEPTING: 'accepting',
  LIMITED_CAPACITY: 'limited_capacity',
  NOT_ACCEPTING: 'not_accepting',
};

const STORE_ACCEPTANCE_LABELS = {
  [STORE_ACCEPTANCE_MODE.ACCEPTING]: 'Accepting Orders',
  [STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY]: 'Limited Capacity',
  [STORE_ACCEPTANCE_MODE.NOT_ACCEPTING]: 'Not Accepting Orders',
};

const STORE_ACCEPTANCE_MESSAGES = {
  [STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY]:
    'High demand right now — we are still accepting orders, but delivery may take a little longer.',
};

const normalizeAcceptanceMode = (value) => {
  const raw = String(value || '').trim().toLowerCase();
  if (raw === STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY) {
    return STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY;
  }
  if (raw === STORE_ACCEPTANCE_MODE.NOT_ACCEPTING || raw === 'closed' || raw === 'busy_off') {
    return STORE_ACCEPTANCE_MODE.NOT_ACCEPTING;
  }
  if (raw === 'open' || raw === 'busy') {
    return raw === 'busy'
      ? STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY
      : STORE_ACCEPTANCE_MODE.ACCEPTING;
  }
  return STORE_ACCEPTANCE_MODE.ACCEPTING;
};

module.exports = {
  STORE_ACCEPTANCE_MODE,
  STORE_ACCEPTANCE_LABELS,
  STORE_ACCEPTANCE_MESSAGES,
  normalizeAcceptanceMode,
};
