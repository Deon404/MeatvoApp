const fs = require('fs');
const path = require('path');
const mockQuery = jest.fn();
const mockOk = jest.fn((res, data, message) => ({ res, data, message }));
const mockLogger = {
  error: jest.fn(),
  warn: jest.fn(),
};

jest.mock('../src/db/postgres', () => ({
  query: (...args) => mockQuery(...args),
  withTransaction: jest.fn(),
}));

jest.mock('../src/db/appSettings', () => ({
  repairAppSettingsSchema: jest.fn(),
}));

jest.mock('../src/utils/response', () => ({
  ok: (...args) => mockOk(...args),
  fail: jest.fn(),
}));

jest.mock('../src/socket/socket', () => ({
  emitToAll: jest.fn(),
}));

jest.mock('../src/utils/storeSettings.util', () => ({
  syncOperationalToStoreSettings: jest.fn(),
  getMergedStoreSettings: jest.fn(),
}));

jest.mock('../src/utils/address', () => ({
  addressToText: jest.fn(() => ''),
}));

jest.mock('../src/services/orderLifecycle.service', () => ({
  transitionOrderState: jest.fn(),
  cancelOrderLifecycle: jest.fn(),
}));

jest.mock('../src/services/assignment.service', () => ({
  emitAssignmentSuccess: jest.fn(),
  retryAssignOrderToPartner: jest.fn(),
  manualAssignOrderToPartner: jest.fn(),
  assignOrderToPartner: jest.fn(),
}));

jest.mock('../src/utils/uploadSigning', () => ({
  signStoredImageUrl: jest.fn((value) => value),
  normalizeStoredImageUrl: jest.fn((value) => value),
}));

jest.mock('../src/utils/logger', () => ({
  logger: mockLogger,
}));

jest.mock('../src/services/failedDelivery.service', () => ({
  listOpenAdminTasks: jest.fn(),
  resolveFailedDelivery: jest.fn(),
}));

jest.mock('../src/constants/failedDelivery.constants', () => ({
  isOrderBlockedFromAssignment: jest.fn(() => false),
  ADMIN_TASK_TYPES: {
    ASSIGNMENT_FAILED: 'assignment_failed',
    FAILED_DELIVERY: 'failed_delivery',
  },
}));

jest.mock('../src/config/businessRules', () => ({
  DEFAULT_STORE_SETTINGS: {},
  PACK_AGE: {
    warningMinutes: 20,
    criticalMinutes: 40,
  },
}));

jest.mock('../src/services/packAge.service', () => ({
  enrichOrderWithPackAge: jest.fn(),
}));

jest.mock('../src/services/dispatch.service', () => ({
  getDispatchQueueOrders: jest.fn(),
}));

jest.mock('../src/services/adminTask.service', () => ({
  resolveAdminTaskByOrder: jest.fn(),
}));

jest.mock('../src/utils/deliveryPartner.util', () => ({
  countRiderActiveOrders: jest.fn(),
  refreshPartnerOperationalState: jest.fn(),
}));

jest.mock('../src/utils/sqlParams', () => ({
  createParamBinder: jest.fn(),
  joinWhere: jest.fn(),
  buildUpdateSet: jest.fn(),
}));

jest.mock('../src/services/packingWeightReconciliation.service', () => ({
  packOrderWithWeightReconciliation: jest.fn(),
}));

jest.mock('../src/services/businessMetrics.service', () => ({
  getOpsMetrics: jest.fn(),
  resolvePeriodBounds: jest.fn(),
  computeCommerceKpiDeltas: jest.fn(),
  computeOpsMetricsForRange: jest.fn(),
  normalizePeriod: jest.fn(),
}));

jest.mock('../src/db/redis', () => ({
  deleteByPattern: jest.fn(),
}));

jest.mock('../src/utils/requestBaseUrl', () => ({
  getPublicBaseUrl: jest.fn(() => 'http://localhost'),
}));

