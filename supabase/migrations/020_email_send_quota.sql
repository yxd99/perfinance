-- Tope mensual de correos por cuenta, para no agotar la cuota de Resend.
-- Cuenta todos los correos que salen a nombre de un usuario: la exportación de
-- egresos (send-expense-export) y los avisos de cobro (send-receivable-notification).
--
-- Por defecto cada cuenta puede enviar 10 correos por mes calendario (hora de
-- Colombia). Para darle otro tope a una cuenta, agrega o edita su fila en
-- email_quotas desde el dashboard de Supabase. El uso queda en email_send_log.
-- Solo en la nube: no se sincroniza a SQLite. Los clientes no tienen acceso; las
-- funciones usan la service role.

CREATE TABLE IF NOT EXISTS email_quotas (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  monthly_limit INTEGER NOT NULL CHECK (monthly_limit >= 0),
  -- Motivo del cambio, para acordarte después.
  note TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS email_send_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('expense_export', 'receivable_notification')),
  recipient TEXT NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS email_send_log_user_sent_idx
  ON email_send_log (user_id, sent_at DESC);

-- RLS sin políticas: anon y authenticated no pueden leer ni escribir.
ALTER TABLE email_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_send_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON email_quotas FROM anon, authenticated;
REVOKE ALL ON email_send_log FROM anon, authenticated;

-- Reserva un envío si la cuenta tiene cupo este mes. Devuelve si se permitió,
-- cuántos lleva (con este), el tope y el id del registro (para liberarlo si
-- Resend falla). El lock por usuario evita que dos envíos simultáneos pasen
-- los dos con el último cupo.
CREATE OR REPLACE FUNCTION public.claim_email_send(p_user_id UUID, p_kind TEXT, p_recipient TEXT)
RETURNS TABLE (allowed BOOLEAN, sent_count INTEGER, quota INTEGER, log_id BIGINT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_quota INTEGER;
  v_used INTEGER;
  v_month_start TIMESTAMPTZ :=
    date_trunc('month', now() AT TIME ZONE 'America/Bogota') AT TIME ZONE 'America/Bogota';
  v_id BIGINT;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('email_quota:' || p_user_id::text, 0));

  SELECT q.monthly_limit INTO v_quota FROM email_quotas q WHERE q.user_id = p_user_id;
  v_quota := COALESCE(v_quota, 10);

  SELECT count(*)::INTEGER INTO v_used
    FROM email_send_log l
    WHERE l.user_id = p_user_id AND l.sent_at >= v_month_start;

  IF v_used >= v_quota THEN
    RETURN QUERY SELECT false, v_used, v_quota, NULL::BIGINT;
    RETURN;
  END IF;

  INSERT INTO email_send_log (user_id, kind, recipient)
    VALUES (p_user_id, p_kind, lower(btrim(p_recipient)))
    RETURNING id INTO v_id;
  RETURN QUERY SELECT true, v_used + 1, v_quota, v_id;
END; $$;

REVOKE ALL ON FUNCTION public.claim_email_send(UUID, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_email_send(UUID, TEXT, TEXT) TO service_role;

-- Uso del mes de la cuenta que llama, para mostrarlo en la app (Más › Correos
-- de este mes). Solo lectura y solo de auth.uid(): nadie ve el uso de otro.
-- Debe usar el mismo tope por defecto y el mismo inicio de mes que claim_email_send.
CREATE OR REPLACE FUNCTION public.my_email_quota()
RETURNS TABLE (sent_count INTEGER, quota INTEGER)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    (SELECT count(*)::INTEGER FROM email_send_log l
      WHERE l.user_id = auth.uid()
        AND l.sent_at >= date_trunc('month', now() AT TIME ZONE 'America/Bogota') AT TIME ZONE 'America/Bogota'),
    COALESCE((SELECT q.monthly_limit FROM email_quotas q WHERE q.user_id = auth.uid()), 10);
$$;

REVOKE ALL ON FUNCTION public.my_email_quota() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_email_quota() TO authenticated;
