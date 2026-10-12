#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v docker >/dev/null || { echo 'Install Docker Engine or Docker Desktop first.'; exit 1; }
if [ ! -f .env ]; then
 python3 - <<'PY'
from pathlib import Path
import secrets
Path('.env').write_text('POSTGRES_PASSWORD='+secrets.token_hex(20)+'\nJWT_SECRET='+secrets.token_hex(32)+'\nDEMO_PASSWORD='+secrets.token_urlsafe(12)+'\nCORS_ORIGINS=http://localhost:3000\n')
PY
 echo 'Created .env. Read DEMO_PASSWORD there to sign in.'
fi
for language in python java cpp; do
 docker build -f "sandbox/$language.Dockerfile" -t "gradeflow-$language:local" sandbox
done
docker compose up --build -d
docker compose run --rm api python -m app.seed
echo 'Backend ready: http://localhost:8000/docs'
