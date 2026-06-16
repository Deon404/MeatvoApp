# File Upload Security Report

**Date:** 2026-06-13  
**Status:** Complete (Task 2.10)

## Upload Endpoints

| Route | Role | Purpose |
|-------|------|---------|
| `POST /api/admin/upload/image` | Admin | Catalog/banner image upload |
| `POST /api/delivery/upload/proof` | Delivery rider | Delivery proof photo upload |
| `GET /uploads/images/:filename` | Signed URL or JWT | Secure image retrieval |

## Controls

| Control | Status |
|---------|--------|
| Max file size (5MB) | ✅ |
| MIME type allowlist | ✅ |
| Magic-byte verification | ✅ |
| Extension allowlist (`.jpg/.jpeg/.png/.gif/.webp`) | ✅ |
| Secure random filename (`{userId}_{timestamp}_{random}.ext`) | ✅ |
| Path traversal block | ✅ |
| Executable/script/archive block | ✅ |
| Basic malware signature scan | ✅ |
| Admin-only catalog upload | ✅ |
| Rider-only proof upload | ✅ |
| Signed URL access (`exp` + HMAC `sig`) | ✅ |
| JWT fallback (admin: any file; rider: own `{userId}_*` files) | ✅ |
| Unsigned storage paths in DB (`/uploads/images/...`) | ✅ |
| Signed URLs re-generated on API read | ✅ |
| Delivery proof URL ownership validation | ✅ |
| Proof persisted to `order_assignments.delivery_image_url` | ✅ |
| Correct `Content-Type` + `nosniff` on download | ✅ |

## Signed URL Flow

1. Upload returns `storagePath` (unsigned, for DB) and `url` (signed, for immediate display).
2. API responses re-sign stored paths via `signStoredImageUrl()`.
3. Direct GET requires valid `?exp=&sig=` or authorized Bearer JWT.

## Environment

| Variable | Purpose |
|----------|---------|
| `UPLOAD_SIGNING_SECRET` | HMAC secret (falls back to `JWT_ACCESS_SECRET`) |
| `UPLOAD_SIGN_TTL_SECONDS` | Signature TTL (default 7 days) |

## Remaining Risk

| Issue | Severity | Notes |
|-------|----------|-------|
| No ClamAV / external AV scan | LOW | Basic signature + magic-byte checks only |
| Signed URL TTL expiry in long-lived clients | LOW | Clients should refresh from API |

## Verdict

Upload security controls are production-ready for MVP launch. Public static `/uploads` serving has been removed.
