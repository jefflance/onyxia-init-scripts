#!/bin/bash
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"   # lancé par erreur avec sh
# setup_vscode.sh — thème « Dobri Next -A00- Black » par défaut et pas de page d'accueil dans le VSCode du service.
# N'écrase pas un réglage déjà choisi ; le fichier peut contenir des commentaires (JSONC),
# donc insertion textuelle plutôt que réécriture JSON.

STAGE=vscode
. "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"

SETTINGS="${HOME}/.local/share/code-server/User/settings.json"
mkdir -p "$(dirname "$SETTINGS")"

# reglage CLÉ 'VALEUR JSON' : ajoute le réglage s'il est absent
reglage() {
  if grep -q "\"$1\"" "$SETTINGS" 2>/dev/null; then
    log "$1 déjà défini, inchangé."
  elif [ ! -s "$SETTINGS" ]; then
    printf '{\n  "%s": %s\n}\n' "$1" "$2" > "$SETTINGS"
    log "$1 défini."
  else
    # première « { » d'une ligne qui n'est pas un commentaire //
    sed -i "0,/^[^/]*{/s//&\n  \"$1\": $2,/" "$SETTINGS"
    log "$1 défini."
  fi
}

# Derrière le proxy (Nubo), code-server ne joint pas Open VSX : on télécharge le .vsix via wget (proxy dans ~/.wgetrc).
# Barre secondaire visible avant l'installation, pour que le chat de Claude s'y place.
if [ -n "${PROXY_URL:-}" ] && ! code-server --list-extensions 2>/dev/null | grep -qix 'anthropic.claude-code'; then
  reglage workbench.secondarySideBar.defaultVisibility '"visible"'
  vsix=/tmp/claude-code.vsix
  url=$(wget -qO- https://open-vsx.org/api/Anthropic/claude-code/linux-x64/latest | grep -o '"download":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ -n "$url" ] && wget -qO "$vsix" "$url" && code-server --install-extension "$vsix" >/dev/null 2>&1; then
    log "extension anthropic.claude-code installée (via proxy)."
  else
    log "extension anthropic.claude-code non installée."
  fi
  rm -f "$vsix"
fi

# Extension du thème (Open VSX, la galerie de code-server) ; sans elle le thème défini serait ignoré.
if code-server --list-extensions 2>/dev/null | grep -qix 'sldobri.bunker'; then
  log "extension sldobri.bunker déjà installée."
else
  code-server --install-extension sldobri.bunker >/dev/null 2>&1 \
    && log "extension sldobri.bunker installée." || log "extension sldobri.bunker non installée (thème sans effet)."
fi

# Mise à jour : code-server n'a pas de commande « update » ; --force réinstalle la dernière version.
# Un échec (extension absente d'Open VSX, ou installée à la main) n'est pas bloquant.
for ext in $(code-server --list-extensions 2>/dev/null); do
  code-server --install-extension "$ext" --force >/dev/null 2>&1 \
    && log "extension $ext à jour." || log "extension $ext non mise à jour."
done

reglage workbench.colorTheme '"Dobri Next -A00- Black"'
reglage workbench.startupEditor '"none"'
reglage workbench.welcomePage.walkthroughs.openOnInstall false
reglage terminal.integrated.defaultProfile.linux '"zsh"'
