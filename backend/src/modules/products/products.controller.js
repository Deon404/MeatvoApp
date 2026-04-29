const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const redis = require('../../db/redis');
const logger = require('../../utils/logger').logger;
const { ok, created, fail } = require('../../utils/response');
const { ROLES } = require('../../utils/roles');
const { isProductFresh, getFreshnessBadge, getFreshnessWhereClause } = require('../../utils/freshness.util');

const CACHE_TTL_PRODUCTS = 300; // 5min
const CACHE_TTL_PRODUCT = 600; // 10min
const CACHE_TTL_CATEGORIES = 3600; // 1h
const CACHE_TTL_FEATURED = 900; // 15min

// Helper
const getListCacheKey = (page, limit, filters) => `products:all:${page}:${limit}:${Buffer.from(JSON.stringify(filters)).toString('base64')}`;

// Admin check
const requireAdmin = (req) => {
  if (req.user?.role !== ROLES.ADMIN) throw fail(null, 403, 'Admin required');
};

/**
 * Format product with full Meatvo schema
 * Adds calculated fields: display_price, freshness_badge, etc.
 */
const formatProduct = (product, weight_g = null) => {
  if (!product) return null;

  const basePrice = Number(product.base_price_per_kg || product.price || 0);
  const weight = weight_g || (product.weight_variants && product.weight_variants.length > 0 ? product.weight_variants[0] : 500);
  const marinationOptions =
    typeof product.marination_options === 'string'
      ? JSON.parse(product.marination_options)
      : product.marination_options;

  return {
    id: product.id,
    name: product.name,
    description: product.description || '',
    category_id: product.category_id,
    category_name: product.category_name || '',
    base_price_per_kg: basePrice,
    display_price: basePrice * (weight / 1000),
    weight_variants: product.weight_variants || [250, 500, 1000],
    cut_types: product.cut_types || null,
    marination_options: marinationOptions || null,
    freshness_date: product.freshness_date || null,
    freshness_badge: getFreshnessBadge(product.freshness_date),
    is_fresh: isProductFresh(product.freshness_date),
    is_active: product.active !== false,
    image_url: product.image_url || '',
    stock: product.stock || 0,
    unit: product.unit || 'kg',
    created_at: product.created_at,
    updated_at: product.updated_at
  };
};

// Enhanced listProducts with freshness filtering
const getAllProducts = asyncHandler(async (req, res) => {
  const q = req.validated?.query || req.query || {};
  const page = Math.max(1, Number(q.page) || 1);
  const limit = Math.min(50, Number(q.limit) || 20);
  const offset = (page - 1) * limit;
  const weight_g = q.weight_g ? Number(q.weight_g) : null;
  const resolvedCategoryId = q.categoryId || q.category;
  const resolvedSearch = q.q || q.search;

  const filters = {
    categoryId: resolvedCategoryId ? Number(resolvedCategoryId) : null,
    min_price: q.min_price ? Number(q.min_price) : null,
    max_price: q.max_price ? Number(q.max_price) : null,
    search: resolvedSearch ? String(resolvedSearch).trim() : null,
    available: q.available !== undefined ? q.available === 'true' : true // Default to fresh only
  };

  const cacheKey = getListCacheKey(page, limit, filters);
  const cached = await redis.get(cacheKey);
  if (cached) return res.json({ success: true, data: JSON.parse(cached) });

  // Build conditions
  const conditions = ['p.active = true'];
  const params = [];

  // Freshness filter - hide products older than 2 days (unless admin or available=false)
  if (filters.available) {
    conditions.push(getFreshnessWhereClause());
  }

  if (filters.categoryId) {
    params.push(filters.categoryId);
    conditions.push(`p.category_id = $${params.length}`);
  }
  if (filters.min_price !== null) {
    params.push(filters.min_price);
    conditions.push(`p.base_price_per_kg >= $${params.length}`);
  }
  if (filters.max_price !== null) {
    params.push(filters.max_price);
    conditions.push(`p.base_price_per_kg <= $${params.length}`);
  }
  if (filters.search) {
    params.push(`%${filters.search.toLowerCase()}%`);
    conditions.push(
      `(LOWER(p.name) ILIKE $${params.length} OR 
        LOWER(p.description) ILIKE $${params.length})`
    );
  }

  const whereClause = `WHERE ${conditions.join(' AND ')}`;

  // Count query
  const { rows: [{ total }] } = await query(
    `SELECT COUNT(*)::int AS total FROM products p ${whereClause}`,
    params
  );

  // List query
  const listParams = [...params, limit, offset];
  const { rows: products } = await query(
    `SELECT p.*, c.name as category_name 
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      ${whereClause}
      ORDER BY p.id DESC
      LIMIT $${listParams.length - 1} 
      OFFSET $${listParams.length}`,
    listParams
  );

  // Format products with full schema
  const formattedProducts = products.map(p => formatProduct(p, weight_g));

  const pages = Math.ceil(Number(total) / limit);
  const data = { products: formattedProducts, total: Number(total), page, pages, limit };

  await redis.set(cacheKey, JSON.stringify(data), 'EX', CACHE_TTL_PRODUCTS);
  return res.json({ success: true, data });
});

