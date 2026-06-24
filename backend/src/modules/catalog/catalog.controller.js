const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok } = require('../../utils/response');
const { signStoredImageUrl } = require('../../utils/uploadSigning');
const { createParamBinder, joinWhere } = require('../../utils/sqlParams');

const listCategories = asyncHandler(async (req, res) => {
  let rows;
  try {
    ({ rows } = await query(
      `SELECT id, name, image_url, active, sort_order
       FROM categories
       WHERE active = TRUE
       ORDER BY sort_order ASC, id DESC`
    ));
  } catch (err) {
    if (err?.code !== '42703') throw err;
    ({ rows } = await query(
      `SELECT id, name, image_url, active
       FROM categories
       WHERE active = TRUE
       ORDER BY id DESC`
    ));
    rows = rows.map((c) => ({ ...c, sort_order: 0 }));
  }

  const baseUrl = `${req.protocol}://${req.get('host')}`;
  const out = rows.map((c) => ({
    id: String(c.id),
    name: c.name,
    imageUrl: signStoredImageUrl(c.image_url || '', baseUrl),
    isActive: Boolean(c.active),
    sortOrder: Number(c.sort_order || 0),
  }));

  return ok(res, out, 'Catalog categories');
});

const listProducts = asyncHandler(async (req, res) => {
  const q = req.validated?.query || {};
  const limit = Number(q.limit || 100);
  const skip = Number(q.skip || 0);
  const categoryId = q.categoryId ? Number(q.categoryId) : null;
  const search = q.q ? String(q.q).toLowerCase() : null;

  const binder = createParamBinder();
  const conditions = ['p.active = TRUE'];

  if (categoryId) {
    conditions.push(`p.category_id = ${binder.ph(categoryId)}`);
  }

  if (search) {
    conditions.push(`LOWER(p.name) LIKE ${binder.ph(`%${search}%`)}`);
  }

  const limitPh = binder.ph(limit);
  const offsetPh = binder.ph(skip);

  const { rows } = await query(
    `
    SELECT p.id, p.category_id, p.name, p.description, p.price, p.image_url, p.stock, p.unit, p.active
    FROM products p
    ${joinWhere(conditions)}
    ORDER BY p.id DESC
    LIMIT ${limitPh} OFFSET ${offsetPh}
    `,
    binder.params
  );

  const baseUrl = `${req.protocol}://${req.get('host')}`;
  const out = rows.map((p) => ({
    id: String(p.id),
    name: p.name,
    description: p.description || '',
    imageUrl: signStoredImageUrl(p.image_url || '', baseUrl),
    unit: p.unit || '',
    price: Number(p.price),
    categoryId: p.category_id ? String(p.category_id) : null,
    inStock: Number(p.stock) > 0,
    stockQty: Number(p.stock),
  }));

  return ok(res, out, 'Catalog products');
});

module.exports = { listCategories, listProducts };
