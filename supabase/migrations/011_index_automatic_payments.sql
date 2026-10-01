CREATE INDEX IF NOT EXISTS idx_automatic_payments_user_next
  ON automatic_payments (user_id, next_run_date);