const listProducts = getAllProducts; // compat

const getProductById = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const weight_g = req.query.weight_g ? Number(req.query.weight_g) : null;
  const cacheKey = `products:id:${id}`;
  let cached = await redis.get(cacheKey);
  if (cached) {
    const data = JSON.parse(cached);
    return res.json({ success: true, data: { product: formatProduct(data.product, weight_g) } });
  }

  const { rows } = await query('SELECT * FROM products WHERE id = $1 AND active = true', [id]);
  if (!rows[0]) return fail(res, 404, 'Not found');

  const product = rows[0];

  // Check freshness
  if (!isProductFresh(product.freshness_date)) {
    return fail(res, 400, 'FRESHNESS_EXPIRED', 'This product is no longer fresh');
  }

  await redis.set(cacheKey, JSON.stringify(product), 'EX', CACHE_TTL_PRODUCT);
  return res.json({ success: true, data: { product: formatProduct(product, weight_g) } });
});

const getCategories = asyncHandler(async (req, res) => {
  const cacheKey = 'products:categories';
  let cached = await redis.get(cacheKey);
  if (cached) return res.json({ success: true, data: { categories: JSON.parse(cached) } });

  const { rows } = await query('SELECT id, name FROM categories WHERE active = true ORDER BY sort_order');
  const categories = rows.map(r => ({
    id: r.id,
    name: r.name,
    slug: r.name.toLowerCase().replace(/[^a-z]/g, '-')
  }));

  await redis.set(cacheKey, JSON.stringify(categories), 'EX', CACHE_TTL_CATEGORIES);
  return res.json({ success: true, data: { categories } });
});

const getFeaturedProducts = asyncHandler(async (req, res) => {
  const cacheKey = 'products:featured';
  let cached = await redis.get(cacheKey);
  if (cached) return res.json({ success: true, data: { products: JSON.parse(cached) } });

  // Get fresh products only
  const { rows } = await query(
    `SELECT * FROM products 
     WHERE active = true 
       AND (freshness_date IS NULL OR freshness_date >= CURRENT_DATE - INTERVAL '2 days')
     ORDER BY id DESC LIMIT 10`
  );

  const formattedProducts = rows.map(p => formatProduct(p));
  await redis.set(cacheKey, JSON.stringify(formattedProducts), 'EX', CACHE_TTL_FEATURED);
  return res.json({ success: true, data: { products: formattedProducts } });
});

const searchProducts = asyncHandler(async (req, res) => {
  const { q } = req.query;
  if (!q || q.toString().trim().length < 2) return fail(res, 400, 'Min 2 chars');
  req.query.q = q;
  req.query.limit = 20;
  return getAllProducts(req, res);
});

