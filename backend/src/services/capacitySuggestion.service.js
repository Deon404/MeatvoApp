const { query } = require('../db/postgres');
const redis = require('../db/redis');
const { logger } = require('../utils/logger');
const { ASSIGNMENT, CAPACITY_SUGGESTION } = require('../config/businessRules');
const { STORE_ACCEPTANCE_MODE } = require('../constants/storeAcceptanceMode.constants');
const {
  CAPACITY_SUGGESTION_SEVERITY,
  CAPACITY_SUGGESTION_REASON,
} = require('../constants/capacitySuggestion.constants');
const { assignableOrderStatuses, activeAssignmentStatuses } = require('./assignment.constants');
const {
  isRiderAtLoadCap,
  MAX_ACTIVE_ORDERS,
} = require('../utils/deliveryPartner.util');
const {
  readOperationalSettings,
  resolveAcceptanceMode,
} = require('../utils/storeSettings.util');

const QUEUE_SNAPSHOT_KEY = 'capacity:queue:snapshot';

function formatSuggestionRow(row) {
  if (!row) return null;
  const signals = row.signals && typeof row.signals === 'object' ? row.signals : {};
  return {
    id: Number(row.id),
    suggestedMode: row.suggested_mode,
    currentMode: row.current_mode,
    severity: row.severity,
    reason: row.reason,
    signals,
    dismissedUntil: row.dismissed_until
      ? new Date(row.dismissed_until).toISOString()
      : null,
    createdAt: row.created_at
      ? new Date(row.created_at).toISOString()
      : new Date().toISOString(),
  };
}

async function countDispatchQueue() {
  const { rows } = await query(
    `SELECT COUNT(*)::int AS count
     FROM orders o
     LEFT JOIN order_assignments oa
       ON oa.order_id = o.id
       AND oa.status = ANY($2::assignment_status[])
     WHERE o.status = ANY($1::order_status[])
       AND oa.id IS NULL`,
    [assignableOrderStatuses, activeAssignmentStatuses]
  );
  return Number(rows[0]?.count || 0);
}

async function countRecentConfirmedOrders() {
  const { rows } = await query(
    `SELECT COUNT(*)::int AS count
     FROM orders
     WHERE confirmed_at IS NOT NULL
       AND confirmed_at >= NOW() - ($1::int * INTERVAL '1 minute')`,
    [CAPACITY_SUGGESTION.confirmedWindowMinutes]
  );
  return Number(rows[0]?.count || 0);
}

async function collectRiderSignals() {
  const { rows } = await query(
    `SELECT dp.id,
            COALESCE(loads.active_count, 0)::int AS active_count
     FROM delivery_partners dp
     LEFT JOIN LATERAL (
       SELECT COUNT(*)::int AS active_count
       FROM order_assignments oa
       JOIN orders o ON o.id = oa.order_id
       WHERE oa.delivery_partner_id = dp.id
         AND oa.status = ANY($1::assignment_status[])
         AND o.status NOT IN ('DELIVERED', 'CANCELLED')
     ) loads ON TRUE
     WHERE dp.is_online = TRUE
       AND dp.approved = TRUE`,
    [activeAssignmentStatuses]
  );

  const activeRiders = rows.length;
  let availableRiders = 0;
  let ridersAtCapacity = 0;
  let totalActiveOrders = 0;

  for (const row of rows) {
    const activeCount = Number(row.active_count || 0);
    totalActiveOrders += activeCount;
    if (isRiderAtLoadCap(activeCount)) {
      ridersAtCapacity += 1;
    } else {
      availableRiders += 1;
    }
  }

  const maxFleetCapacity = activeRiders * MAX_ACTIVE_ORDERS;
  const riderCapacityUsed = maxFleetCapacity > 0
    ? Math.min(1, totalActiveOrders / maxFleetCapacity)
    : 0;

  return {
    activeRiders,
    availableRiders,
    ridersAtCapacity,
    riderCapacityUsed,
    allRidersAtCapacity: activeRiders > 0 && availableRiders === 0,
    noAvailableRiders: availableRiders === 0,
  };
}

