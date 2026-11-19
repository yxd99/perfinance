-- Color elegido por el usuario para cada tarjeta y cuenta de ahorro: posición
-- en la paleta de billetes de la app (0 verde, 1 azul, 2 naranja, 3 café,
-- 4 rosado). NULL = automático por orden de creación, como hasta ahora.
ALTER TABLE credit_cards
  ADD COLUMN IF NOT EXISTS color_slot SMALLINT CHECK (color_slot BETWEEN 0 AND 4);

ALTER TABLE payment_methods
  ADD COLUMN IF NOT EXISTS color_slot SMALLINT CHECK (color_slot BETWEEN 0 AND 4);
