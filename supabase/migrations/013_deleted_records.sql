-- Tombstones: every hard delete on a synced table is recorded here so other
-- devices can remove their local copy on the next pull. Rows keep being
-- deleted for real, so existing triggers, cascades and readers are untouched.

CREATE TABLE IF NOT EXISTS deleted_records (
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (table_name, record_id)
);

CREATE INDEX IF NOT EXISTS idx_deleted_records_user ON deleted_records(user_id, deleted_at);

ALTER TABLE deleted_records ENABLE ROW LEVEL SECURITY;

-- Read-only for clients: rows are written by the trigger below.
DROP POLICY IF EXISTS "deleted_records_owner_read" ON deleted_records;
CREATE POLICY "deleted_records_owner_read" ON deleted_records
  FOR SELECT USING (auth.uid() = user_id);

-- Child tables have no user_id: pass the parent table and FK column as
-- trigger arguments. When the parent is already gone (cascade) the deleting
-- user is used instead.
CREATE OR REPLACE FUNCTION public.fn_record_tombstone()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row JSONB := to_jsonb(OLD);
  v_user UUID;
BEGIN
  IF v_row ? 'user_id' THEN
    v_user := (v_row->>'user_id')::uuid;
  ELSE
    EXECUTE format('SELECT user_id FROM %I WHERE id = $1', TG_ARGV[0])
      INTO v_user USING (v_row->>TG_ARGV[1])::uuid;
    v_user := COALESCE(v_user, auth.uid());
  END IF;

  -- Skips account deletion (the user row is already gone) and unattributable deletes.
  IF v_user IS NULL OR NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_user) THEN
    RETURN OLD;
  END IF;

  INSERT INTO deleted_records (table_name, record_id, user_id)
    VALUES (TG_TABLE_NAME, OLD.id, v_user)
  ON CONFLICT (table_name, record_id) DO UPDATE SET deleted_at = now();
  RETURN OLD;
END; $$;

DROP TRIGGER IF EXISTS trg_tombstone ON credit_cards;
CREATE TRIGGER trg_tombstone AFTER DELETE ON credit_cards
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone();

DROP TRIGGER IF EXISTS trg_tombstone ON payment_methods;
CREATE TRIGGER trg_tombstone AFTER DELETE ON payment_methods
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone();

DROP TRIGGER IF EXISTS trg_tombstone ON expenses;
CREATE TRIGGER trg_tombstone AFTER DELETE ON expenses
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone();

DROP TRIGGER IF EXISTS trg_tombstone ON debts;
CREATE TRIGGER trg_tombstone AFTER DELETE ON debts
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone();

DROP TRIGGER IF EXISTS trg_tombstone ON automatic_payments;
CREATE TRIGGER trg_tombstone AFTER DELETE ON automatic_payments
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone();

DROP TRIGGER IF EXISTS trg_tombstone ON receivables;
CREATE TRIGGER trg_tombstone AFTER DELETE ON receivables
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone();

DROP TRIGGER IF EXISTS trg_tombstone ON card_payments;
CREATE TRIGGER trg_tombstone AFTER DELETE ON card_payments
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone('credit_cards', 'card_id');

DROP TRIGGER IF EXISTS trg_tombstone ON min_payment_configs;
CREATE TRIGGER trg_tombstone AFTER DELETE ON min_payment_configs
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone('credit_cards', 'card_id');

DROP TRIGGER IF EXISTS trg_tombstone ON debt_payments;
CREATE TRIGGER trg_tombstone AFTER DELETE ON debt_payments
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone('debts', 'debt_id');

DROP TRIGGER IF EXISTS trg_tombstone ON receivable_payments;
CREATE TRIGGER trg_tombstone AFTER DELETE ON receivable_payments
  FOR EACH ROW EXECUTE FUNCTION public.fn_record_tombstone('receivables', 'receivable_id');
