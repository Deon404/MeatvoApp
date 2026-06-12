const asyncHandler = require('express-async-handler');
const { query, withTransaction } = require('../../db/postgres');
const { ok, created, fail } = require('../../utils/response');

const DEFAULT_LAT = 23.7957;
const DEFAULT_LNG = 86.4304;
const DEFAULT_CITY = 'Dhanbad';
const DEFAULT_STATE = 'Jharkhand';

const SELECT_COLUMNS = `
  id, user_id, address_line1, address_line2, city, state, pincode,
  landmark, address_type, latitude, longitude, is_default, created_at
`;

const normalizeLabel = (label) => {
  const raw = String(label ?? 'home').toLowerCase();
  const s = raw.includes('.') ? raw.split('.').pop() : raw;
  if (['home', 'work', 'other'].includes(s)) return s;
  return 'home';
};

const toAddressType = (label) => normalizeLabel(label).toUpperCase();

const resolveCoords = (lat, lng) => ({
  lat: lat != null && !Number.isNaN(Number(lat)) ? Number(lat) : DEFAULT_LAT,
  lng: lng != null && !Number.isNaN(Number(lng)) ? Number(lng) : DEFAULT_LNG,
});

const toAddressDto = (row) => {
  const label = normalizeLabel(row.address_type);
  const line1 = row.address_line1 ?? '';
  const { lat, lng } = resolveCoords(row.latitude, row.longitude);
  return {
    id: String(row.id),
    userId: String(row.user_id),
    user_id: String(row.user_id),
    label,
    address_type: toAddressType(label),
    addressLine1: line1,
    address_line1: line1,
    addressLine2: row.address_line2 ?? null,
    address_line2: row.address_line2 ?? null,
    city: row.city || DEFAULT_CITY,
    state: row.state || DEFAULT_STATE,
    pincode: row.pincode ?? '',
    landmark: row.landmark ?? '',
    lat,
    lng,
    latitude: lat,
    longitude: lng,
    isDefault: Boolean(row.is_default),
    is_default: Boolean(row.is_default),
    createdAt: row.created_at,
    created_at: row.created_at,
  };
};

const getAddresses = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  const { rows } = await query(
    `SELECT ${SELECT_COLUMNS}
     FROM addresses
     WHERE user_id = $1
     ORDER BY is_default DESC, id DESC`,
    [userId]
  );

  const addresses = rows.map(toAddressDto);
  return ok(res, { addresses }, 'Addresses');
});

const addAddress = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const body = req.validated.body;
  const { lat, lng } = resolveCoords(body.lat, body.lng);
  const label = normalizeLabel(body.label);
  const addressType = toAddressType(label);

  const row = await withTransaction(async (client) => {
    if (body.isDefault) {
      await client.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
    }

    const { rows } = await client.query(
      `INSERT INTO addresses (
         user_id, address_line1, address_line2, city, state, pincode,
         landmark, address_type, latitude, longitude, is_default
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       RETURNING ${SELECT_COLUMNS}`,
      [
        userId,
        body.addressLine1,
        body.addressLine2 || null,
        body.city || DEFAULT_CITY,
        body.state || DEFAULT_STATE,
        body.pincode || '',
        body.landmark || null,
        addressType,
        lat,
        lng,
        Boolean(body.isDefault),
      ]
    );
    return rows[0];
  });

  if (!row) {
    return fail(res, 500, 'Failed to create address');
  }

  return created(res, toAddressDto(row), 'Address added');
});

const updateAddress = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const id = Number(req.validated.params.id);
  const body = req.validated.body;

  const existing = await query(
    `SELECT ${SELECT_COLUMNS} FROM addresses WHERE id = $1 AND user_id = $2`,
    [id, userId]
  );
  if (!existing.rows[0]) {
    return fail(res, 404, 'Address not found');
  }

  const current = existing.rows[0];
  const raw = req.body || {};
  const isDefaultOnly =
    raw.isDefault === true &&
    !raw.addressLine1 &&
    !raw.addressLine &&
    raw.label === undefined;

  if (isDefaultOnly) {
    const row = await withTransaction(async (client) => {
      await client.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
      const { rows } = await client.query(
        `UPDATE addresses SET is_default = TRUE WHERE id = $1 AND user_id = $2
         RETURNING ${SELECT_COLUMNS}`,
        [id, userId]
      );
      return rows[0];
    });
    return ok(res, toAddressDto(row), 'Default address updated');
  }

  const label = body.label !== undefined ? normalizeLabel(body.label) : normalizeLabel(current.address_type);
  const addressType = toAddressType(label);
  const { lat, lng } = resolveCoords(
    body.lat !== undefined ? body.lat : current.latitude,
    body.lng !== undefined ? body.lng : current.longitude
  );

  const row = await withTransaction(async (client) => {
    if (body.isDefault) {
      await client.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
    }

    const { rows } = await client.query(
      `UPDATE addresses SET
         address_line1 = $1,
         address_line2 = $2,
         city = $3,
         state = $4,
         pincode = $5,
         landmark = $6,
         address_type = $7,
         latitude = $8,
         longitude = $9,
         is_default = $10
       WHERE id = $11 AND user_id = $12
       RETURNING ${SELECT_COLUMNS}`,
      [
        body.addressLine1 ?? current.address_line1,
        body.addressLine2 !== undefined ? body.addressLine2 : current.address_line2,
        body.city ?? current.city ?? DEFAULT_CITY,
        body.state ?? current.state ?? DEFAULT_STATE,
        body.pincode !== undefined ? body.pincode : current.pincode ?? '',
        body.landmark !== undefined ? body.landmark : current.landmark,
        addressType,
        lat,
        lng,
        body.isDefault !== undefined ? Boolean(body.isDefault) : Boolean(current.is_default),
        id,
        userId,
      ]
    );
    return rows[0];
  });

  if (!row) {
    return fail(res, 500, 'Failed to update address');
  }

  return ok(res, toAddressDto(row), 'Address updated');
});

const setDefaultAddress = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const id = Number(req.validated.params.id);

  const row = await withTransaction(async (client) => {
    const check = await client.query(
      'SELECT id FROM addresses WHERE id = $1 AND user_id = $2',
      [id, userId]
    );
    if (!check.rows[0]) return null;

    await client.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
    const { rows } = await client.query(
      `UPDATE addresses SET is_default = TRUE WHERE id = $1 AND user_id = $2
       RETURNING ${SELECT_COLUMNS}`,
      [id, userId]
    );
    return rows[0];
  });

  if (!row) return fail(res, 404, 'Address not found');
  return ok(res, toAddressDto(row), 'Default address updated');
});

const deleteAddress = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const id = Number(req.validated.params.id);

  const { rows } = await query(
    'DELETE FROM addresses WHERE id = $1 AND user_id = $2 RETURNING id',
    [id, userId]
  );
  if (!rows[0]) return fail(res, 404, 'Address not found');
  return ok(res, {}, 'Address deleted');
});

module.exports = {
  getAddresses,
  addAddress,
  updateAddress,
  setDefaultAddress,
  deleteAddress,
  listAddresses: getAddresses,
  createAddress: addAddress,
};
