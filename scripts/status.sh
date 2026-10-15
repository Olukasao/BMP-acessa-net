#!/bin/bash
# AcessaBMP - status dos servicos OpenBMP
set -euo pipefail
cd "$(dirname "$0")/.."

echo "======================================"
echo " OPENBMP STATUS (AcessaBMP)"
echo "======================================"
echo
if [ -f .env ]; then
  GRAFANA_BIND_IP=$(grep '^GRAFANA_BIND_IP=' .env | cut -d= -f2-)
  OBMP_DATA_ROOT=$(grep '^OBMP_DATA_ROOT=' .env | cut -d= -f2-)
fi
GRAFANA_BIND_IP=${GRAFANA_BIND_IP:-127.0.0.1}
OBMP_DATA_ROOT=${OBMP_DATA_ROOT:-/var/lib/accessabmp}

echo "--- Containers ---"
docker compose ps
echo
echo "--- Portas relevantes ---"
echo "BMP 5000 (0.0.0.0, publico p/ roteadores):"
ss -lntp 2>/dev/null | grep ':5000' || echo "  NAO ESTA OUVINDO"
echo "Grafana 3000 (${GRAFANA_BIND_IP}):"
ss -lntp 2>/dev/null | grep ':3000' || echo "  NAO ESTA OUVINDO"
echo "PostgreSQL 5432 (127.0.0.1):"
ss -lntp 2>/dev/null | grep ':5432' || echo "  NAO ESTA OUVINDO"
echo "Kafka 9092 (127.0.0.1):"
ss -lntp 2>/dev/null | grep ':9092' || echo "  NAO ESTA OUVINDO"
echo
echo "--- Grafana ---"
GF_URL="http://${GRAFANA_BIND_IP}:3000"
if curl -sf -o /dev/null -w '' --max-time 3 "$GF_URL/api/health"; then
  echo "Grafana HTTP: ONLINE ($GF_URL)"
else
  echo "Grafana HTTP: OFFLINE ($GF_URL)"
fi
if [ -f .env ]; then
  GF_USER=$(grep '^GF_ADMIN_USER=' .env | cut -d= -f2)
  GF_PASS=$(grep '^GF_ADMIN_PASSWORD=' .env | cut -d= -f2)
  DS_RESULT=$(curl -sf -u "${GF_USER}:${GF_PASS}" --max-time 3 -X POST "$GF_URL/api/ds/query" \
    -H "Content-Type: application/json" \
    -d '{"queries":[{"refId":"A","datasource":{"type":"postgres","uid":"openbmp"},"rawSql":"SELECT 1","format":"table"}]}' 2>/dev/null || true)
  if echo "$DS_RESULT" | grep -q '"values"'; then
    echo "OpenBMP Datasource: CONNECTED"
  else
    echo "OpenBMP Datasource: DISCONNECTED"
  fi
fi
echo
echo "--- Disco (${OBMP_DATA_ROOT}) ---"
df -h "$OBMP_DATA_ROOT"
echo
echo "--- Uso de recursos (docker stats, snapshot) ---"
docker stats --no-stream
