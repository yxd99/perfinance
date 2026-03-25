-- Perfinance: esquema Supabase (PostgreSQL) con RLS
-- Ejecutar en SQL Editor del dashboard de Supabase

-- Tablas con user_id y updated_at para sync

CREATE TABLE IF NOT EXISTS credit_cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alias TEXT NOT NULL,
  cut_off_day INTEGER NOT NULL CHECK (cut_off_day >= 1 AND cut_off_day <= 31),
  management_fee NUMERIC(15,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'other',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL,
  date TIMESTAMPTZ NOT NULL,
  payment_type TEXT NOT NULL CHECK (payment_type IN ('credit_card', 'payment_method')),
  payment_ref UUID NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS card_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id UUID NOT NULL REFERENCES credit_cards(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL,
  date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS min_payment_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id UUID NOT NULL REFERENCES credit_cards(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(card_id, year, month)
);

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER credit_cards_updated_at BEFORE UPDATE ON credit_cards
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER payment_methods_updated_at BEFORE UPDATE ON payment_methods
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER expenses_updated_at BEFORE UPDATE ON expenses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER card_payments_updated_at BEFORE UPDATE ON card_payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER min_payment_configs_updated_at BEFORE UPDATE ON min_payment_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS: habilitar en todas las tablas
ALTER TABLE credit_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE min_payment_configs ENABLE ROW LEVEL SECURITY;

-- Políticas: usuario solo ve/modifica sus datos
CREATE POLICY "credit_cards_user" ON credit_cards
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "payment_methods_user" ON payment_methods
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "expenses_user" ON expenses
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- card_payments y min_payment_configs: acceso si la tarjeta es del usuario
CREATE POLICY "card_payments_user" ON card_payments
  FOR ALL USING (
    EXISTS (SELECT 1 FROM credit_cards c WHERE c.id = card_id AND c.user_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM credit_cards c WHERE c.id = card_id AND c.user_id = auth.uid())
  );

CREATE POLICY "min_payment_configs_user" ON min_payment_configs
  FOR ALL USING (
    EXISTS (SELECT 1 FROM credit_cards c WHERE c.id = card_id AND c.user_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM credit_cards c WHERE c.id = card_id AND c.user_id = auth.uid())
  );
