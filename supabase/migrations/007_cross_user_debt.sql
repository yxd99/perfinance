-- ============================================================================
-- Migration 007: Cross-User Debt (mirrored debts)
-- ============================================================================
-- Creates the server-side projection that lets a registered debtor see
-- a creditor's receivable as a read-only "mirrored debt" in their own account.
--
-- Architecture:
--   user_profiles      — narrow email→user_id lookup surface (SECURITY DEFINER only)
--   mirrored_debts     — debtor-owned projection of a receivable
--   mirrored_debt_payments — payment history mirrored from receivable_payments (no note)
--   4 SECURITY DEFINER triggers drive all writes:
--     trg_receivable_upsert_mirror   — on receivable INSERT/UPDATE
--     trg_receivable_soft_delete     — BEFORE receivable DELETE → sets status='revoked'
--     trg_payment_sync_mirror        — on receivable_payment INS/UPD/DEL
--     trg_backfill_on_register       — on user_profiles INSERT (new user registration)
-- ============================================================================

-- ============ user_profiles: the ONLY email→user_id surface ============

CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_email
  ON user_profiles(lower(trim(email)));

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- A user may read ONLY their own profile from the client.
-- The resolver RPC bypasses RLS (SECURITY DEFINER).
CREATE POLICY "user_profiles_self_read" ON user_profiles
  FOR SELECT USING (auth.uid() = id);

-- No client INSERT/UPDATE/DELETE policy: profiles are populated by trigger only.

-- Populate from auth.users on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email)
  VALUES (NEW.id, lower(trim(NEW.email)))
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- One-time backfill of existing users
INSERT INTO public.user_profiles (id, email)
  SELECT id, lower(trim(email)) FROM auth.users
  ON CONFLICT (id) DO NOTHING;


-- ============ mirrored_debts (debtor-owned projection) ============

CREATE TABLE IF NOT EXISTS mirrored_debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receivable_id UUID NOT NULL,                 -- NO FK: must survive receivable hard-delete (soft-delete model)
  debtor_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  creditor_user_id UUID NOT NULL,
  creditor_email TEXT NOT NULL,
  debtor_name TEXT,                            -- as the creditor labeled them
  total_amount NUMERIC(15,2) NOT NULL,
  description TEXT,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'active',       -- active | revoked
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (receivable_id, debtor_user_id)       -- idempotency: one mirror per receivable per debtor
);

CREATE INDEX IF NOT EXISTS idx_mirrored_debts_debtor ON mirrored_debts(debtor_user_id);

ALTER TABLE mirrored_debts ENABLE ROW LEVEL SECURITY;

-- Debtor can READ their own mirrors
CREATE POLICY "mirrored_debts_debtor_read" ON mirrored_debts
  FOR SELECT USING (auth.uid() = debtor_user_id);

-- Debtor may DELETE only when revoked.
-- NO INSERT/UPDATE policy => clients can never write (triggers use SECURITY DEFINER).
CREATE POLICY "mirrored_debts_debtor_delete_revoked" ON mirrored_debts
  FOR DELETE USING (auth.uid() = debtor_user_id AND status = 'revoked');


-- ============ mirrored_debt_payments ============

CREATE TABLE IF NOT EXISTS mirrored_debt_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mirrored_debt_id UUID NOT NULL REFERENCES mirrored_debts(id) ON DELETE CASCADE,
  source_payment_id UUID NOT NULL,             -- the receivable_payments.id this mirrors
  amount NUMERIC(15,2) NOT NULL,
  date DATE NOT NULL,
  -- NOTE: note column is DELIBERATELY absent — creditor's private notes never leak to debtor
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (mirrored_debt_id, source_payment_id)
);

CREATE INDEX IF NOT EXISTS idx_mirrored_pay_debt ON mirrored_debt_payments(mirrored_debt_id);

ALTER TABLE mirrored_debt_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mirrored_pay_debtor_read" ON mirrored_debt_payments
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM mirrored_debts m
    WHERE m.id = mirrored_debt_id AND m.debtor_user_id = auth.uid()
  ));

-- delete cascades from mirrored_debts; debtor delete of payments handled via parent cascade.

