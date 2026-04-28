#!/bin/bash
# CLI da Lanchonete — uso: API_URL=http://<ip> ./lanchonete.sh
# Depende de: curl, jq

set -euo pipefail

API="${API_URL:-http://localhost:3000}"
RED='\033[0;31m' GRN='\033[0;32m' YLW='\033[1;33m' BLD='\033[1m' RST='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
get()  { curl -sf "$API$1"; }
post() { curl -sf -X POST -H 'Content-Type: application/json' -d "$2" "$API$1"; }
patch(){ curl -sf -X PATCH -H 'Content-Type: application/json' -d "$2" "$API$1"; }

header() { echo -e "\n${BLD}${RED}══ $1 ══${RST}"; }
ok()     { echo -e "${GRN}✔ $1${RST}"; }
err()    { echo -e "${RED}✖ $1${RST}"; }
ask()    { echo -en "${YLW}$1${RST} "; read -r REPLY; echo "$REPLY"; }

check_deps() {
  for cmd in curl jq; do
    command -v "$cmd" &>/dev/null || { err "Instale $cmd primeiro."; exit 1; }
  done
}

# ── Cardápio ──────────────────────────────────────────────────────────────────
ver_cardapio() {
  header "CARDÁPIO"
  get /cardapio | jq -r '
    .data
    | group_by(.categoria)[]
    | (.[0].categoria | ascii_upcase),
      (.[] | "  \(.id)\t\(.nome)\t\("R$ " + (.preco | tostring))\t(\(.tempo_preparo_min)min)")
  ' | column -t -s $'\t'
}

# ── Fazer pedido ──────────────────────────────────────────────────────────────
fazer_pedido() {
  header "NOVO PEDIDO"
  ver_cardapio

  MESA=$(ask "\nMesa:")
  NOME=$(ask "Seu nome:")

  ITENS='[]'
  while true; do
    ID=$(ask "ID do item (Enter para finalizar):")
    [[ -z "$ID" ]] && break
    QTD=$(ask "Quantidade:")
    OBS=$(ask "Observação (Enter para pular):")
    ITEM=$(jq -n --argjson id "$ID" --argjson q "$QTD" --arg o "$OBS" \
      '{cardapio_id:$id, quantidade:$q, observacao:$o}')
    ITENS=$(echo "$ITENS" | jq ". + [$ITEM]")
  done

  if [[ $(echo "$ITENS" | jq 'length') -eq 0 ]]; then
    err "Nenhum item selecionado."
    return
  fi

  PAYLOAD=$(jq -n \
    --argjson mesa "$MESA" \
    --arg nome "$NOME" \
    --argjson itens "$ITENS" \
    '{mesa:$mesa, cliente_nome:$nome, itens:$itens}')

  RESP=$(post /pedidos "$PAYLOAD")
  ID_PEDIDO=$(echo "$RESP" | jq -r '.pedido.id')
  TOTAL=$(echo "$RESP" | jq -r '.pedido.total')
  ok "Pedido #$ID_PEDIDO criado! Total: R$ $TOTAL"
}

# ── Ver pedidos ───────────────────────────────────────────────────────────────
ver_pedidos() {
  header "PEDIDOS (últimas 24h)"
  FILTRO=""
  STATUS=$(ask "Filtrar por status (Enter para todos):")
  [[ -n "$STATUS" ]] && FILTRO="?status=$STATUS"

  get "/pedidos$FILTRO" | jq -r '
    .data[]
    | "\(.id)\t Mesa \(.mesa)\t\(.cliente_nome)\t[\(.status)]\tR$ \(.total)\t\(.created_at[:16])"
  ' | column -t -s $'\t' || err "Nenhum pedido encontrado."
}

# ── Detalhe do pedido ─────────────────────────────────────────────────────────
detalhe_pedido() {
  header "DETALHE DO PEDIDO"
  ID=$(ask "Número do pedido:")
  get "/pedidos/$ID" | jq -r '
    "Pedido #\(.id) — Mesa \(.mesa) — \(.cliente_nome) [\(.status)]",
    "Itens:",
    (.itens[] | "  • \(.nome) x\(.quantidade) = R$ \(.subtotal)"),
    "─────────────────────",
    "Total: R$ \(.total)"
  '
}

# ── Atualizar status ──────────────────────────────────────────────────────────
atualizar_status() {
  header "ATUALIZAR STATUS"
  echo "Status válidos: recebido | preparando | pronto | entregue | cancelado"
  ID=$(ask "Número do pedido:")
  ST=$(ask "Novo status:")
  RESP=$(patch "/pedidos/$ID/status" "{\"status\":\"$ST\"}")
  ok "$(echo "$RESP" | jq -r '.message')"
}

# ── Verificar saúde ───────────────────────────────────────────────────────────
health() {
  header "SAÚDE DA API"
  get /health | jq .
  get /health/ready | jq . 2>/dev/null || true
}

# ── Menu principal ────────────────────────────────────────────────────────────
menu() {
  while true; do
    echo -e "\n${BLD}${RED}╔══════════════════════╗
║   🍔  LANCHONETE     ║
╚══════════════════════╝${RST}"
    echo -e "API: ${YLW}$API${RST}\n"
    echo "  1) Ver cardápio"
    echo "  2) Fazer pedido"
    echo "  3) Ver pedidos"
    echo "  4) Detalhe do pedido"
    echo "  5) Atualizar status"
    echo "  6) Saúde da API"
    echo "  0) Sair"
    OPC=$(ask "\nOpção:")
    case "$OPC" in
      1) ver_cardapio ;;
      2) fazer_pedido ;;
      3) ver_pedidos ;;
      4) detalhe_pedido ;;
      5) atualizar_status ;;
      6) health ;;
      0) echo "Até logo!"; exit 0 ;;
      *) err "Opção inválida." ;;
    esac
  done
}

check_deps
menu
