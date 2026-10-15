#!/bin/bash
# AcessaBMP - para os servicos OpenBMP SEM remover containers, volumes ou dados
# NUNCA usar "docker compose down -v" aqui.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose stop
