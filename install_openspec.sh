#!/bin/bash
# install_openspec.sh — CLI OpenSpec (@fission-ai/openspec)
# https://github.com/Fission-AI/OpenSpec
#
# Installé dans ~/.npm-global comme Claude Code : non persistant, réinstallé à
# chaque service. Après install_claude.sh (Node et npm).
#
# Rien n'est initialisé ici : « openspec init » se lance une fois par projet,
# dans ~/work, et ce qu'il écrit vit dans le dépôt du projet.
# La télémétrie d'OpenSpec, active par défaut, est coupée dans .bashrc.

BRIQUE=openspec
. "${INIT_LIB:-$(dirname "$0")/lib.sh}"

command -v npm >/dev/null 2>&1 || echec "npm absent (install_claude.sh doit tourner avant)"

npm install -g --prefix "$NPM_PREFIX" @fission-ai/openspec@latest >/dev/null 2>&1 \
  || echec "installation de @fission-ai/openspec (registre npm injoignable ?)"
log "OK — $(openspec --version 2>/dev/null || echo installé)"

bashrc_ajouter "OpenSpec : pas de télémétrie" <<'EOF'
export OPENSPEC_TELEMETRY=0
EOF
log "Dans un projet : openspec init, puis /opsx:propose dans Claude Code."
