const asyncHandler = require('express-async-handler');
const { query } = require('../../db/postgres');
const { ok, created, fail } = require('../../utils/response');
const { ROLES } = require('../../utils/roles');
const { signStoredImageUrl, normalizeStoredImageUrl } = require('../../utils/uploadSigning');
const { getPublicBaseUrl } = require('../../utils/requestBaseUrl');

const listBanners = asyncHandler(async (req, res) => {
  const includeInactiveRequested = Boolean(req.validated?.query?.includeInactive);
  const includeInactive = req.user?.role === ROLES.ADMIN ? includeInactiveRequested : false;

  const { rows } = includeInactive
    ? await query(
        `SELECT id, image_url, active, sort_order
         FROM banners
         ORDER BY sort_order ASC, id DESC`
      )
    : await query(
        `SELECT id, image_url, active, sort_order
         FROM banners
         WHERE active = $1
         ORDER BY sort_order ASC, id DESC`,
        [true]
      );
  const baseUrl = getPublicBaseUrl(req);
  const banners = rows.map((b) => ({
    ...b,
    image_url: signStoredImageUrl(b.image_url || '', baseUrl),
  }));
  return ok(res, { banners }, 'Banners');
});

const createBanner = asyncHandler(async (req, res) => {
  const body = req.validated.body;
  const imageUrl = normalizeStoredImageUrl(body.image_url);
  const { rows } = await query(
    `INSERT INTO banners (image_url, active, sort_order)
     VALUES ($1,$2,$3)
     RETURNING id, image_url, active, sort_order`,
    [imageUrl, body.active ?? true, body.sort_order ?? 0]
  );
  const baseUrl = getPublicBaseUrl(req);
  return created(res, {
    banner: {
      ...rows[0],
      image_url: signStoredImageUrl(rows[0].image_url || '', baseUrl),
    },
  }, 'Banner created');
});

const deleteBanner = asyncHandler(async (req, res) => {
  const id = Number(req.validated.params.id);
  const { rows } = await query('UPDATE banners SET active = FALSE WHERE id = $1 RETURNING id', [id]);
  if (!rows[0]) return fail(res, 404, 'Banner not found');
  return ok(res, {}, 'Banner deleted');
});

module.exports = { listBanners, createBanner, deleteBanner };

