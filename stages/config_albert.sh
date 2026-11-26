#!/bin/bash
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"   # lancé par erreur avec sh
# Pose un agent Continue sans toucher au config.yaml généré par l'extension.
# ALBERT_API_KEY : variable d'env Onyxia, résolue par Continue à l'exécution (jamais écrite ici).
STAGE=albert
. "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"
set -e

mkdir -p "$HOME/.continue/agents"

# Heredoc entre guillemets : ${{ secrets... }} reste littéral, c'est la syntaxe Continue.
cat > "$HOME/.continue/agents/albert.yaml" <<'EOF'
%YAML 1.1
---
name: Albert
version: 1.0.0
schema: v1
model_defaults: &model_defaults
  provider: openai
  apiKey: ${{ secrets.ALBERT_API_KEY }}
  apiBase: https://albert.api.etalab.gouv.fr/v1
models:
  - name: openweight-large
    <<: *model_defaults
    model: openweight-large
    roles:
      - chat
      - edit
      - apply
      - autocomplete
  - name: openweight-code
    <<: *model_defaults
    model: openweight-code
    roles:
      - chat
      - edit
      - apply
      - autocomplete
  - name: openweight-small
    <<: *model_defaults
    model: openweight-small
    roles:
      - chat
      - edit
      - apply
      - autocomplete
EOF

log "Agent Continue posé."
