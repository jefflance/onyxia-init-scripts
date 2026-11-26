#!/bin/bash
# init.sh — orchestrateur d'initialisation Onyxia (SSPCloud, Nubonyxia)
#
# C'est la SEULE URL à fournir à Onyxia (champ « script d'initialisation ») :
#   https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/refs/heads/main/init.sh
#
# lib.sh et chaque stage sont téléchargés dans un dossier temporaire, puis
# lancés avec bash. L'échec d'un stage n'arrête pas les suivants ; un bilan
# est affiché à la fin. Lancé en root, chaque stage tourne sous « onyxia ».

# Ordre significatif : voir les commentaires à droite.
STAGES=(
  install_claude.sh          # Node, npm et CLI « claude »
  install_claude_plugins.sh  # a besoin de claude
  install_openspec.sh        # a besoin de npm
  setup_git.sh               # installe le helper Vault
  install_gh.sh              # a besoin du helper Vault
  setup_claude_config.sh     # clone un dépôt privé : a besoin du helper Vault
  config_albert.sh
  setup_vscode.sh
)

# INIT_REF (tag ou SHA) épingle les stages ; sans lui, main est suivi.
export BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/${INIT_REF:-main}}"
TRAVAIL="$(mktemp -d)"
chmod 755 "$TRAVAIL"

if [ "$(id -u)" = "0" ]; then
  HOME_ONYXIA="$(getent passwd onyxia | cut -d: -f6)"
  # -m garde l'environnement (GIT_REPOSITORY, VAULT_*…) ; HOME est remis à celui d'onyxia.
  lancer() { su -m onyxia -s /bin/bash -c 'HOME="$1"; shift; exec "$@"' _ "$HOME_ONYXIA" "$@"; }
else
  lancer() { "$@"; }
fi

echo "############ INIT ONYXIA : DÉBUT ############"
echo "utilisateur : $(id -un) (uid $(id -u))"

if ! curl -fsSL --max-time 60 "$BASE_URL/lib/lib.sh" -o "$TRAVAIL/lib.sh" || [ ! -s "$TRAVAIL/lib.sh" ]; then
  echo "[init] ÉCHEC du téléchargement de lib/lib.sh depuis $BASE_URL — abandon."
  exit 0
fi
export INIT_LIB="$TRAVAIL/lib.sh"

BILAN=()
for stage in "${STAGES[@]}"; do
  echo ""
  echo "---- $stage ----"
  if curl -fsSL --max-time 60 "$BASE_URL/stages/$stage" -o "$TRAVAIL/$stage" && [ -s "$TRAVAIL/$stage" ]; then
    lancer bash "$TRAVAIL/$stage"
    code=$?
  else
    echo "[init] téléchargement de $stage impossible ou fichier vide."
    code=1
  fi
  if [ "$code" -eq 0 ]; then BILAN+=("  OK     $stage"); else BILAN+=("  ÉCHEC  $stage (code $code)"); fi
done

rm -rf "$TRAVAIL"
echo ""
echo "############ BILAN ############"
printf '%s\n' "${BILAN[@]}"
echo "############ INIT ONYXIA : FIN ############"