// Admin CRUD - Updated with new schema
const createProduct = asyncHandler(async (req, res) => {
  requireAdmin(req);
  const body = req.validated.body;

  // Parse marination_options if provided as string
  let marinationOptions = body.marination_options;
  if (typeof marinationOptions === 'string') {
    try {
      marinationOptions = JSON.parse(marinationOptions);
    } catch (e) {
      marinationOptions = null;
    }
  }

  // Parse weight_variants if provided as string
  let weightVariants = body.weight_variants;
  if (typeof weightVariants === 'string') {
    try {
      weightVariants = JSON.parse(weightVariants);
    } catch (e) {
      weightVariants = [250, 500, 1000];
    }
  }

  // Parse cut_types if provided as string
  let cutTypes = body.cut_types;
  if (typeof cutTypes === 'string') {
    try {
      cutTypes = JSON.parse(cutTypes);
    } catch (e) {
      cutTypes = null;
    }
  }

  const { rows } = await query(
    `INSERT INTO products (
      category_id, name, description, base_price_per_kg, price, 
      weight_variants, cut_types, marination_options, freshness_date,
      image_url, stock, unit, active
    )
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *`,
    [
      body.category_id || null,
      body.name,
      body.description || null,
      body.base_price_per_kg || body.price || null,
      body.price || null, // Keep legacy price for compatibility
      Array.isArray(weightVariants) ? weightVariants : [250, 500, 1000],
      Array.isArray(cutTypes) ? cutTypes : null,
      marinationOptions ? JSON.stringify(marinationOptions) : null,
      body.freshness_date || null,
      body.image_url || null,
      body.stock || 0,
      body.unit || null,
      body.active !== undefined ? body.active : true
    ]
  );

  await redis.del('products:*');
  logger.info('product_created', { id: rows[0].id });
  return created(res, { product: formatProduct(rows[0]) });
});

const updateProduct = asyncHandler(async (req, res) => {
  requireAdmin(req);
  const id = Number(req.params.id);
  const patch = req.body;
  const sets = [], params = [];

  const allowed = [
    'category_id', 'name', 'description', 'price', 'base_price_per_kg',
    'weight_variants', 'cut_types', 'marination_options', 'freshness_date',
    'image_url', 'stock', 'unit', 'active'
  ];

  for (const k of allowed) {
    if (patch[k] !== undefined) {
      let value = patch[k];

      // Handle array/JSON fields
      if (k === 'weight_variants' && typeof value === 'string') {
        try { value = JSON.parse(value); } catch (e) { }
      }
      if (k === 'cut_types' && typeof value === 'string') {
        try { value = JSON.parse(value); } catch (e) { }
      }
      if (k === 'marination_options' && typeof value === 'string') {
        try { value = JSON.parse(value); } catch (e) { }
      }

      params.push(value);
      sets.push(k + '= $' + params.length);
    }
  }

  if (!sets.length) return fail(res, 400, 'No fields');
  params.push(id);
  const { rows } = await query(
    `UPDATE products SET ${sets.join(',')} WHERE id=$${params.length} RETURNING *`,
    params
  );
  if (!rows[0]) return fail(res, 404);
  await redis.del('products:*');
  logger.info('product_updated', { id });
  return ok(res, { product: formatProduct(rows[0]) });
});

const deleteProduct = asyncHandler(async (req, res) => {
  requireAdmin(req);
  const id = Number(req.params.id);
  const { rows } = await query('UPDATE products SET active=false WHERE id=$1 RETURNING id', [id]);
  if (!rows[0]) return fail(res, 404);
  await redis.del('products:*');
  logger.info('product_deleted', { id });
  return ok(res, { message: 'Soft deleted' });
});

module.exports = {
  listProducts, getAllProducts,
  getProductById,
  getCategories,
  getFeaturedProducts,
  searchProducts,
  createProduct,
  updateProduct,
  deleteProduct,
  formatProduct
};