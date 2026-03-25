-- Deudas: compras a cuotas con fecha máximo de pago
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  total_amount NUMERIC(15,2) NOT NULL,
  number_of_installments INTEGER NOT NULL CHECK (number_of_installments >= 1),
  due_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS debt_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id UUID NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL,
  date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER debts_updated_at BEFORE UPDATE ON debts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER debt_payments_updated_at BEFORE UPDATE ON debt_payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "debts_user" ON debts
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "debt_payments_user" ON debt_payments
  FOR ALL USING (
    EXISTS (SELECT 1 FROM debts d WHERE d.id = debt_id AND d.user_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM debts d WHERE d.id = debt_id AND d.user_id = auth.uid())
  );
