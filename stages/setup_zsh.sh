#!/bin/bash
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"   # lancé par erreur avec sh
# setup_zsh.sh — zsh + oh-my-zsh + starship, zsh par défaut dans le terminal VSCode.
# zsh vient d'apt (root ou sudo sans mot de passe) ; oh-my-zsh est cloné et starship
# est une archive officielle vérifiée par sa somme de contrôle, tous deux en espace utilisateur.
# Un ~/.zshrc existant n'est pas écrasé.

STAGE=zsh
. "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"

# -- 1. zsh ------------------------------------------------------------------
if ! command -v zsh >/dev/null; then
  if [ "$(id -u)" = 0 ]; then SU=""; else SU="sudo -n"; fi
  { $SU apt-get update -qq && $SU env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zsh; } >/dev/null 2>&1
  command -v zsh >/dev/null || echec "zsh non installable (apt, root ou sudo requis)"
fi
log "zsh : $(zsh --version)"

# -- 2. oh-my-zsh ------------------------------------------------------------
if [ -d "$HOME/.oh-my-zsh" ]; then
  log "oh-my-zsh déjà présent."
else
  git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" \
    || echec "clonage d'oh-my-zsh impossible"
fi

# -- 3. starship -------------------------------------------------------------
if command -v starship >/dev/null; then
  log "starship déjà présent."
else
  case "$(uname -m)" in x86_64|aarch64) ;; *) echec "architecture non prévue : $(uname -m)" ;; esac
  nom="starship-$(uname -m)-unknown-linux-musl.tar.gz"
  url="https://github.com/starship/starship/releases/latest/download/$nom"
  tmp="$(mktemp -d)"
  { telecharger "$url" "$tmp/$nom" 120 && telecharger "$url.sha256" "$tmp/somme" 30; } \
    || echec "téléchargement de starship impossible"
  [ "$(sha256sum "$tmp/$nom" | cut -d' ' -f1)" = "$(cut -d' ' -f1 "$tmp/somme")" ] \
    || echec "somme de contrôle de starship invalide"
  mkdir -p "$BIN_DIR" && tar -xzf "$tmp/$nom" -C "$BIN_DIR" starship || echec "extraction de starship impossible"
  rm -rf "$tmp"
  log "starship installé."
fi

# -- 4. ~/.zshrc -------------------------------------------------------------
if [ ! -f "$HOME/.zshrc" ]; then
  rc_lier "$HOME/.zshrc"   # d'abord : le PATH doit précéder « starship init »
  cat >> "$HOME/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   # l'invite est celle de starship
plugins=(git)
source "$ZSH/oh-my-zsh.sh"
eval "$(starship init zsh)"
EOF
fi
rc_lier "$HOME/.zshrc"   # PATH, token Claude, etc. communs avec bash
log "~/.zshrc prêt."
