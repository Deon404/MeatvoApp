const asyncHandler = require('express-async-handler');
const { query, withTransaction } = require('../../db/postgres');
const { ok, created, fail } = require('../../utils/response');

const listAddresses = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const { rows } = await query(
    `SELECT id, label, address_line, landmark, lat, lng, is_default
     FROM addresses
     WHERE user_id = $1
     ORDER BY is_default DESC, id DESC`,
    [userId]
  );

  const addresses = rows.map((r) => ({
    id: Number(r.id),
    label: r.label,
    addressLine: r.address_line,
    landmark: r.landmark || '',
    lat: Number(r.lat),
    lng: Number(r.lng),
    isDefault: Boolean(r.is_default),
  }));
  return ok(res, { addresses }, 'Addresses');
});

const createAddress = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const body = req.validated.body;

  const address = await withTransaction(async (client) => {
    if (body.isDefault) {
      await client.query('UPDATE addresses SET is_default = FALSE WHERE user_id = $1', [userId]);
    }

    const { rows } = await client.query(
      `INSERT INTO addresses (user_id, label, address_line, landmark, lat, lng, is_default)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING id, label, address_line, landmark, lat, lng, is_default`,
      [
        userId,
        body.label,
        body.addressLine,
        body.landmark || null,
        body.lat,
        body.lng,
        Boolean(body.isDefault),
      ]
    );
    return rows[0];
  });

  return created(
    res,
    {
      address: {
        id: Number(address.id),
        label: address.label,
        addressLine: address.address_line,
        landmark: address.landmark || '',
        lat: Number(address.lat),
        lng: Number(address.lng),
        isDefault: Boolean(address.is_default),
      },
    },
    'Address created'
  );
});

const deleteAddress = asyncHandler(async (req, res) => {
  const userId = Number(req.user.id);
  const id = Number(req.validated.params.id);

  const { rows } = await query(
    'DELETE FROM addresses WHERE id = $1 AND user_id = $2 RETURNING id',
    [id, userId]
  );
  if (!rows[0]) return fail(res, 404, 'Address not found');
  return ok(res, {}, 'Address deleted');
});

module.exports = {
  listAddresses,
  createAddress,
  deleteAddress,
};
