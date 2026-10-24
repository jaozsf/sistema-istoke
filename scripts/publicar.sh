#!/usr/bin/env bash
# Publica o StockIQ na Vercel: a API (backend/) e o app web (Flutter) saem no
# mesmo projeto e no mesmo domínio. O build web é copiado para backend/public/
# (ignorado pelo Git -- é gerado a cada publicação) e servido como estático;
# /api, /health e /docs continuam indo para a API.
#
# Uso (na raiz do repositório):
#   ./scripts/publicar.sh           # web + API em produção
#   ./scripts/publicar.sh preview   # deploy de teste (sem variáveis de produção)
#   ./scripts/publicar.sh apk       # só gera o APK Android de release
set -euo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
alvo="${1:-prod}"

if [[ "$alvo" == "apk" ]]; then
  (cd "$raiz/stockiq-flutter" && flutter build apk --release)
  echo "APK: stockiq-flutter/build/app/outputs/flutter-apk/app-release.apk"
  exit 0
fi

(cd "$raiz/stockiq-flutter" && flutter build web --release)

rm -rf "$raiz/backend/public"
cp -r "$raiz/stockiq-flutter/build/web" "$raiz/backend/public"

cd "$raiz/backend"
if [[ "$alvo" == "preview" ]]; then
  vercel --yes
else
  vercel --prod --yes
fi
