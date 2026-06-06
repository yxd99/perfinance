-- Lo que me deben: receivables (money others owe the user) with partial payments
CREATE TABLE IF NOT EXISTS receivables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  debtor_name TEXT NOT NULL,
  debtor_email TEXT,
  total_amount NUMERIC(15,2) NOT NULL CHECK (total_amount > 0),
  description TEXT,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS receivable_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receivable_id UUID NOT NULL REFERENCES receivables(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
  date TIMESTAMPTZ NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_receivables_user ON receivables(user_id);
CREATE INDEX IF NOT EXISTS idx_recv_payments_recv ON receivable_payments(receivable_id);

CREATE TRIGGER receivables_updated_at BEFORE UPDATE ON receivables
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER receivable_payments_updated_at BEFORE UPDATE ON receivable_payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE receivables ENABLE ROW LEVEL SECURITY;
ALTER TABLE receivable_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "receivables_user" ON receivables
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "receivable_payments_user" ON receivable_payments
  FOR ALL USING (
    EXISTS (SELECT 1 FROM receivables r WHERE r.id = receivable_id AND r.user_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM receivables r WHERE r.id = receivable_id AND r.user_id = auth.uid())
  );
