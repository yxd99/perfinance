-- Agregar columna agent_type a chat_conversations para multi-agente

ALTER TABLE chat_conversations
  ADD COLUMN IF NOT EXISTS agent_type TEXT NOT NULL DEFAULT 'financialAdvisor';

CREATE INDEX IF NOT EXISTS idx_chat_conversations_agent
  ON chat_conversations(user_id, agent_type, updated_at DESC);
