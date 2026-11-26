#!/bin/bash
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"   # lancé par erreur avec sh
# setup_vscode.sh — thème « Dark Modern » par défaut dans le VSCode du service.
# N'écrase pas un thème déjà choisi ; le fichier peut contenir des commentaires (JSONC),
# donc insertion textuelle plutôt que réécriture JSON.

STAGE=vscode
. "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"

SETTINGS="${HOME}/.local/share/code-server/User/settings.json"
mkdir -p "$(dirname "$SETTINGS")"

if grep -q '"workbench.colorTheme"' "$SETTINGS" 2>/dev/null; then
  log "thème déjà défini, inchangé."
elif [ ! -s "$SETTINGS" ]; then
  printf '{\n  "workbench.colorTheme": "Dark Modern"\n}\n' > "$SETTINGS"
  log "thème Dark Modern défini."
else
  # première « { » d'une ligne qui n'est pas un commentaire //
  sed -i '0,/^[^/]*{/s//&\n  "workbench.colorTheme": "Dark Modern",/' "$SETTINGS"
  log "thème Dark Modern défini."
fi
