# Database Migrations

## Order Status Migration

**Purpose:** Consolidate legacy order statuses into unified status system.

### Changes:
- `PICKED_UP` → `OUT_FOR_DELIVERY`
- `ON_THE_WAY` → `OUT_FOR_DELIVERY`
- Adds new statuses to order_status enum:
  - `PAYMENT_PENDING`
  - `PAYMENT_VERIFIED`
  - `PACKING_STARTED`
  - `RIDER_ASSIGNED`
  - `RIDER_ACCEPTED`
  - `RIDER_REJECTED`
  - `RIDER_NEARBY`
  - `REFUNDED`
  - `FAILED`

### How to Run:

**Option A — Terminal (Node.js script)**

Do NOT paste the `.js` file into pgAdmin. Run from the backend folder:

```bash
cd backend
node src/db/migrations/migrate_order_statuses.js
```

Requires `.env` with database credentials (same as the API).

**Option B — pgAdmin (SQL script)**

Open Query Tool and run the SQL file:

`backend/src/db/migrations/migrate_order_statuses.sql`

If `ADD VALUE` fails inside a transaction, run STEP 1 lines one by one, then run STEP 2.

### Rollback:

If you need to rollback, manually update:
```sql
-- This is safe because the migration is idempotent
-- Legacy statuses are mapped correctly in the code
```

### Safety:

- Migration runs in a transaction
- Backs up current state before changes
- Can be run multiple times safely
- Does not delete any data
