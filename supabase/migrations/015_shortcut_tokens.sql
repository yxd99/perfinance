-- Personal token that lets an iOS Shortcut (Wallet transaction automation)
-- create expenses through the log-wallet-expense edge function without a
-- session JWT. Only the SHA-256 hash is stored; one token per user.

CREATE TABLE IF NOT EXISTS shortcut_tokens (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  -- Device offset from UTC, so the expense gets the user's local date.
  utc_offset_minutes INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ
);

ALTER TABLE shortcut_tokens ENABLE ROW LEVEL SECURITY;

-- The owner can see whether a token exists and revoke it. Rows are written
-- only by create_shortcut_token and read by the edge function (service role).
DROP POLICY IF EXISTS "shortcut_tokens_owner_read" ON shortcut_tokens;
CREATE POLICY "shortcut_tokens_owner_read" ON shortcut_tokens
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "shortcut_tokens_owner_delete" ON shortcut_tokens;
CREATE POLICY "shortcut_tokens_owner_delete" ON shortcut_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- Creates (or replaces) the caller's token and returns it in clear ONCE.
CREATE OR REPLACE FUNCTION public.create_shortcut_token(p_utc_offset_minutes INTEGER)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user UUID := auth.uid();
  v_token TEXT := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO shortcut_tokens (user_id, token_hash, utc_offset_minutes)
    VALUES (v_user, encode(sha256(convert_to(v_token, 'UTF8')), 'hex'), p_utc_offset_minutes)
  ON CONFLICT (user_id) DO UPDATE SET
    token_hash = EXCLUDED.token_hash,
    utc_offset_minutes = EXCLUDED.utc_offset_minutes,
    created_at = now(),
    last_used_at = NULL;

  RETURN v_token;
END; $$;

REVOKE ALL ON FUNCTION public.create_shortcut_token(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_shortcut_token(INTEGER) TO authenticated;
