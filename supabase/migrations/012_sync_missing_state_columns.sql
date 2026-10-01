-- Columns that exist in the local SQLite schema (v7 / v12) but were never
-- created in Postgres. Without them every push of credit_cards, debts and
-- automatic_payments fails (PGRST204) and pull falls back to the defaults.

ALTER TABLE credit_cards
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE debts
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

ALTER TABLE debts DROP CONSTRAINT IF EXISTS debts_status_check;
ALTER TABLE debts
  ADD CONSTRAINT debts_status_check CHECK (status IN ('active', 'paid', 'hidden'));

ALTER TABLE automatic_payments
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';

ALTER TABLE automatic_payments DROP CONSTRAINT IF EXISTS automatic_payments_status_check;
ALTER TABLE automatic_payments
  ADD CONSTRAINT automatic_payments_status_check CHECK (status IN ('active', 'paused'));

NOTIFY pgrst, 'reload schema';
