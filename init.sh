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
  setup_zsh.sh               # avant setup_vscode : le terminal par défaut
  setup_vscode.sh
)

# INIT_REF (tag ou SHA) épingle les stages ; sans lui, main est suivi.
export BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/${INIT_REF:-main}}"
# Proxy de repli : si GitHub est injoignable en direct, on passe par le proxy, qui filtre sur le User-Agent.
# PROXY_UA_ON active le -A de curl() ci-dessous ; lib.sh configure le reste (wget, git, npm…).
PROXY_URL="http://172.16.0.53:3128"
PROXY_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:102.0) Gecko/20100101 Firefox/102.0"
curl() { command curl ${PROXY_UA_ON:+-A "$PROXY_UA"} "$@"; }
if ! curl -fsS --max-time 10 -o /dev/null "$BASE_URL/lib/lib.sh"; then
  echo "[init] pas d'accès direct à l'extérieur : bascule sur le proxy $PROXY_URL"
  export PROXY_URL PROXY_UA PROXY_UA_ON=1
  export http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" HTTP_PROXY="$PROXY_URL" HTTPS_PROXY="$PROXY_URL"
  export no_proxy="localhost,127.0.0.1,.svc,.cluster.local" NO_PROXY="localhost,127.0.0.1,.svc,.cluster.local"
fi

TRAVAIL="$(mktemp -d)"
chmod 755 "$TRAVAIL"

# Journal lisible dans l'instance : tout ce qui s'affiche y est aussi écrit.
# Consulter : cat ~/init-onyxia.log
if [ "$(id -u)" = "0" ]; then HOME_LOG="$(getent passwd onyxia | cut -d: -f6)"; else HOME_LOG="$HOME"; fi
LOG="${HOME_LOG:-/tmp}/init-onyxia.log"
{ : >> "$LOG"; } 2>/dev/null || LOG="/tmp/init-onyxia.log"
[ "$(id -u)" = "0" ] && chown onyxia "$LOG" 2>/dev/null
exec > >(tee -a "$LOG") 2>&1

if [ "$(id -u)" = "0" ]; then
  HOME_ONYXIA="$(getent passwd onyxia | cut -d: -f6)"
  # -m garde l'environnement (GIT_REPOSITORY, VAULT_*…) ; HOME est remis à celui d'onyxia.
  lancer() { su -m onyxia -s /bin/bash -c 'HOME="$1"; shift; exec "$@"' _ "$HOME_ONYXIA" "$@"; }
else
  lancer() { "$@"; }
fi

echo "############ INIT ONYXIA : DÉBUT ($(date '+%F %T')) ############"
echo "journal : $LOG"
echo "utilisateur : $(id -un) (uid $(id -u))"

if ! curl -fsSL --max-time 60 "$BASE_URL/lib/lib.sh" -o "$TRAVAIL/lib.sh" || [ ! -s "$TRAVAIL/lib.sh" ]; then
  echo "[init] ÉCHEC du téléchargement de lib/lib.sh depuis $BASE_URL — abandon."
  exit 0
fi
export INIT_LIB="$TRAVAIL/lib.sh"

BILAN=()
for stage in "${STAGES[@]}"; do
  echo ""
  echo "---- $stage ($(date '+%T')) ----"
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
echo "############ INIT ONYXIA : FIN ($(date '+%F %T')) — journal : $LOG ############"
sleep 1   # laisse tee finir d'écrire
