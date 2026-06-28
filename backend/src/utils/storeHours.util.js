const {
  STORE,
  DEFAULT_STORE_SETTINGS,
} = require('../config/businessRules');

const DEFAULT_OPEN_TIME = STORE.storeOpenTime;
const DEFAULT_CLOSE_TIME = STORE.storeCloseTime;
const IST_TIMEZONE = STORE.istTimezone;

const parseTimeToMinutes = (timeStr) => {
  if (timeStr == null || timeStr === '') return null;
  const match = String(timeStr).trim().match(/^(\d{1,2}):(\d{2})/);
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
};

const normalizeTimeHHMM = (timeStr, fallback) => {
  const mins = parseTimeToMinutes(timeStr);
  if (mins == null) return fallback;
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
};

const getISTContext = (date = new Date()) => {
  const formatter = new Intl.DateTimeFormat('en-IN', {
    timeZone: IST_TIMEZONE,
    hour: 'numeric',
    minute: 'numeric',
    hour12: false,
  });
  const parts = formatter.formatToParts(date);
  const read = (type) => Number(parts.find((p) => p.type === type)?.value || 0);
  let hour = read('hour');
  if (hour === 24) hour = 0;
  const minute = read('minute');
  return {
    minutesSinceMidnight: hour * 60 + minute,
  };
};

const formatTime12h = (timeStr) => {
  const mins = parseTimeToMinutes(timeStr);
  if (mins == null) return String(timeStr || '');
  const hours = Math.floor(mins / 60);
  const minutes = mins % 60;
  const period = hours >= 12 ? 'PM' : 'AM';
  const h12 = hours % 12 || 12;
  if (minutes === 0) return `${h12} ${period}`;
  return `${h12}:${String(minutes).padStart(2, '0')} ${period}`;
};

const isWithinStoreHours = (openTime, closeTime, nowMinutes) => {
  const open = parseTimeToMinutes(openTime);
  const close = parseTimeToMinutes(closeTime);
  if (open == null || close == null) return true;
  if (open === close) return false;
  if (open < close) {
    return nowMinutes >= open && nowMinutes < close;
  }
  return nowMinutes >= open || nowMinutes < close;
};

const buildClosedMessage = ({ manualOpen, withinHours, openTime, closeTime, nowMinutes }) => {
  const openLabel = formatTime12h(openTime);
  const closeLabel = formatTime12h(closeTime);

  if (!manualOpen && withinHours) {
    return `We're not accepting orders right now. We'll resume during store hours (${openLabel} – ${closeLabel}).`;
  }

  const closeMinutes = parseTimeToMinutes(closeTime);
  const openMinutes = parseTimeToMinutes(openTime);

  if (closeMinutes != null && nowMinutes >= closeMinutes) {
    return `We're not accepting orders right now. We'll resume tomorrow from ${openLabel}.`;
  }

  if (openMinutes != null && nowMinutes < openMinutes) {
    return `We're not accepting orders right now. We'll resume from ${openLabel} today.`;
  }

  if (!manualOpen) {
    return `We're not accepting orders right now. We'll resume from ${openLabel} when we're back.`;
  }

  return `We're not accepting orders right now. We'll resume from ${openLabel} tomorrow.`;
};

/**
 * Combines manual admin toggle with configured open/close hours (IST).
 */
const {
  STORE_ACCEPTANCE_MODE,
  STORE_ACCEPTANCE_MESSAGES,
  normalizeAcceptanceMode,
} = require('../constants/storeAcceptanceMode.constants');

const resolveStoreAvailability = ({
  manualOpen = true,
  acceptanceMode = STORE_ACCEPTANCE_MODE.ACCEPTING,
  storeOpenTime = null,
  storeCloseTime = null,
  now = new Date(),
} = {}) => {
  const openTime = normalizeTimeHHMM(storeOpenTime, DEFAULT_OPEN_TIME);
  const closeTime = normalizeTimeHHMM(storeCloseTime, DEFAULT_CLOSE_TIME);
  const { minutesSinceMidnight } = getISTContext(now);
  const withinHours = isWithinStoreHours(openTime, closeTime, minutesSinceMidnight);
  const normalizedMode = normalizeAcceptanceMode(acceptanceMode);
  const manualAccepting = Boolean(manualOpen) &&
    normalizedMode !== STORE_ACCEPTANCE_MODE.NOT_ACCEPTING;
  const effectiveOpen = manualAccepting && withinHours;

  let closedReason = null;
  let closedMessage = null;
  let capacityMessage = null;

  if (!effectiveOpen) {
    if (!manualAccepting && !withinHours) {
      closedReason = 'MANUAL_AND_HOURS';
    } else if (!manualAccepting) {
      closedReason = 'MANUAL';
    } else {
      closedReason = 'OUTSIDE_HOURS';
    }
    closedMessage = buildClosedMessage({
      manualOpen: manualAccepting,
      withinHours,
      openTime,
      closeTime,
      nowMinutes: minutesSinceMidnight,
    });
  } else if (normalizedMode === STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY) {
    capacityMessage = STORE_ACCEPTANCE_MESSAGES[STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY];
  }

  const effectiveAcceptanceMode = !withinHours || !manualAccepting
    ? STORE_ACCEPTANCE_MODE.NOT_ACCEPTING
    : normalizedMode;

  return {
    is_open: effectiveOpen,
    manual_open: manualAccepting,
    within_hours: withinHours,
    acceptance_mode: effectiveAcceptanceMode,
    store_open_time: openTime,
    store_close_time: closeTime,
    closed_reason: closedReason,
    closed_message: closedMessage,
    capacity_message: capacityMessage,
    next_open_display: effectiveOpen ? null : formatTime12h(openTime),
  };
};

module.exports = {
  DEFAULT_OPEN_TIME,
  DEFAULT_CLOSE_TIME,
  IST_TIMEZONE,
  parseTimeToMinutes,
  normalizeTimeHHMM,
  formatTime12h,
  isWithinStoreHours,
  resolveStoreAvailability,
};