const uploadSigning = require('../src/utils/uploadSigning');
const {
  dashboard,
  listBanners,
  createBanner,
  updateBanner,
} = require('../src/modules/admin/admin.controller');

describe('admin dashboard', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockQuery.mockImplementation((sql) => {
      const text = String(sql).replace(/\s+/g, ' ');
      if (
        text.includes("WHERE status = 'PLACED'") ||
        text.includes("status NOT IN ('DELIVERED','CANCELLED','REFUNDED')") ||
        text.includes("COALESCE(payment_status, 'PENDING')")
      ) {
        const err = new Error('invalid input value for enum order_status');
        err.code = '22P02';
        throw err;
      }
      return Promise.resolve({ rows: [{ total: 7 }] });
    });
  });

  test('casts enum-backed dashboard comparisons to text for older schemas', async () => {
    const req = {};
    const res = {};
    const next = jest.fn();

    await dashboard(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(mockOk).toHaveBeenCalledTimes(1);

    const payload = mockOk.mock.calls[0][1];
    expect(payload.stats).toMatchObject({
      totalOrders: 7,
      liveOrders: 7,
      deliveredRevenue: 7,
      dispatchQueueCount: 7,
      awaitingPaymentCount: 7,
    });

    const issuedSql = mockQuery.mock.calls.map(([sql]) => String(sql).replace(/\s+/g, ' '));
    expect(issuedSql).toEqual(
      expect.arrayContaining([
        expect.stringContaining("status::text NOT IN ('DELIVERED','CANCELLED','REFUNDED')"),
        expect.stringContaining("WHERE o.status::text = 'PACKED'"),
        expect.stringContaining("WHERE status::text = 'PLACED'"),
        expect.stringContaining("payment_status::text"),
      ])
    );
  });

  test('uses text comparisons for admin order filters and analytics status queries', () => {
    const source = fs.readFileSync(
      path.join(__dirname, '..', 'src', 'modules', 'admin', 'admin.controller.js'),
      'utf8'
    );

    expect(source).toContain('o.status::text = ${binder.ph(String(statusFilter).trim().toUpperCase())}');
    expect(source).toContain("COUNT(*) FILTER (WHERE o.status::text = 'DELIVERED')");
    expect(source).toContain("COUNT(*) FILTER (WHERE oa.status::text IN ('ACCEPTED', 'PICKED', 'DELIVERED'))");
  });

  test('signs banner image URLs in admin banner responses', async () => {
    uploadSigning.signStoredImageUrl.mockImplementation((value) =>
      value ? `signed:${value}` : value
    );

    mockQuery
      .mockResolvedValueOnce({
        rows: [{ id: 1, image_url: '/uploads/images/banner-1.jpg', active: true }],
      })
      .mockResolvedValueOnce({
        rows: [{ id: 2, image_url: '/uploads/images/banner-2.jpg', active: true }],
      })
      .mockResolvedValueOnce({
        rows: [{ id: 3, image_url: '/uploads/images/banner-3.jpg', active: true }],
      });

    const next = jest.fn();

    await listBanners({}, {}, next);
    await createBanner(
      { body: { imageUrl: '/uploads/images/banner-2.jpg' }, query: {}, params: {} },
      {},
      next
    );
    await updateBanner(
      {
        body: { imageUrl: '/uploads/images/banner-3.jpg' },
        query: {},
        params: { id: '3' },
      },
      {},
      next
    );

    expect(next).not.toHaveBeenCalled();
    expect(mockOk).toHaveBeenNthCalledWith(
      1,
      {},
      [{ id: 1, image_url: 'signed:/uploads/images/banner-1.jpg', active: true }],
      'Banners'
    );
    expect(mockOk).toHaveBeenNthCalledWith(
      2,
      {},
      { id: 2, image_url: 'signed:/uploads/images/banner-2.jpg', active: true },
      'Banner created'
    );
    expect(mockOk).toHaveBeenNthCalledWith(
      3,
      {},
      { id: 3, image_url: 'signed:/uploads/images/banner-3.jpg', active: true },
      'Banner updated'
    );
  });
});
