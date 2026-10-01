-- Maps an Apple Wallet card name to a Perfinance credit card or payment
-- method. log-wallet-expense inserts a row with no target the first time it
-- sees a name it cannot resolve; the user assigns it once from the app.
-- Cloud-only: not synced to the local SQLite database.

CREATE TABLE IF NOT EXISTS wallet_cards (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Normalized wallet_name (no accents, case or symbols); see cardKey() in the function.
  name_key TEXT NOT NULL,
  wallet_name TEXT NOT NULL,
  payment_type TEXT CHECK (payment_type IN ('credit_card', 'payment_method')),
  payment_ref UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, name_key),
  CHECK ((payment_type IS NULL) = (payment_ref IS NULL))
);

ALTER TABLE wallet_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_cards_owner_read" ON wallet_cards;
CREATE POLICY "wallet_cards_owner_read" ON wallet_cards
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "wallet_cards_owner_update" ON wallet_cards;
CREATE POLICY "wallet_cards_owner_update" ON wallet_cards
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "wallet_cards_owner_delete" ON wallet_cards;
CREATE POLICY "wallet_cards_owner_delete" ON wallet_cards
  FOR DELETE USING (auth.uid() = user_id);

-- Assigns a Wallet card to one of the caller's payment targets and moves the
-- expenses that were logged as "tarjeta sin identificar" for that card.
-- Returns how many expenses were corrected. Runs with the caller's RLS.
CREATE OR REPLACE FUNCTION public.assign_wallet_card(
  p_name_key TEXT,
  p_payment_type TEXT,
  p_payment_ref UUID
)
RETURNS INTEGER LANGUAGE plpgsql SET search_path = public AS $$
DECLARE
  v_name TEXT;
  v_suffix TEXT;
  v_fixed INTEGER;
BEGIN
  IF p_payment_type = 'credit_card' THEN
    PERFORM 1 FROM credit_cards WHERE id = p_payment_ref AND user_id = auth.uid();
  ELSIF p_payment_type = 'payment_method' THEN
    PERFORM 1 FROM payment_methods WHERE id = p_payment_ref AND user_id = auth.uid();
  ELSE
    RAISE EXCEPTION 'Invalid payment type';
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment target not found';
  END IF;

  UPDATE wallet_cards
    SET payment_type = p_payment_type, payment_ref = p_payment_ref, updated_at = now()
    WHERE user_id = auth.uid() AND name_key = p_name_key
    RETURNING wallet_name INTO v_name;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet card not found';
  END IF;

  v_suffix := ' (tarjeta sin identificar: ' || v_name || ')';
  UPDATE expenses
    SET payment_type = p_payment_type,
        payment_ref = p_payment_ref,
        description = left(description, length(description) - length(v_suffix))
    WHERE user_id = auth.uid()
      AND description LIKE '[Wallet]: %'
      AND lower(right(description, length(v_suffix))) = lower(v_suffix);
  GET DIAGNOSTICS v_fixed = ROW_COUNT;
  RETURN v_fixed;
END; $$;

REVOKE ALL ON FUNCTION public.assign_wallet_card(TEXT, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_wallet_card(TEXT, TEXT, UUID) TO authenticated;
