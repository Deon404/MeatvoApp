# Risk Assessment

## Critical Risks

| Risk | Probability | Impact | Mitigation | Rollback |
|------|-------------|--------|------------|----------|
| Payment webhook failure | Medium | Critical | Base64 signature fix; sandbox test | COD-only mode |
| DB migration failure | Low | Critical | Idempotent migrations; backup first | Restore pg_dump |
| Security breach (IDOR) | Low (fixed) | Critical | Ownership checks deployed | Audit orders, notify users |
| SSL cert failure | Medium | High | Certbot dry-run; HTTP fallback temp | ENFORCE_HTTPS=false |

## High Risks

| Risk | Probability | Impact | Mitigation | Rollback |
|------|-------------|--------|------------|----------|
| Redis down | Medium | High | Password + systemd; PM2 restart | Memory fallback (dev only) |
| OTP SMS failure | Medium | Critical | MSG91 DLT verified; Twilio fallback | Dev bypass (emergency) |
| Flutter rejection | Medium | High | Internal track first; release signing | Fix and resubmit |

## Medium Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Socket disconnect | Medium | Medium | 5s polling fallback in Flutter |
| Disk full | Medium | Medium | Log rotation + backup retention |
| Maps quota exceeded | Medium | High | Enable billing; set quotas |

## Scaling Risks

- Single PM2 fork instance — upgrade to cluster mode at scale
- In-memory notification/rider cache — migrate to Redis at scale
