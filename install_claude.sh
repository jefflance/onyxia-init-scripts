#!/bin/bash
# install_claude.sh — Node.js, CLI Claude Code, extension VSCode, token Vault
#
# Node vient de l'archive officielle (nodejs.org), dépliée dans ~/.local/node :
# ni root, ni apt, ni sudo. La somme de contrôle est vérifiée avant dépliage, et
# la liste des sommes l'est elle-même par la signature GPG des mainteneurs Node
# (clés actives de github.com/nodejs/release-keys, hôte distinct de nodejs.org).
# Sans gpgv, on se contente de la somme seule, avec un avertissement.
# Claude Code exige Node >= 22.
#
# Authentification : token CLAUDE_CODE_OAUTH_TOKEN lu dans Vault (section 4),
# sinon « claude login » dans le terminal.

BRIQUE=claude
. "${INIT_LIB:-$(dirname "$0")/lib.sh}"

MAJEUR=22

node_ok() { [ "$(node --version 2>/dev/null | sed 's/^v//; s/\..*//')" -ge "$MAJEUR" ] 2>/dev/null; }

# -- 1. Node.js --------------------------------------------------------------
if node_ok; then
  log "Node déjà présent : $(node --version)"
else
  [ -n "$ARCH_NODE" ] || echec "architecture non prévue : $(uname -m)"
  dist="https://nodejs.org/dist/latest-v$MAJEUR.x"
  tmp="$(mktemp -d)"

  if command -v gpgv >/dev/null 2>&1; then
    telecharger "$dist/SHASUMS256.txt.asc" "$tmp/sommes.asc" 30 || echec "nodejs.org injoignable (réseau filtré ?)"
    telecharger "https://raw.githubusercontent.com/nodejs/release-keys/main/gpg-only-active-keys/pubring.kbx" "$tmp/cles.kbx" 30 \
      || echec "clés de signature Node introuvables"
    # --output : on ne lit que le texte réellement signé, pas un fichier à côté.
    gpgv --quiet --keyring "$tmp/cles.kbx" --output "$tmp/sommes" "$tmp/sommes.asc" 2>/dev/null \
      || echec "signature GPG de SHASUMS256.txt invalide"
  else
    log "ATTENTION : gpgv absent, signature de SHASUMS256.txt non vérifiée."
    telecharger "$dist/SHASUMS256.txt" "$tmp/sommes" 30 || echec "nodejs.org injoignable (réseau filtré ?)"
  fi
  nom="$(grep -o "node-v[0-9.]*-linux-$ARCH_NODE\.tar\.xz" "$tmp/sommes" | head -1)"
  [ -n "$nom" ] || echec "aucune archive Node $MAJEUR pour $ARCH_NODE"

  log "Node : $nom"
  { telecharger "$dist/$nom" "$tmp/$nom" 180 && (cd "$tmp" && grep " $nom\$" sommes | sha256sum -c --status); } \
    || echec "téléchargement ou somme de contrôle de $nom"

  rm -rf "$NODE_DIR"; mkdir -p "$NODE_DIR"
  tar -xJf "$tmp/$nom" -C "$NODE_DIR" --strip-components=1 || echec "extraction de $nom"
  rm -rf "$tmp"
  node_ok || echec "aucune version >= $MAJEUR après installation"
fi
log "Node $(node --version) — npm $(npm --version) — $(command -v node)"

# -- 2. CLI Claude Code ------------------------------------------------------
log "Installation de @anthropic-ai/claude-code..."
npm install -g --prefix "$NPM_PREFIX" "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION:-latest}" || echec "installation du CLI"

# -- 3. Extension VSCode -----------------------------------------------------
if command -v code-server >/dev/null 2>&1; then
  log "Extension VSCode anthropic.claude-code..."
  code-server --install-extension anthropic.claude-code || log "extension non installée"
else
  log "code-server absent : extension ignorée"
fi

# -- 4. Authentification et premier démarrage --------------------------------
# Token (claude setup-token) stocké dans Vault, clé CLAUDE_CODE_OAUTH_TOKEN, lu à
# l'ouverture de chaque terminal par le helper de setup_git.sh, jamais écrit sur
# disque. Le terminal seulement : l'extension VSCode ne lit pas .bashrc.
bashrc_ajouter "Claude Code : token d'abonnement lu dans Vault" <<'EOF'
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -x "$HOME/.local/bin/git-credential-vault" ]; then
  CLAUDE_CODE_OAUTH_TOKEN="$("$HOME/.local/bin/git-credential-vault" secret CLAUDE_CODE_OAUTH_TOKEN)"
  [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && export CLAUDE_CODE_OAUTH_TOKEN || unset CLAUDE_CODE_OAUTH_TOKEN
fi
EOF
# Sans ce drapeau, un ~/.claude.json vierge relance l'assistant de premier démarrage.
[ -f "$HOME/.claude.json" ] || echo '{"hasCompletedOnboarding": true}' > "$HOME/.claude.json"
mkdir -p "$HOME/.claude"

[ -x "$NPM_PREFIX/bin/claude" ] || echec "rien dans $NPM_PREFIX/bin"
log "OK — $(claude --version 2>/dev/null || echo installé). Ouvre un NOUVEAU terminal, puis : claude"
