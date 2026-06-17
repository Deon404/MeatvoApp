const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, created, fail } = require('../../utils/response');
const { ROLES } = require('../../utils/roles');
const { signStoredImageUrl } = require('../../utils/uploadSigning');

const requestBaseUrl = (req) => `${req.protocol}://${req.get('host')}`;

const formatCategory = (category, baseUrl) => ({
  ...category,
  image_url: signStoredImageUrl(category.image_url || '', baseUrl),
});

const ALLOWED_CATEGORY_COLUMNS = ['name', 'image_url', 'active'];

function buildCategoryUpdateClause(updates) {
  const sets = [];
  const params = [];
  for (const [key, value] of Object.entries(updates)) {
    if (!ALLOWED_CATEGORY_COLUMNS.includes(key)) continue;
    params.push(value);
    sets.push(`${key} = $${params.length}`);
  }
  return { sets, params };
}

const listCategories = asyncHandler(async (req, res) => {
  const includeInactiveRequested = Boolean(req.validated?.query?.includeInactive);
  const includeInactive = req.user?.role === ROLES.ADMIN ? includeInactiveRequested : false;

  const params = [];
  let where = '';
  if (!includeInactive) {
    params.push(true);
    where = `WHERE active = $${params.length}`;
  }

  const { rows } = await query(
    `SELECT id, name, image_url, active FROM categories ${where} ORDER BY id DESC`,
    params
  );
  const baseUrl = requestBaseUrl(req);
  const categories = rows.map((row) => formatCategory(row, baseUrl));
  return ok(res, { categories }, 'Categories');
});

const createCategory = asyncHandler(async (req, res) => {
  const { name, image_url = null, active = true } = req.validated.body;
  const { rows } = await query(
    'INSERT INTO categories (name, image_url, active) VALUES ($1,$2,$3) RETURNING id, name, image_url, active',
    [name, image_url, active]
  );
  const baseUrl = requestBaseUrl(req);
  return created(res, { category: formatCategory(rows[0], baseUrl) }, 'Category created');
});

const updateCategory = asyncHandler(async (req, res) => {
  const id = Number(req.validated.params.id);
  const patch = req.validated.body;
  const { sets, params } = buildCategoryUpdateClause(patch || {});
  if (!sets.length) return fail(res, 400, 'No fields to update');

  params.push(id);
  const { rows } = await query(
    `UPDATE categories SET ${sets.join(', ')} WHERE id = $${params.length}
     RETURNING id, name, image_url, active`,
    params
  );
  if (!rows[0]) return fail(res, 404, 'Category not found');
  const baseUrl = requestBaseUrl(req);
  return ok(res, { category: formatCategory(rows[0], baseUrl) }, 'Category updated');
});

const deleteCategory = asyncHandler(async (req, res) => {
  const id = Number(req.validated.params.id);
  const { rows } = await query(
    'UPDATE categories SET active = FALSE WHERE id = $1 RETURNING id',
    [id]
  );
  if (!rows[0]) return fail(res, 404, 'Category not found');
  return ok(res, {}, 'Category deleted');
});

module.exports = {
  listCategories,
  createCategory,
  updateCategory,
  deleteCategory,
};

