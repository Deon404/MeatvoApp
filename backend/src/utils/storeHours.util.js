const DEFAULT_OPEN_TIME = '09:00';
const DEFAULT_CLOSE_TIME = '22:00';
const IST_TIMEZONE = 'Asia/Kolkata';

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
    return `Store is temporarily closed. We'll resume when we're open again (${openLabel} – ${closeLabel}).`;
  }

  const closeMinutes = parseTimeToMinutes(closeTime);
  const openMinutes = parseTimeToMinutes(openTime);

  if (closeMinutes != null && nowMinutes >= closeMinutes) {
    return `Store is closed right now. We'll take orders tomorrow from ${openLabel}.`;
  }

  if (openMinutes != null && nowMinutes < openMinutes) {
    return `Store is closed right now. We'll take orders from ${openLabel} today.`;
  }

  if (!manualOpen) {
    return `Store is closed right now. We'll take orders from ${openLabel} when we're open again.`;
  }

  return `Store is closed right now. We'll take orders from ${openLabel} tomorrow.`;
};

/**
 * Combines manual admin toggle with configured open/close hours (IST).
 */
const resolveStoreAvailability = ({
  manualOpen = true,
  storeOpenTime = null,
  storeCloseTime = null,
  now = new Date(),
} = {}) => {
  const openTime = normalizeTimeHHMM(storeOpenTime, DEFAULT_OPEN_TIME);
  const closeTime = normalizeTimeHHMM(storeCloseTime, DEFAULT_CLOSE_TIME);
  const { minutesSinceMidnight } = getISTContext(now);
  const withinHours = isWithinStoreHours(openTime, closeTime, minutesSinceMidnight);
  const effectiveOpen = Boolean(manualOpen) && withinHours;

  let closedReason = null;
  let closedMessage = null;

  if (!effectiveOpen) {
    if (!manualOpen && !withinHours) {
      closedReason = 'MANUAL_AND_HOURS';
    } else if (!manualOpen) {
      closedReason = 'MANUAL';
    } else {
      closedReason = 'OUTSIDE_HOURS';
    }
    closedMessage = buildClosedMessage({
      manualOpen: Boolean(manualOpen),
      withinHours,
      openTime,
      closeTime,
      nowMinutes: minutesSinceMidnight,
    });
  }

  return {
    is_open: effectiveOpen,
    manual_open: Boolean(manualOpen),
    within_hours: withinHours,
    store_open_time: openTime,
    store_close_time: closeTime,
    closed_reason: closedReason,
    closed_message: closedMessage,
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
