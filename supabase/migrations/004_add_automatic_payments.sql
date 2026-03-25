-- Pagos automáticos: generan egresos recurrentes en la fecha programada
CREATE TABLE IF NOT EXISTS automatic_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payment_type TEXT NOT NULL CHECK (payment_type IN ('credit_card', 'payment_method')),
  payment_ref UUID NOT NULL,
  amount NUMERIC(15,2) NOT NULL,
  description TEXT NOT NULL,
  next_run_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER automatic_payments_updated_at BEFORE UPDATE ON automatic_payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE automatic_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "automatic_payments_user" ON automatic_payments
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
