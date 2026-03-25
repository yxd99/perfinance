-- Añadir columna description a expenses (ejecutar en SQL Editor de Supabase si ya tienes la tabla)
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS description TEXT;
