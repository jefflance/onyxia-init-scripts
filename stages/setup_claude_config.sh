#!/bin/bash
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"   # lancé par erreur avec sh
# setup_claude_config.sh
# Installe la configuration Claude Code (CLAUDE.md et skills) tenue dans un dépôt
# PRIVÉ, cloné avec le token GitHub lu dans Vault par le helper de setup_git.sh.
# Doit donc tourner APRÈS setup_git.sh.
#
# Ce dépôt-ci est public : il ne contient que la mécanique. Le contenu (qui décrit
# notamment Nubonyxia) reste dans le dépôt privé.
#
#   ~/.claude/CLAUDE.md       -> <clone>/CLAUDE.md
#   ~/.claude/skills/<skill>  -> <clone>/skills/<skill>
#
# Le clone vit hors de ~/work : il est refait à chaque nouveau service, donc
# toujours à jour. Toute modification faite dedans doit être poussée aussitôt.

STAGE=claude-config
. "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"

CLAUDE_DIR="$HOME/.claude"
CONFIG_DIR="$HOME/.local/share/claude-onyxia-config"
CONFIG_REPO="${CLAUDE_CONFIG_REPO:-}"

if [ -z "$CONFIG_REPO" ]; then
  log "CLAUDE_CONFIG_REPO non défini : stage ignoré."
  exit 0
fi

if [ ! -x "$HELPER" ]; then
  echec "$HELPER absent (setup_git.sh doit tourner avant)"
fi

# -- 1. Cloner, ou mettre à jour si le clone existe déjà ---------------------
mkdir -p "$(dirname "$CONFIG_DIR")"
if [ -d "$CONFIG_DIR/.git" ]; then
  if git -c credential.helper="$HELPER" -c safe.directory="$CONFIG_DIR" \
       -C "$CONFIG_DIR" pull --ff-only --quiet 2>&1; then
    log "Dépôt mis à jour."
  else
    log "ATTENTION : mise à jour impossible, version locale conservée."
  fi
else
  if git -c credential.helper="$HELPER" clone --quiet "$CONFIG_REPO" "$CONFIG_DIR" 2>&1; then
    log "Dépôt cloné dans $CONFIG_DIR"
  else
    echec "clonage impossible (dépôt privé : clé GITHUB_TOKEN absente de Vault ?)"
  fi
fi

# -- 2. Liens dans ~/.claude -------------------------------------------------
# Un fichier ou dossier réel déjà présent n'est jamais écrasé : il est mis de côté
# HORS de ~/.claude/skills, sinon Claude Code chargerait la copie comme un second skill.
BACKUP_DIR="$CLAUDE_DIR/claude-config-backups"
relier() {
  local cible="$1" lien="$2"
  if [ -e "$lien" ] && [ ! -L "$lien" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$lien" "$BACKUP_DIR/$(basename "$lien").$(date +%Y%m%d%H%M%S)"
    log "$lien existant mis de côté dans $BACKUP_DIR."
  fi
  ln -sfn "$cible" "$lien"
}

mkdir -p "$CLAUDE_DIR/skills"

if [ -f "$CONFIG_DIR/CLAUDE.md" ]; then
  relier "$CONFIG_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  log "CLAUDE.md relié."
fi

for skill in "$CONFIG_DIR"/skills/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  nom="$(basename "$skill")"
  relier "${skill%/}" "$CLAUDE_DIR/skills/$nom"
  log "Skill '$nom' relié."
done


log "Terminé."
