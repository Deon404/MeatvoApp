# Dev-only scripts

Local development and integration tests only. **Not included in Docker production builds.**

Run from repo root, e.g.:

```bash
node backend/scripts/dev-only/test-connection.js
node backend/scripts/dev-only/test-otp-flow.js
```

Requires a populated `backend/.env` with valid secrets (see `backend/.env.example`).
