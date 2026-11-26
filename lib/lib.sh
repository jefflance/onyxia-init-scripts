#!/bin/bash
# lib.sh — fonctions et chemins communs aux stages. Sourcé, jamais lancé seul :
#   STAGE=nom; . "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"
# init.sh le télécharge une fois et exporte INIT_LIB.

set -u

BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/main}"
BASHRC="$HOME/.bashrc"
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

# bashrc_ajouter <repère> : ajoute stdin à ~/.bashrc, sous « # <repère> », une seule fois.
bashrc_ajouter() {
  grep -qF "# $1" "$BASHRC" 2>/dev/null && return 0
  { printf '\n# %s\n' "$1"; cat; } >> "$BASHRC"
}

# Le PATH ci-dessus, pour les prochains terminaux. Idempotent.
bashrc_ajouter "init-scripts : PATH" <<'EOF'
export PATH="$HOME/.local/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
EOF
