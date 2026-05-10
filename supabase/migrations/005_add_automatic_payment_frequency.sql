-- Agrega día canónico de pago y frecuencia a pagos automáticos
ALTER TABLE automatic_payments
  ADD COLUMN IF NOT EXISTS payment_day_of_month SMALLINT NOT NULL DEFAULT 1
    CHECK (payment_day_of_month BETWEEN 1 AND 31),
  ADD COLUMN IF NOT EXISTS frequency TEXT NOT NULL DEFAULT 'mensual'
    CHECK (frequency IN ('mensual', 'trimestral', 'semestral', 'anual'));

-- Backfill: extrae el día del next_run_date existente
UPDATE automatic_payments
SET payment_day_of_month = EXTRACT(DAY FROM next_run_date)::SMALLINT
WHERE payment_day_of_month = 1;
