#!/bin/bash
# AcessaBMP - sobe os servicos OpenBMP (nao remove volumes nem recria dados)
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose up -d
