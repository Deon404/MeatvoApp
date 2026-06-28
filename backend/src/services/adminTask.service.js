const { query } = require('../db/postgres');
const {
  ADMIN_TASK_STATUS,
} = require('../constants/failedDelivery.constants');

async function createOpenAdminTask(client, { taskType, orderId, payload = {} }) {
  const db = client || { query };
  const { rows: existing } = await db.query(
    `SELECT id FROM admin_tasks
     WHERE order_id = $1 AND task_type = $2 AND status = $3
     LIMIT 1`,
    [orderId, taskType, ADMIN_TASK_STATUS.OPEN]
  );
  if (existing[0]) return existing[0];

  const { rows } = await db.query(
    `INSERT INTO admin_tasks (task_type, order_id, status, payload)
     VALUES ($1, $2, $3, $4)
     RETURNING id, task_type, order_id, status, payload, created_at`,
    [taskType, orderId, ADMIN_TASK_STATUS.OPEN, JSON.stringify(payload)]
  );
  return rows[0];
}

async function resolveAdminTaskByOrder(client, { orderId, taskType, adminUserId = null }) {
  const db = client || { query };
  const { rowCount } = await db.query(
    `UPDATE admin_tasks
     SET status = $1, resolved_at = NOW(), resolved_by = $2
     WHERE order_id = $3 AND task_type = $4 AND status = $5`,
    [
      ADMIN_TASK_STATUS.RESOLVED,
      adminUserId,
      orderId,
      taskType,
      ADMIN_TASK_STATUS.OPEN,
    ]
  );
  return rowCount > 0;
}

module.exports = {
  createOpenAdminTask,
  resolveAdminTaskByOrder,
};