async function readPreviousQueueSnapshot() {
  try {
    const raw = await redis.get(QUEUE_SNAPSHOT_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return {
      queueCount: Number(parsed.queueCount || 0),
      capturedAt: parsed.capturedAt ? new Date(parsed.capturedAt) : null,
    };
  } catch {
    return null;
  }
}

async function writeQueueSnapshot(queueCount) {
  try {
    await redis.set(
      QUEUE_SNAPSHOT_KEY,
      JSON.stringify({
        queueCount,
        capturedAt: new Date().toISOString(),
      }),
      'EX',
      CAPACITY_SUGGESTION.queueGrowthLookbackSeconds * 2
    );
  } catch (err) {
    logger.warn('capacity_queue_snapshot_failed', { message: err?.message });
  }
}

function isQueueGrowing(queueCount, previousSnapshot) {
  if (!previousSnapshot?.capturedAt) return false;
  const ageMs = Date.now() - previousSnapshot.capturedAt.getTime();
  if (ageMs > CAPACITY_SUGGESTION.queueGrowthLookbackSeconds * 1000) {
    return false;
  }
  return queueCount > Number(previousSnapshot.queueCount || 0);
}

/**
 * Pure evaluation — used by unit tests and runtime service.
 */
function evaluateCapacitySuggestion({
  signals,
  currentMode,
  rules = CAPACITY_SUGGESTION,
}) {
  const {
    queueCount,
    confirmedRecent,
    activeRiders,
    availableRiders,
    riderCapacityUsed,
    allRidersAtCapacity,
    noAvailableRiders,
    queueGrowing,
  } = signals;

  const limitedTriggers = [];
  if (queueCount > rules.peakReadyBacklog) {
    limitedTriggers.push(CAPACITY_SUGGESTION_REASON.DISPATCH_QUEUE);
  }
  if (confirmedRecent > rules.peakConfirmedOrders) {
    limitedTriggers.push(CAPACITY_SUGGESTION_REASON.CONFIRMED_ORDERS);
  }
  if (allRidersAtCapacity) {
    limitedTriggers.push(CAPACITY_SUGGESTION_REASON.RIDERS_AT_CAPACITY);
  }
  if (noAvailableRiders && queueGrowing && queueCount > 0) {
    limitedTriggers.push(CAPACITY_SUGGESTION_REASON.NO_RIDER_QUEUE_GROWING);
  }

  const clearConditionsMet =
    queueCount <= rules.clearQueueThreshold &&
    confirmedRecent <= rules.clearConfirmedThreshold &&
    availableRiders >= 1;

  let suggestedMode = null;
  let reason = null;
  let severity = null;

  if (
    currentMode === STORE_ACCEPTANCE_MODE.ACCEPTING &&
    limitedTriggers.length > 0
  ) {
    suggestedMode = STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY;
    reason = limitedTriggers.join(',');
    severity = resolveLimitedCapacitySeverity(limitedTriggers, signals, rules);
  } else if (
    currentMode === STORE_ACCEPTANCE_MODE.LIMITED_CAPACITY &&
    clearConditionsMet
  ) {
    suggestedMode = STORE_ACCEPTANCE_MODE.ACCEPTING;
    reason = CAPACITY_SUGGESTION_REASON.PRESSURE_CLEARED;
    severity = CAPACITY_SUGGESTION_SEVERITY.INFO;
  }

  if (!suggestedMode) {
    return null;
  }

  return {
    suggestedMode,
    severity,
    reason,
    signals: {
      queueCount,
      confirmedRecent,
      activeRiders,
      availableRiders,
      riderCapacityUsed,
      currentMode,
    },
    createdAt: new Date().toISOString(),
  };
}

function resolveLimitedCapacitySeverity(triggers, signals, rules) {
  const { queueCount, confirmedRecent } = signals;
  const severeQueue = queueCount > rules.peakReadyBacklog * 2;
  const severeConfirmed = confirmedRecent > rules.peakConfirmedOrders * 2;

  if (triggers.length >= 3 || severeQueue || severeConfirmed) {
    return CAPACITY_SUGGESTION_SEVERITY.CRITICAL;
  }
  if (triggers.length >= 2) {
    return CAPACITY_SUGGESTION_SEVERITY.WARNING;
  }
  return CAPACITY_SUGGESTION_SEVERITY.INFO;
}

async function collectOperationalSignals() {
  const operational = await readOperationalSettings();
  const currentMode = resolveAcceptanceMode(operational);
  const queueCount = await countDispatchQueue();
  const confirmedRecent = await countRecentConfirmedOrders();
  const riderSignals = await collectRiderSignals();
  const previousSnapshot = await readPreviousQueueSnapshot();
  const queueGrowing = isQueueGrowing(queueCount, previousSnapshot);

  await writeQueueSnapshot(queueCount);

  return {
    currentMode,
    queueCount,
    confirmedRecent,
    queueGrowing,
    ...riderSignals,
  };
}

async function getLatestSuggestionRow() {
  const { rows } = await query(
    `SELECT id, suggested_mode, current_mode, reason, severity, signals,
            dismissed_until, created_at
     FROM capacity_suggestions
     ORDER BY created_at DESC
     LIMIT 1`
  );
  return rows[0] || null;
}

function isDismissed(row) {
  if (!row?.dismissed_until) return false;
  return new Date(row.dismissed_until).getTime() > Date.now();
}

async function persistSuggestion(evaluation) {
  const { rows } = await query(
    `INSERT INTO capacity_suggestions
       (suggested_mode, current_mode, reason, severity, signals)
     VALUES ($1, $2, $3, $4, $5::jsonb)
     RETURNING id, suggested_mode, current_mode, reason, severity, signals,
               dismissed_until, created_at`,
    [
      evaluation.suggestedMode,
      evaluation.signals.currentMode,
      evaluation.reason,
      evaluation.severity,
      JSON.stringify(evaluation.signals),
    ]
  );
  return formatSuggestionRow(rows[0]);
}

function shouldPersistNewSuggestion(latestRow, evaluation) {
  if (!latestRow) return true;
  if (isDismissed(latestRow)) return true;
  return (
    latestRow.suggested_mode !== evaluation.suggestedMode ||
    latestRow.reason !== evaluation.reason ||
    latestRow.severity !== evaluation.severity
  );
}

async function evaluateAndPersistSuggestion({ io = null } = {}) {
  const rawSignals = await collectOperationalSignals();
  const evaluation = evaluateCapacitySuggestion({
    signals: {
      queueCount: rawSignals.queueCount,
      confirmedRecent: rawSignals.confirmedRecent,
      activeRiders: rawSignals.activeRiders,
      availableRiders: rawSignals.availableRiders,
      riderCapacityUsed: rawSignals.riderCapacityUsed,
      allRidersAtCapacity: rawSignals.allRidersAtCapacity,
      noAvailableRiders: rawSignals.noAvailableRiders,
      queueGrowing: rawSignals.queueGrowing,
    },
    currentMode: rawSignals.currentMode,
  });

  if (!evaluation) {
    return { suggestion: null, persisted: false, signals: rawSignals };
  }

  const latestRow = await getLatestSuggestionRow();
  if (isDismissed(latestRow) &&
      latestRow.suggested_mode === evaluation.suggestedMode) {
    return {
      suggestion: null,
      suppressed: true,
      dismissedUntil: latestRow.dismissed_until,
      signals: rawSignals,
    };
  }

  let persistedRow = null;
  if (shouldPersistNewSuggestion(latestRow, evaluation)) {
    persistedRow = await persistSuggestion(evaluation);
    if (io) {
      io.to('admin_room').emit('store:capacity_suggestion', persistedRow);
    }
    logger.info('capacity_suggestion_created', {
      suggestedMode: evaluation.suggestedMode,
      severity: evaluation.severity,
      reason: evaluation.reason,
    });
  } else {
    persistedRow = formatSuggestionRow(latestRow);
  }

  return {
    suggestion: persistedRow || evaluation,
    persisted: Boolean(persistedRow?.id),
    signals: rawSignals,
  };
}

async function getActiveCapacitySuggestion() {
  const latestRow = await getLatestSuggestionRow();
  if (!latestRow) {
    return { suggestion: null, active: false };
  }

  if (isDismissed(latestRow)) {
    return {
      suggestion: null,
      active: false,
      dismissedUntil: new Date(latestRow.dismissed_until).toISOString(),
    };
  }

  const rawSignals = await collectOperationalSignals();
  const evaluation = evaluateCapacitySuggestion({
    signals: {
      queueCount: rawSignals.queueCount,
      confirmedRecent: rawSignals.confirmedRecent,
      activeRiders: rawSignals.activeRiders,
      availableRiders: rawSignals.availableRiders,
      riderCapacityUsed: rawSignals.riderCapacityUsed,
      allRidersAtCapacity: rawSignals.allRidersAtCapacity,
      noAvailableRiders: rawSignals.noAvailableRiders,
      queueGrowing: rawSignals.queueGrowing,
    },
    currentMode: rawSignals.currentMode,
  });

  if (!evaluation) {
    return { suggestion: null, active: false, signals: rawSignals };
  }

  if (latestRow.suggested_mode !== evaluation.suggestedMode) {
    return {
      suggestion: {
        ...evaluation,
        id: Number(latestRow.id),
      },
      active: true,
      stale: true,
    };
  }

  return {
    suggestion: formatSuggestionRow(latestRow),
    active: true,
  };
}

async function dismissCapacitySuggestion(minutes = CAPACITY_SUGGESTION.defaultDismissMinutes) {
  const safeMinutes = Math.min(Math.max(Number(minutes) || 30, 1), 24 * 60);
  const latestRow = await getLatestSuggestionRow();
  if (!latestRow) {
    return { dismissed: false, reason: 'no_suggestion' };
  }

  const { rows } = await query(
    `UPDATE capacity_suggestions
     SET dismissed_until = NOW() + ($1::int * INTERVAL '1 minute')
     WHERE id = $2
     RETURNING id, suggested_mode, dismissed_until`,
    [safeMinutes, latestRow.id]
  );

  return {
    dismissed: true,
    id: Number(rows[0]?.id),
    suggestedMode: rows[0]?.suggested_mode,
    dismissedUntil: rows[0]?.dismissed_until
      ? new Date(rows[0].dismissed_until).toISOString()
      : null,
    minutes: safeMinutes,
  };
}

let debounceTimer = null;
let debounceIo = null;

function scheduleCapacitySuggestionCheck(io = null, { immediate = false } = {}) {
  if (io) debounceIo = io;

  if (immediate) {
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      debounceTimer = null;
    }
    return evaluateAndPersistSuggestion({ io: io || debounceIo }).catch((err) => {
      logger.warn('capacity_suggestion_check_failed', { message: err?.message });
    });
  }

  if (debounceTimer) return;
  debounceTimer = setTimeout(() => {
    debounceTimer = null;
    evaluateAndPersistSuggestion({ io: debounceIo }).catch((err) => {
      logger.warn('capacity_suggestion_debounced_check_failed', { message: err?.message });
    });
  }, CAPACITY_SUGGESTION.eventDebounceMs);
  debounceTimer.unref?.();
}

function startCapacitySuggestionMonitor(io) {
  scheduleCapacitySuggestionCheck(io, { immediate: true });
  const timer = setInterval(() => {
    evaluateAndPersistSuggestion({ io }).catch((err) => {
      logger.warn('capacity_suggestion_monitor_tick_failed', { message: err?.message });
    });
  }, CAPACITY_SUGGESTION.monitorIntervalMs);
  timer.unref?.();
  return timer;
}

module.exports = {
  evaluateCapacitySuggestion,
  resolveLimitedCapacitySeverity,
  collectOperationalSignals,
  evaluateAndPersistSuggestion,
  getActiveCapacitySuggestion,
  dismissCapacitySuggestion,
  scheduleCapacitySuggestionCheck,
  startCapacitySuggestionMonitor,
  countDispatchQueue,
  countRecentConfirmedOrders,
  collectRiderSignals,
  formatSuggestionRow,
  isDismissed,
};
