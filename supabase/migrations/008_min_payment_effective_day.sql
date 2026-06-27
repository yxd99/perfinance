-- Migration 008: Add effective_day to min_payment_configs
-- Adds the effective_day column that determines which payments in a month
-- count toward the minimum payment progress.

ALTER TABLE min_payment_configs
  ADD COLUMN IF NOT EXISTS effective_day INTEGER NOT NULL DEFAULT 1;

-- Verify or create UNIQUE constraint on (card_id, year, month).
-- This ensures insert-ignore semantics on mobile match remote behavior.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'min_payment_configs'::regclass
      AND contype = 'u'
      AND conname = 'min_payment_configs_card_id_year_month_key'
  ) THEN
    ALTER TABLE min_payment_configs
      ADD CONSTRAINT min_payment_configs_card_id_year_month_key
      UNIQUE (card_id, year, month);
  END IF;
END
$$;
