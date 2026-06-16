# Database Security Report

**Date:** 2026-06-12

## SQL Injection Audit

**Verdict: No exploitable SQL injection found in runtime API code.**

### Safe Patterns Observed

1. **Parameterized queries:** All user values bound via `$1`, `$2`, …
2. **Column allowlists:** `PRODUCT_UPDATE_COLUMNS`, `ALLOWED_PRODUCT_COLUMNS`, etc.
3. **Dynamic WHERE clauses:** Placeholder indices computed safely (`nextParam()`)

### Files Reviewed (Dynamic SQL)

| File | Pattern | Risk |
|------|---------|------|
| `orders.controller.js` | Dynamic WHERE/LIMIT/OFFSET | Low ✅ |
| `admin.controller.js` | Column allowlist updates | Low ✅ |
| `products.controller.js` | Column allowlist | Low ✅ |
| `delivery.controller.js` | Static date conditions | Low ✅ |
| `payments.controller.js` | Static admin clause | Low ✅ |
| `migrate_order_statuses.js` | Migration-only string interp | Low (not runtime) |

### No Changes Required

All queries already use parameterized access. No string concatenation of user input detected.

## Schema Security Notes

| Item | Status | Notes |
|------|--------|-------|
| Foreign keys | ✅ Present in `schema.sql` | Orders → users, products |
| Indexes | ✅ On frequently queried columns | |
| `users.mfa_secret` plaintext | ⚠️ | Encrypt at rest recommended |
| `users.refresh_token_hash` | ✅ SHA-256 hash stored | |

## Recommendations

1. Encrypt `mfa_secret` column at application level
2. Add audit log table for admin mutations (future)
3. Review migration scripts before production deploy
