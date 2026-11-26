#!/bin/bash
# install_claude_plugins.sh — bun, puis les plugins Claude Code
# ~/.claude n'est pas persistant : sans cette brique, chaque nouveau service
# démarre sans plugins. Après install_claude.sh (CLI « claude »).
#
# Les marketplaces sont des dépôts GitHub publics : ni token, ni connexion à
# Claude. Sans internet (Nubonyxia), la brique échoue sans rien casser.
#
# bun d'abord : certains plugins (compound-engineering) s'en servent pour
# installer leurs paquets et les sautent sans lui.
#
# Pour ajouter un plugin : une ligne « <dépôt GitHub du marketplace> <plugin>@<marketplace> ».

BRIQUE=plugins
. "${INIT_LIB:-$(dirname "$0")/lib.sh}"

PLUGINS="
EveryInc/compound-engineering-plugin compound-engineering@compound-engineering-plugin
anthropics/claude-plugins-official frontend-design@claude-plugins-official
DietrichGebert/ponytail ponytail@ponytail
"

command -v claude >/dev/null 2>&1 || echec "CLI claude absent (install_claude.sh doit tourner avant)"

if command -v bun >/dev/null 2>&1; then
  log "bun déjà présent : $(bun --version)"
elif npm install -g --prefix "$NPM_PREFIX" bun >/dev/null 2>&1; then
  log "bun installé : $(bun --version)"
else
  log "ÉCHEC de bun : les plugins seront installés sans leurs paquets."
fi

installes="$(claude plugin list 2>/dev/null)"
marketplaces="$(claude plugin marketplace list 2>/dev/null)"
erreurs=0

while read -r depot plugin; do
  [ -n "$depot" ] || continue
  if grep -qF "$plugin" <<<"$installes"; then log "$plugin déjà installé."; continue; fi

  if ! grep -qF "${plugin#*@}" <<<"$marketplaces" \
     && ! claude plugin marketplace add "$depot" >/dev/null 2>&1; then
    log "ÉCHEC : marketplace $depot injoignable (pas d'internet ?)."; erreurs=1; continue
  fi
  if claude plugin install "$plugin" --scope user >/dev/null 2>&1; then
    log "$plugin installé."
  else
    log "ÉCHEC de l'installation de $plugin."; erreurs=1
  fi
done <<<"$PLUGINS"

exit "$erreurs"
