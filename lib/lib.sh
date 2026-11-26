#!/bin/bash
# lib.sh — fonctions et chemins communs aux stages. Sourcé, jamais lancé seul :
#   STAGE=nom; . "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"
# init.sh le télécharge une fois et exporte INIT_LIB.

set -u

BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/main}"
BASHRC="$HOME/.bashrc"
INIT_RC="$HOME/.init-scripts.sh"   # blocs communs à bash et zsh, lus par .bashrc et .zshrc
BIN_DIR="$HOME/.local/bin"
NODE_DIR="$HOME/.local/node"
NPM_PREFIX="$HOME/.npm-global"
HELPER="$BIN_DIR/git-credential-vault"

# Node et les outils utilisateur priment sur le système, pour ce stage comme pour les suivants.
export PATH="$NODE_DIR/bin:$NPM_PREFIX/bin:$BIN_DIR:$PATH"

# Noms d'architecture : gh / Go (ARCH_GO) et Node (ARCH_NODE). Vides si non prévue.
case "$(uname -m)" in
  x86_64)  ARCH_GO=amd64; ARCH_NODE=x64 ;;
  aarch64) ARCH_GO=arm64; ARCH_NODE=arm64 ;;
  *)       ARCH_GO="";    ARCH_NODE="" ;;
esac

log()   { echo "[${STAGE:-init}] $*"; }
echec() { log "ÉCHEC : $*"; exit 1; }      # init.sh signale l'échec et passe au stage suivant
# telecharger <url> <fichier> [délai en secondes]
telecharger() { curl -fsSL --max-time "${3:-60}" "$1" -o "$2"; }

# bashrc_ajouter <repère> : ajoute stdin à ~/.init-scripts.sh (lu par bash et zsh), sous « # <repère> », une seule fois.
bashrc_ajouter() {
  grep -qF "# $1" "$INIT_RC" 2>/dev/null && return 0
  { printf '\n# %s\n' "$1"; cat; } >> "$INIT_RC"
}

# rc_lier <fichier rc> : fait lire ~/.init-scripts.sh par ce fichier, une seule fois.
rc_lier() {
  grep -qF "$INIT_RC" "$1" 2>/dev/null || printf '\n[ -f "%s" ] && . "%s"\n' "$INIT_RC" "$INIT_RC" >> "$1"
}
rc_lier "$BASHRC"

# Le PATH ci-dessus, pour les prochains terminaux. Idempotent.
bashrc_ajouter "init-scripts : PATH" <<'EOF'
export PATH="$HOME/.local/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
EOF

# Proxy décidé par init.sh (PROXY_URL/PROXY_UA exportés) : on le rend durable pour curl, wget, git, npm
# et les prochains terminaux. Idempotent. shortcut: apt/dnf (root) non configurés.
if [ -n "${PROXY_URL:-}" ]; then
  grep -qs '^proxy' "$HOME/.curlrc" || printf 'proxy = "%s"\nuser-agent = "%s"\n' "$PROXY_URL" "$PROXY_UA" >> "$HOME/.curlrc"
  grep -qs '^use_proxy' "$HOME/.wgetrc" || printf 'use_proxy = on\nhttp_proxy = %s\nhttps_proxy = %s\nuser_agent = %s\n' "$PROXY_URL" "$PROXY_URL" "$PROXY_UA" >> "$HOME/.wgetrc"
  grep -qs '^proxy=' "$HOME/.npmrc" || printf 'proxy=%s\nhttps-proxy=%s\nuser-agent=%s\n' "$PROXY_URL" "$PROXY_URL" "$PROXY_UA" >> "$HOME/.npmrc"
  if command -v git >/dev/null; then git config --global http.proxy "$PROXY_URL"; git config --global http.userAgent "$PROXY_UA"; fi
  bashrc_ajouter "init-scripts : proxy" <<EOF
export http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" HTTP_PROXY="$PROXY_URL" HTTPS_PROXY="$PROXY_URL"
export no_proxy="localhost,127.0.0.1,.svc,.cluster.local" NO_PROXY="localhost,127.0.0.1,.svc,.cluster.local"
EOF
fi
