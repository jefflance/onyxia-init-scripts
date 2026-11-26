# onyxia-init-scripts

Script d'initialisation pour les services VSCode Onyxia (SSPCloud, Nubonyxia).
URL à indiquer dans le champ « script d'initialisation » du service :

```
https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/refs/heads/main/init.sh
```

`init.sh` télécharge `lib/lib.sh` (fonctions et chemins communs), puis lance chaque stage de sa liste `STAGES` ; l'échec de l'un n'arrête pas les suivants et un bilan est affiché à la fin. Lancé en root, il exécute les stages sous `onyxia`.

Arborescence : `init.sh` (seule URL à fournir), `lib/lib.sh`, `stages/` (un stage par script), `bin/git-credential-vault` (helper installé par `setup_git.sh`).

| Stage (`stages/`) | Rôle |
| --- | --- |
| `install_claude.sh` | Node.js 22 (archive officielle dans `~/.local/node`, somme de contrôle vérifiée et signature GPG des sommes si `gpgv` est présent, sans root), CLI Claude Code, extension VSCode, token `CLAUDE_CODE_OAUTH_TOKEN` lu dans Vault (pas de `claude login`) |
| `install_claude_plugins.sh` | bun, plugins Claude Code (compound-engineering, frontend-design, ponytail) |
| `install_openspec.sh` | CLI OpenSpec (télémétrie coupée) |
| `setup_git.sh` | Git, helper `git-credential-vault`, clone du dépôt du service |
| `install_gh.sh` | CLI GitHub, token lu dans Vault |
| `setup_claude_config.sh` | `CLAUDE.md` et skills depuis un dépôt privé |
| `config_albert.sh` | Agent Continue pointant vers l'API Albert (clé `ALBERT_API_KEY`, variable d'env Onyxia) |
| `setup_vscode.sh` | Thème « Dark Modern » par défaut (sans écraser un thème déjà choisi) |

Aucun secret ici : les tokens sont lus à chaque usage, jamais écrits sur le disque.

## Secrets et variables

`git-credential-vault` (installé par `setup_git.sh` dans `~/.local/bin`) cherche une clé d'abord
dans l'environnement, puis dans Vault (`VAULT_ADDR`, `VAULT_TOKEN`, `VAULT_MOUNT`, `VAULT_TOP_DIR`,
fournis par Onyxia ; parcours de l'arborescence sur 4 niveaux, première occurrence retenue).
L'emplacement trouvé (jamais la valeur) est gardé dans `~/.cache/git-credential-vault.json` : les
appels suivants coûtent une requête. Le helper ne répond qu'en `https`.
`git-credential-vault secret <CLÉ>` affiche la valeur : c'est ce qu'utilisent les autres stages.

| Clé (environnement ou Vault) | Utilisée par |
| --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`) | `.bashrc`, terminal seulement (l'extension VSCode ne lit pas `.bashrc`) |
| `GITHUB_TOKEN` | git sur github.com, lanceur `gh`, clone du dépôt privé de `setup_claude_config.sh` |
| `GITLAB_TOKEN` | git sur gitlab.com |
| `GIT_NAME`, `GIT_EMAIL` | identité git, si `GIT_USER_NAME` / `GIT_USER_MAIL` (Onyxia) sont absents |
| `FORGE_HOST`, `FORGE_TOKEN` | git sur la Forge interne |
| `FORGE_REMOTES` | `nom-du-dépôt=chemin/sur/la/forge`, paires séparées par des espaces |

Variables d'environnement lues par les stages : `GIT_REPOSITORY` et `GIT_BRANCH` (Onyxia, clone du
dépôt du service dans `~/work`), `ALBERT_API_KEY` (lue par Continue, pas par les scripts),
`CLAUDE_CONFIG_REPO` (URL du dépôt privé de `setup_claude_config.sh` ; sans lui, le stage est ignoré), `INIT_REF` / `BASE_URL` (origine des scripts, voir ci-dessous),
`CLAUDE_CODE_VERSION` et `OPENSPEC_VERSION` (versions npm ; `latest` par défaut).

## Modifier ou tester

- **Ajouter un stage** : créer `stages/mon_stage.sh` commençant par
  `STAGE=nom; . "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"` (donne `log`, `echec`, `telecharger`,
  `bashrc_ajouter`, `$ARCH_GO`, `$ARCH_NODE` et le `PATH`), puis l'ajouter à `STAGES` dans `init.sh`
  à sa place dans l'ordre. `echec "…"` quitte avec le code 1 ; `init.sh` passe à la suivante.
- **Essayer une branche** : `BASE_URL=https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/<branche-ou-sha> bash init.sh`.
  Par défaut `main` est suivi, donc tout push s'applique au prochain service. Pour épingler :
  URL de `init.sh` à un SHA ou un tag, et variable d'environnement `INIT_REF` au même SHA ou tag.
- **Rejouable** : chaque stage vérifie ce qui est déjà en place (Node, gh, plugins, `.bashrc`).
- Journal : tout est aussi écrit dans `~/init-onyxia.log` (`cat ~/init-onyxia.log` dans l'instance). Les stages se lancent avec `bash` (un `sh stage.sh` se relance seul sous bash).
- `init.sh` rend toujours 0, même si des stages échouent : lire le bilan en fin de journal
  (un stage qui sort en non-zéro y figure en ÉCHEC, y compris un clonage raté dans `setup_git.sh`).

## Alias git : GitHub ↔ Forge

`setup_git.sh` installe quatre alias quand un remote `forge` existe (Vault : `FORGE_HOST`,
`FORGE_TOKEN`, `FORGE_REMOTES`). La **Forge est la référence** (son `main` ne change que par
merge request) ; le `main` de GitHub n'en est que le miroir.

| Alias | Où | Effet |
| --- | --- | --- |
| `git forge-pull [main]` | Nubonyxia | Recopie `main` de la Forge vers GitHub, en avance rapide seulement |
| `git feat <nom>` | SSPCloud | Nouvelle branche partie de `origin/main` (le miroir) |
| `git ship <nom>` | Nubonyxia | Rebase la branche sur `forge/main`, la republie sur GitHub (`--force-with-lease`), puis `forge-push` |
| `git forge-push` | Nubonyxia | Envoie la branche courante à la Forge (refuse `main`) |

SSPCloud n'atteint pas la Forge : le VSCode Nubonyxia, qui voit la Forge et GitHub, sert de
passerelle.

### Exemple : une fonctionnalité

```bash
# 1. Nubonyxia : mettre le miroir GitHub à jour
git forge-pull

# 2. SSPCloud : coder avec Claude Code
git feat filtre-onglet4
claude                                   # coder, puis :
git add app/onglet4.R && git commit -m "Onglet 4 : ajouter le filtre par bureau"
git push -u origin HEAD

# 3. Nubonyxia : livrer à la Forge
git ship filtre-onglet4                  # puis merge request vers main sur la Forge

# 4. Nubonyxia, après la fusion (avance rapide) : miroir à jour, puis déploiement manuel
git forge-pull
```

Si le rebase de `git ship` rencontre un conflit, résoudre, `git rebase --continue`, puis relancer
`git ship`. Ne jamais pousser directement sur le `main` de la Forge ni fusionner à la main dans
celui de GitHub.
