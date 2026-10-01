-- Incremental pull asks each table for rows changed since the last sync
-- (updated_at >= cursor). These indexes keep that lookup cheap as data grows.

CREATE INDEX IF NOT EXISTS idx_credit_cards_user_updated ON credit_cards(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_payment_methods_user_updated ON payment_methods(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_expenses_user_updated ON expenses(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_debts_user_updated ON debts(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_automatic_payments_user_updated ON automatic_payments(user_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_receivables_user_updated ON receivables(user_id, updated_at);

-- Child tables are scoped by RLS through their parent, so they are filtered by time only.
CREATE INDEX IF NOT EXISTS idx_card_payments_updated ON card_payments(updated_at);
CREATE INDEX IF NOT EXISTS idx_min_payment_configs_updated ON min_payment_configs(updated_at);
CREATE INDEX IF NOT EXISTS idx_debt_payments_updated ON debt_payments(updated_at);
CREATE INDEX IF NOT EXISTS idx_receivable_payments_updated ON receivable_payments(updated_at);
