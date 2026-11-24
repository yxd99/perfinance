-- link_receivable_to_debtor es SECURITY DEFINER y no verifica quién la llama.
-- Solo la usan los triggers trg_receivable_upsert_mirror y
-- trg_backfill_on_register (que la ejecuta sobre receivables de otro usuario,
-- así que no puede exigir auth.uid() = user_id). La app no la llama.
-- Se quita EXECUTE a los clientes: deja de estar expuesta como RPC en PostgREST
-- y los triggers siguen funcionando porque corren como dueño de la función.

REVOKE EXECUTE ON FUNCTION public.link_receivable_to_debtor(UUID) FROM PUBLIC, anon, authenticated;
