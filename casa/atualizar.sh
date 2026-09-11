#!/usr/bin/env bash
# Atualiza a linha "casa" do FineTune: puxa o upstream, reaplica nossos patches por rebase,
# compila sem Xcode e instala em /Applications (o app anterior vai pra Lixeira).
#
# Uso: casa/atualizar.sh            # fetch upstream + rebase + build + instalar
#      casa/atualizar.sh --so-build # sem fetch/rebase (ex.: testar um patch local)
# Se o rebase conflitar, o script para: resolve no clone, `git rebase --continue`, roda de novo com --so-build.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"; OUT="$REPO/build/casa"

if [ "${1:-}" != "--so-build" ]; then
  echo "== upstream: fetch + rebase da branch casa"
  git fetch upstream --tags
  git rebase upstream/main
fi

echo "== build sem Xcode"
casa/build-sem-xcode.sh "$REPO" "$OUT"

echo "== instalar"
osascript -e 'tell application "FineTune" to quit' >/dev/null 2>&1 || true
sleep 1; pkill -x FineTune 2>/dev/null || true
if [ -d /Applications/FineTune.app ]; then
  mv /Applications/FineTune.app "$HOME/.Trash/FineTune-anterior-$(date +%Y%m%d-%H%M%S).app"
fi
cp -R "$OUT/FineTune.app" /Applications/FineTune.app
xattr -cr /Applications/FineTune.app
open -a /Applications/FineTune.app
sleep 3
pgrep -x FineTune >/dev/null && echo "FineTune rodando (pid $(pgrep -x FineTune)) — $(git log --oneline -1)" || { echo "FALHA: FineTune não subiu"; exit 1; }
echo "Se ficar mudo: tccutil reset AudioCapture com.finetuneapp.FineTune && open -a FineTune (o macOS pede a permissão de novo)."
