#!/bin/bash
# AcessaBMP - segue os logs de todos os servicos OpenBMP
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose logs -f --tail=100 "$@"