-- updated_at triggers (reuse existing update_updated_at() function from earlier migrations)
CREATE TRIGGER mirrored_debts_updated_at
  BEFORE UPDATE ON mirrored_debts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER mirrored_pay_updated_at
  BEFORE UPDATE ON mirrored_debt_payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ============ resolver RPC + upsert helper (SECURITY DEFINER) ============
-- Resolves debtor by email, upserts the mirror idempotently.
-- Returns the mirror id or NULL.

CREATE OR REPLACE FUNCTION public.link_receivable_to_debtor(p_receivable_id UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec receivables%ROWTYPE;
  v_debtor_id UUID;
  v_mirror_id UUID;
BEGIN
  SELECT * INTO v_rec FROM receivables WHERE id = p_receivable_id;
  IF NOT FOUND OR v_rec.debtor_email IS NULL THEN RETURN NULL; END IF;

  SELECT id INTO v_debtor_id FROM user_profiles
    WHERE lower(trim(email)) = lower(trim(v_rec.debtor_email)) LIMIT 1;
  IF v_debtor_id IS NULL THEN RETURN NULL; END IF;          -- not registered yet → backfill later
  IF v_debtor_id = v_rec.user_id THEN RETURN NULL; END IF;  -- self-debt guard (EC-17)

  INSERT INTO mirrored_debts (
    receivable_id, debtor_user_id, creditor_user_id, creditor_email,
    debtor_name, total_amount, description, due_date, status
  )
  SELECT v_rec.id, v_debtor_id, v_rec.user_id,
         (SELECT email FROM user_profiles WHERE id = v_rec.user_id),
         v_rec.debtor_name, v_rec.total_amount, v_rec.description, v_rec.due_date, 'active'
  ON CONFLICT (receivable_id, debtor_user_id) DO UPDATE SET
    total_amount = EXCLUDED.total_amount,
    description  = EXCLUDED.description,
    due_date     = EXCLUDED.due_date,
    -- never resurrect a revoked mirror on a stray update
    status       = CASE WHEN mirrored_debts.status = 'revoked' THEN 'revoked' ELSE 'active' END,
    updated_at   = now()
  RETURNING id INTO v_mirror_id;
  RETURN v_mirror_id;
END; $$;


-- ============ trigger: receivable INSERT/UPDATE → upsert mirror ============

CREATE OR REPLACE FUNCTION public.fn_receivable_upsert_mirror()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.link_receivable_to_debtor(NEW.id);
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_receivable_upsert_mirror ON receivables;
CREATE TRIGGER trg_receivable_upsert_mirror
  AFTER INSERT OR UPDATE ON receivables
  FOR EACH ROW EXECUTE FUNCTION public.fn_receivable_upsert_mirror();


-- ============ trigger: receivable BEFORE DELETE → soft-delete revoke ============
-- BEFORE (not AFTER) so the receivable_id link still exists when we update mirrored_debts.

CREATE OR REPLACE FUNCTION public.fn_receivable_soft_delete_mirror()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE mirrored_debts
    SET status = 'revoked', revoked_at = now(), updated_at = now()
    WHERE receivable_id = OLD.id AND status <> 'revoked';
  RETURN OLD;                                  -- allow the delete to proceed
END; $$;

DROP TRIGGER IF EXISTS trg_receivable_soft_delete ON receivables;
CREATE TRIGGER trg_receivable_soft_delete
  BEFORE DELETE ON receivables
  FOR EACH ROW EXECUTE FUNCTION public.fn_receivable_soft_delete_mirror();


-- ============ trigger: receivable_payment INS/UPD/DEL → sync mirror payments ============
-- Copies amount+date ONLY. The note column is deliberately NOT copied.

CREATE OR REPLACE FUNCTION public.fn_payment_sync_mirror()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_mirror_id UUID;
  v_rid UUID;
BEGIN
  v_rid := COALESCE(NEW.receivable_id, OLD.receivable_id);
  SELECT id INTO v_mirror_id FROM mirrored_debts WHERE receivable_id = v_rid LIMIT 1;
  IF v_mirror_id IS NULL THEN RETURN COALESCE(NEW, OLD); END IF;  -- no debtor mirror, nothing to sync

  IF TG_OP = 'DELETE' THEN
    DELETE FROM mirrored_debt_payments
      WHERE mirrored_debt_id = v_mirror_id AND source_payment_id = OLD.id;
  ELSE
    INSERT INTO mirrored_debt_payments (mirrored_debt_id, source_payment_id, amount, date)
      VALUES (v_mirror_id, NEW.id, NEW.amount, NEW.date)  -- note column NOT copied
    ON CONFLICT (mirrored_debt_id, source_payment_id) DO UPDATE SET
      amount = EXCLUDED.amount,
      date   = EXCLUDED.date,
      updated_at = now();
  END IF;
  RETURN COALESCE(NEW, OLD);
END; $$;

DROP TRIGGER IF EXISTS trg_payment_sync_mirror ON receivable_payments;
CREATE TRIGGER trg_payment_sync_mirror
  AFTER INSERT OR UPDATE OR DELETE ON receivable_payments
  FOR EACH ROW EXECUTE FUNCTION public.fn_payment_sync_mirror();


-- ============ trigger: new user_profiles row → backfill pending receivables ============

CREATE OR REPLACE FUNCTION public.fn_backfill_mirrors_on_register()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r receivables%ROWTYPE;
BEGIN
  FOR r IN
    SELECT * FROM receivables
    WHERE lower(trim(debtor_email)) = lower(trim(NEW.email)) AND user_id <> NEW.id
  LOOP
    PERFORM public.link_receivable_to_debtor(r.id);  -- idempotent
    -- backfill existing payments for this receivable
    INSERT INTO mirrored_debt_payments (mirrored_debt_id, source_payment_id, amount, date)
      SELECT m.id, rp.id, rp.amount, rp.date
        FROM mirrored_debts m
        JOIN receivable_payments rp ON rp.receivable_id = m.receivable_id
        WHERE m.receivable_id = r.id AND m.debtor_user_id = NEW.id
      ON CONFLICT (mirrored_debt_id, source_payment_id) DO NOTHING;
  END LOOP;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_backfill_on_register ON user_profiles;
CREATE TRIGGER trg_backfill_on_register
  AFTER INSERT ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.fn_backfill_mirrors_on_register();


-- ============ SQL Verification Checklist (run in SQL editor to validate) ============
--
-- (a) user_profiles backfill count:
--     SELECT COUNT(*) FROM user_profiles;
--     — should match: SELECT COUNT(*) FROM auth.users;
--
-- (b) trigger on new user with email normalized:
--     INSERT INTO auth.users (id, email, ...) VALUES (gen_random_uuid(), '  Alice@Example.COM  ', ...);
--     SELECT * FROM user_profiles WHERE email = 'alice@example.com';
--     — should return 1 row
--
-- (c) mirror created on receivable insert:
--     INSERT INTO receivables (id, user_id, debtor_name, debtor_email, total_amount, ...) VALUES (...);
--     SELECT * FROM mirrored_debts WHERE receivable_id = <inserted_id>;
--     — should return 1 row if debtor_email matched a user_profiles entry
--
-- (d) self-debt guard returns null:
--     SELECT link_receivable_to_debtor(<receivable_id_where_creditor_eq_debtor>);
--     — should return NULL
--
-- (e) soft-delete sets revoked:
--     DELETE FROM receivables WHERE id = <receivable_id>;
--     SELECT status, revoked_at FROM mirrored_debts WHERE receivable_id = <receivable_id>;
--     — status should be 'revoked', revoked_at should be set
--
-- (f) payment sync copies amount+date without note:
--     INSERT INTO receivable_payments (id, receivable_id, amount, date, note) VALUES (...);
--     SELECT * FROM mirrored_debt_payments WHERE source_payment_id = <payment_id>;
--     — should have amount+date, NO note column
--
-- (g) backfill on register creates mirrors:
--     Create receivable with debtor_email, then INSERT user with that email into auth.users
--     SELECT * FROM mirrored_debts WHERE debtor_user_id = <new_user_id>;
--     — should have rows for all receivables with that email
--
-- (h) RLS rejects debtor UPDATE on active mirror:
--     As debtor user: UPDATE mirrored_debts SET status = 'active' WHERE id = <mirror_id>;
--     — should be rejected (no UPDATE policy)
-- ============================================================================
