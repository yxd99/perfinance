-- Destinatarios a los que send-receivable-notification puede enviar correos.
-- La primera vez que un usuario intenta enviar a un correo, la función inserta
-- la fila con approved = false y no envía. El dueño del proyecto revisa la
-- tabla en el dashboard de Supabase y pone approved = true para habilitarlo.
-- Solo en la nube: no se sincroniza a SQLite. Los clientes no tienen acceso;
-- la función la lee y escribe con la service role.

CREATE TABLE IF NOT EXISTS email_recipient_allowlist (
  requested_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Correo normalizado (trim + minúsculas); ver normalizeEmail() en la función.
  email TEXT NOT NULL CHECK (email = lower(btrim(email)) AND email <> ''),
  approved BOOLEAN NOT NULL DEFAULT false,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Último intento de envío, aprobado o no; sirve para monitorear el uso.
  last_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (requested_by, email)
);

CREATE INDEX IF NOT EXISTS email_recipient_allowlist_pending_idx
  ON email_recipient_allowlist (created_at DESC) WHERE NOT approved;

-- approved_at se llena solo al aprobar desde el dashboard.
CREATE OR REPLACE FUNCTION public.fn_email_allowlist_approved_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.approved AND (TG_OP = 'INSERT' OR NOT OLD.approved) THEN
    NEW.approved_at := now();
  ELSIF NOT NEW.approved THEN
    NEW.approved_at := NULL;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_email_allowlist_approved_at ON email_recipient_allowlist;
CREATE TRIGGER trg_email_allowlist_approved_at
  BEFORE INSERT OR UPDATE OF approved ON email_recipient_allowlist
  FOR EACH ROW EXECUTE FUNCTION public.fn_email_allowlist_approved_at();

-- RLS sin políticas: anon y authenticated no pueden leer ni escribir.
ALTER TABLE email_recipient_allowlist ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON email_recipient_allowlist FROM anon, authenticated;
