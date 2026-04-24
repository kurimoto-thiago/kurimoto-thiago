-- ── Seed — Cardápio inicial ──────────────────────────────────────────────────
INSERT INTO cardapio (nome, descricao, preco, categoria, tempo_preparo_min) VALUES
  -- Lanches
  ('X-Burguer',       'Pão brioche, carne 180g, queijo, alface, tomate, maionese da casa', 28.90, 'lanche',        12),
  ('X-Bacon',         'Pão brioche, carne 180g, bacon crocante, queijo cheddar, picles',   34.90, 'lanche',        15),
  ('X-Frango',        'Filé de frango grelhado, queijo, alface, tomate, maionese',         26.90, 'lanche',        12),
  ('X-Veggie',        'Hambúrguer de grão-de-bico, queijo, rúcula, tomate, guacamole',     30.90, 'lanche',        14),
  ('X-Tudo',          'Carne 180g, bacon, presunto, ovos, queijo duplo, salada completa',  42.90, 'lanche',        18),
  -- Acompanhamentos
  ('Batata Frita P',  'Porção pequena de batatas fritas crocantes',                         9.90, 'acompanhamento', 8),
  ('Batata Frita G',  'Porção grande de batatas fritas crocantes',                         15.90, 'acompanhamento',10),
  ('Onion Rings',     'Anéis de cebola empanados, porção com 8 unidades',                  14.90, 'acompanhamento',10),
  ('Salada Caesar',   'Alface romana, croutons, parmesão, molho caesar',                   16.90, 'acompanhamento', 5),
  -- Bebidas
  ('Coca-Cola 350ml', 'Lata gelada',                                                        6.00, 'bebida',         1),
  ('Suco de Laranja', 'Natural, 300ml',                                                     9.90, 'bebida',         5),
  ('Milkshake',       'Chocolate, morango ou baunilha — 400ml',                            18.90, 'bebida',         7),
  ('Água Mineral',    '500ml, com ou sem gás',                                              4.00, 'bebida',         1),
  -- Sobremesas
  ('Brownie',         'Brownie de chocolate com sorvete de creme',                         14.90, 'sobremesa',      5),
  ('Sundae',          'Sorvete de creme com calda de chocolate ou morango',                11.90, 'sobremesa',      3),
  -- Combos
  ('Combo Clássico',  'X-Burguer + Batata Frita P + Coca-Cola 350ml',                     39.90, 'combo',          15),
  ('Combo Família',   '2x X-Burguer + 2x Batata Frita G + 2x Coca-Cola',                  79.90, 'combo',          20)
ON CONFLICT DO NOTHING;
