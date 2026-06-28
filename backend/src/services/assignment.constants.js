/** Shared assignment / batching status constants (breaks assignment.service ↔ order-batcher cycle). */

const assignableOrderStatuses = ['PACKED'];

const activeAssignmentStatuses = ['ASSIGNED', 'ACCEPTED', 'PICKED'];

const assignableOrderStatusSet = new Set(assignableOrderStatuses);
const activeAssignmentStatusSet = new Set(activeAssignmentStatuses);

module.exports = {
  assignableOrderStatuses,
  activeAssignmentStatuses,
  assignableOrderStatusSet,
  activeAssignmentStatusSet,
};
