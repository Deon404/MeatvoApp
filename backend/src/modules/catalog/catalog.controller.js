const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok } = require('../../utils/response');

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

  const out = rows.map((c) => ({
    id: String(c.id),
    name: c.name,
    imageUrl: c.image_url || '',
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

  const params = [];
  const conditions = ['p.active = TRUE'];

  if (categoryId) {
    params.push(categoryId);
    conditions.push(`p.category_id = $${params.length}`);
  }

  if (search) {
    params.push(`%${search}%`);
    conditions.push(`LOWER(p.name) LIKE $${params.length}`);
  }

  params.push(limit);
  const limitIdx = params.length;
  params.push(skip);
  const offsetIdx = params.length;

  const { rows } = await query(
    `
    SELECT p.id, p.category_id, p.name, p.description, p.price, p.image_url, p.stock, p.unit, p.active
    FROM products p
    WHERE ${conditions.join(' AND ')}
    ORDER BY p.id DESC
    LIMIT $${limitIdx} OFFSET $${offsetIdx}
    `,
    params
  );

  const out = rows.map((p) => ({
    id: String(p.id),
    name: p.name,
    description: p.description || '',
    imageUrl: p.image_url || '',
    unit: p.unit || '',
    price: Number(p.price),
    categoryId: p.category_id ? String(p.category_id) : null,
    inStock: Number(p.stock) > 0,
    stockQty: Number(p.stock),
  }));

  return ok(res, out, 'Catalog products');
});

module.exports = { listCategories, listProducts };
