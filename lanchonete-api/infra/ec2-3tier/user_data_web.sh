#!/bin/bash
# Camada 1 — Web: Nginx + frontend estático
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

APP_HOST="${APP_HOST}"

# ── Sistema + Nginx ───────────────────────────────────────────────────────────
dnf update -y
dnf install -y nginx nmap-ncat

# ── Aguarda App ficar disponível ──────────────────────────────────────────────
echo "Aguardando App em $APP_HOST:3000..."
for i in $(seq 1 40); do
  if nc -z "$APP_HOST" 3000 2>/dev/null; then
    echo "App disponivel"
    break
  fi
  echo "  tentativa $i/40 — aguardando 15s..."
  sleep 15
done

# ── Frontend ──────────────────────────────────────────────────────────────────
mkdir -p /usr/share/nginx/html/lanchonete
cat > /usr/share/nginx/html/lanchonete/index.html <<'HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lanchonete</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: Arial, sans-serif; background: #f5f5f5; color: #333; }
    header { background: #d32f2f; color: white; padding: 1rem 2rem; display: flex; align-items: center; gap: 2rem; }
    header h1 { font-size: 1.5rem; }
    nav button { background: transparent; border: 2px solid white; color: white; padding: 0.4rem 1rem; border-radius: 4px; cursor: pointer; font-size: 0.9rem; }
    nav button.active, nav button:hover { background: white; color: #d32f2f; }
    main { max-width: 1100px; margin: 2rem auto; padding: 0 1rem; }
    section { display: none; }
    section.active { display: block; }
    h2 { margin-bottom: 1.5rem; color: #d32f2f; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 1rem; }
    .card { background: white; border-radius: 8px; padding: 1rem; box-shadow: 0 2px 4px rgba(0,0,0,.1); }
    .card h3 { font-size: 1rem; margin-bottom: 0.3rem; }
    .card p { font-size: 0.85rem; color: #666; margin-bottom: 0.5rem; }
    .card .preco { font-size: 1.1rem; font-weight: bold; color: #d32f2f; }
    .card .tempo { font-size: 0.8rem; color: #888; }
    .categoria-titulo { font-size: 1.1rem; font-weight: bold; color: #555; margin: 1.5rem 0 0.5rem; text-transform: capitalize; border-bottom: 2px solid #eee; padding-bottom: 0.3rem; }
    form { background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,.1); max-width: 700px; }
    .form-row { margin-bottom: 1rem; }
    label { display: block; font-size: 0.9rem; margin-bottom: 0.3rem; font-weight: bold; }
    input[type=text], input[type=number] { width: 100%; padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; font-size: 1rem; }
    .itens-list { max-height: 350px; overflow-y: auto; border: 1px solid #eee; border-radius: 4px; padding: 0.5rem; }
    .item-row { display: flex; align-items: center; gap: 0.5rem; padding: 0.4rem 0; border-bottom: 1px solid #f0f0f0; }
    .item-row:last-child { border-bottom: none; }
    .item-row label { flex: 1; font-weight: normal; margin: 0; }
    .item-row input[type=number] { width: 60px; }
    .item-row .preco { font-size: 0.85rem; color: #d32f2f; min-width: 60px; text-align: right; }
    button[type=submit] { background: #d32f2f; color: white; border: none; padding: 0.7rem 2rem; border-radius: 4px; font-size: 1rem; cursor: pointer; margin-top: 1rem; }
    button[type=submit]:hover { background: #b71c1c; }
    .msg { padding: 0.8rem 1rem; border-radius: 4px; margin-bottom: 1rem; }
    .msg.ok  { background: #e8f5e9; color: #2e7d32; }
    .msg.err { background: #ffebee; color: #c62828; }
    table { width: 100%; border-collapse: collapse; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,.1); }
    th { background: #d32f2f; color: white; padding: 0.7rem 1rem; text-align: left; font-size: 0.9rem; }
    td { padding: 0.6rem 1rem; border-bottom: 1px solid #eee; font-size: 0.9rem; }
    tr:last-child td { border-bottom: none; }
    .badge { display: inline-block; padding: 0.2rem 0.5rem; border-radius: 12px; font-size: 0.75rem; font-weight: bold; }
    .badge.recebido   { background: #fff3e0; color: #e65100; }
    .badge.preparando { background: #e3f2fd; color: #1565c0; }
    .badge.pronto     { background: #e8f5e9; color: #2e7d32; }
    .badge.entregue   { background: #f3e5f5; color: #6a1b9a; }
    .badge.cancelado  { background: #fce4ec; color: #880e4f; }
    .refresh { background: #555; color: white; border: none; padding: 0.4rem 1rem; border-radius: 4px; cursor: pointer; font-size: 0.85rem; margin-bottom: 1rem; }
    .refresh:hover { background: #333; }
  </style>
</head>
<body>
<header>
  <h1>🍔 Lanchonete</h1>
  <nav>
    <button id="btn-cardapio" class="active" onclick="show('cardapio')">Cardápio</button>
    <button id="btn-pedido"              onclick="show('pedido')">Fazer Pedido</button>
    <button id="btn-pedidos"             onclick="show('pedidos')">Pedidos</button>
  </nav>
</header>
<main>
  <section id="sec-cardapio" class="active">
    <h2>Cardápio</h2>
    <div id="cardapio-content">Carregando...</div>
  </section>

  <section id="sec-pedido">
    <h2>Fazer Pedido</h2>
    <div id="pedido-msg"></div>
    <form id="form-pedido">
      <div class="form-row">
        <label>Mesa</label>
        <input type="number" id="mesa" min="1" max="200" required placeholder="Número da mesa">
      </div>
      <div class="form-row">
        <label>Seu nome</label>
        <input type="text" id="cliente" required placeholder="Nome do cliente" maxlength="100">
      </div>
      <div class="form-row">
        <label>Itens (informe a quantidade desejada)</label>
        <div class="itens-list" id="itens-list">Carregando cardápio...</div>
      </div>
      <button type="submit">Confirmar Pedido</button>
    </form>
  </section>

  <section id="sec-pedidos">
    <h2>Pedidos Recentes</h2>
    <button class="refresh" onclick="loadPedidos()">↻ Atualizar</button>
    <div id="pedidos-content">Carregando...</div>
  </section>
</main>

<script>
  const API = '/api';
  let cardapioCache = [];

  function show(id) {
    document.querySelectorAll('section').forEach(s => s.classList.remove('active'));
    document.querySelectorAll('nav button').forEach(b => b.classList.remove('active'));
    document.getElementById('sec-' + id).classList.add('active');
    document.getElementById('btn-' + id).classList.add('active');
    if (id === 'pedidos') loadPedidos();
  }

  function fmt(v) {
    return 'R$ ' + Number(v).toFixed(2).replace('.', ',');
  }

  async function loadCardapio() {
    try {
      const r = await fetch(API + '/cardapio');
      if (!r.ok) throw new Error(r.status);
      const json = await r.json();
      cardapioCache = json.data || json;

      const byCategoria = {};
      cardapioCache.forEach(item => {
        if (!byCategoria[item.categoria]) byCategoria[item.categoria] = [];
        byCategoria[item.categoria].push(item);
      });

      let html = '';
      for (const [cat, itens] of Object.entries(byCategoria)) {
        html += '<div class="categoria-titulo">' + cat + '</div><div class="grid">';
        itens.forEach(item => {
          html += '<div class="card">' +
            '<h3>' + item.nome + '</h3>' +
            '<p>' + (item.descricao || '') + '</p>' +
            '<div class="preco">' + fmt(item.preco) + '</div>' +
            '<div class="tempo">⏱ ' + item.tempo_preparo_min + ' min</div>' +
            '</div>';
        });
        html += '</div>';
      }
      document.getElementById('cardapio-content').innerHTML = html;

      // Preenche a lista de itens no formulário de pedido
      let itensHtml = '';
      cardapioCache.forEach(item => {
        itensHtml += '<div class="item-row">' +
          '<label>' + item.nome + '</label>' +
          '<span class="preco">' + fmt(item.preco) + '</span>' +
          '<input type="number" min="0" max="10" value="0" data-id="' + item.id + '" data-preco="' + item.preco + '">' +
          '</div>';
      });
      document.getElementById('itens-list').innerHTML = itensHtml;
    } catch (e) {
      document.getElementById('cardapio-content').innerHTML =
        '<p style="color:red">Erro ao carregar cardápio: ' + e.message + '</p>';
    }
  }

  document.getElementById('form-pedido').addEventListener('submit', async function(e) {
    e.preventDefault();
    const msgEl = document.getElementById('pedido-msg');
    msgEl.innerHTML = '';

    const mesa = parseInt(document.getElementById('mesa').value);
    const cliente_nome = document.getElementById('cliente').value.trim();
    const itens = [];

    document.querySelectorAll('#itens-list input[type=number]').forEach(inp => {
      const qty = parseInt(inp.value);
      if (qty > 0) {
        itens.push({ cardapio_id: parseInt(inp.dataset.id), quantidade: qty });
      }
    });

    if (itens.length === 0) {
      msgEl.innerHTML = '<div class="msg err">Selecione pelo menos 1 item.</div>';
      return;
    }

    try {
      const r = await fetch(API + '/pedidos', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mesa, cliente_nome, itens })
      });
      const data = await r.json();
      if (!r.ok) throw new Error(data.error || r.status);
      msgEl.innerHTML = '<div class="msg ok">Pedido #' + data.pedido.id + ' criado! Total: ' + fmt(data.pedido.total) + '</div>';
      this.reset();
      document.querySelectorAll('#itens-list input[type=number]').forEach(i => i.value = 0);
    } catch (err) {
      msgEl.innerHTML = '<div class="msg err">Erro: ' + err.message + '</div>';
    }
  });

  async function loadPedidos() {
    document.getElementById('pedidos-content').innerHTML = 'Carregando...';
    try {
      const r = await fetch(API + '/pedidos');
      if (!r.ok) throw new Error(r.status);
      const json = await r.json();
      const rows = json.data || [];
      if (rows.length === 0) {
        document.getElementById('pedidos-content').innerHTML = '<p>Nenhum pedido nas últimas 24h.</p>';
        return;
      }
      let html = '<table><thead><tr><th>#</th><th>Mesa</th><th>Cliente</th><th>Status</th><th>Total</th><th>Horário</th></tr></thead><tbody>';
      rows.forEach(p => {
        const dt = new Date(p.created_at).toLocaleString('pt-BR');
        html += '<tr>' +
          '<td>' + p.id + '</td>' +
          '<td>' + p.mesa + '</td>' +
          '<td>' + p.cliente_nome + '</td>' +
          '<td><span class="badge ' + p.status + '">' + p.status + '</span></td>' +
          '<td>' + fmt(p.total) + '</td>' +
          '<td>' + dt + '</td>' +
          '</tr>';
      });
      html += '</tbody></table>';
      document.getElementById('pedidos-content').innerHTML = html;
    } catch (e) {
      document.getElementById('pedidos-content').innerHTML =
        '<p style="color:red">Erro ao carregar pedidos: ' + e.message + '</p>';
    }
  }

  loadCardapio();
</script>
</body>
</html>
HTML

# ── Nginx ─────────────────────────────────────────────────────────────────────
cat > /etc/nginx/conf.d/lanchonete.conf <<NGINX
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html/lanchonete;
    index index.html;

    # Proxy da API para a camada App
    location /api/ {
        proxy_pass         http://$APP_HOST:3000/;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
        proxy_read_timeout    30s;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINX

# Remove configuração padrão do nginx
rm -f /etc/nginx/conf.d/default.conf

systemctl enable --now nginx

echo "✅ Camada Web pronta — acesse http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
