# onyxia-init-scripts

Script d'initialisation des services VSCode Onyxia (SSPCloud, Nubonyxia). URL à mettre dans le champ « script d'initialisation » :

```
https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/refs/heads/main/init.sh
```

`init.sh` (seule URL à fournir) télécharge `lib/lib.sh` puis lance chaque stage de `STAGES` (`stages/`). Un stage en échec n'arrête pas les suivants ; un bilan clôt le journal. Lancé en root, il exécute les stages sous `onyxia`. Aucun secret dans le dépôt : les tokens sont lus à chaque usage, jamais écrits sur disque.

| Stage | Rôle |
| --- | --- |
| `install_claude.sh` | Node.js 22 (archive officielle dans `~/.local/node`, somme et signature GPG vérifiées, sans root), CLI Claude Code, extension VSCode, token lu dans Vault (pas de `claude login`) |
| `install_claude_plugins.sh` | bun, plugins Claude Code (compound-engineering, frontend-design, ponytail) |
| `install_openspec.sh` | CLI OpenSpec (télémétrie coupée) |
| `setup_git.sh` | Git, helper `git-credential-vault` (`bin/`), clone du dépôt du service, alias Forge |
| `install_gh.sh` | CLI GitHub, token lu dans Vault |
| `setup_claude_config.sh` | `CLAUDE.md` et skills depuis un dépôt privé |
| `config_albert.sh` | Agent Continue vers l'API Albert |
| `setup_zsh.sh` | zsh (apt, root ou sudo), oh-my-zsh, starship (archive vérifiée) |
| `setup_vscode.sh` | Mise à jour des extensions, thème « Dobri Next -A00- Black », pas de page d'accueil, zsh par défaut (réglages existants préservés) |

## Proxy de repli

`init.sh` teste l'accès direct à GitHub (10 s). S'il échoue, il bascule sur `http://172.16.0.53:3128`, qui filtre sur le User-Agent (Firefox 102). `lib.sh` rend alors le réglage durable : `~/.curlrc`, `~/.wgetrc`, `~/.npmrc`, `git config --global` (`http.proxy`, `http.userAgent`) et variables `http(s)_proxy` / `no_proxy` dans `~/.init-scripts.sh`. Non couverts : apt/dnf, et `no_proxy` ne liste que `localhost`, `127.0.0.1`, `.svc`, `.cluster.local`.

## Secrets et variables

`git-credential-vault` (`~/.local/bin`) cherche une clé dans l'environnement, puis dans Vault (`VAULT_ADDR`, `VAULT_TOKEN`, `VAULT_MOUNT`, `VAULT_TOP_DIR`, fournis par Onyxia ; 4 niveaux d'arborescence, première occurrence retenue). L'emplacement trouvé (jamais la valeur) est mis en cache dans `~/.cache/git-credential-vault.json`. Il ne répond qu'en `https`. `git-credential-vault secret <CLÉ>` affiche la valeur : c'est ce qu'utilisent les stages.

| Clé (environnement ou Vault) | Utilisée par |
| --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`) | `.bashrc`, terminal seulement (l'extension VSCode ne le lit pas) |
| `GITHUB_TOKEN` | git sur github.com, `gh`, clone du dépôt privé de `setup_claude_config.sh` |
| `GITLAB_TOKEN` | git sur gitlab.com |
| `GIT_NAME`, `GIT_EMAIL` | identité git, si `GIT_USER_NAME` / `GIT_USER_MAIL` (Onyxia) sont absents |
| `FORGE_HOST`, `FORGE_TOKEN` | git sur la Forge interne |
| `FORGE_REMOTES` | paires `nom-du-dépôt=chemin/sur/la/forge` séparées par des espaces |

Autres variables d'environnement : `GIT_REPOSITORY`, `GIT_BRANCH` (Onyxia, clone dans `~/work`), `ALBERT_API_KEY` (lue par Continue), `CLAUDE_CONFIG_REPO` (dépôt privé de `setup_claude_config.sh`, sinon stage ignoré), `CLAUDE_CODE_VERSION` et `OPENSPEC_VERSION` (versions npm, `latest` par défaut), `INIT_REF` / `BASE_URL` (origine des scripts).

## Modifier ou tester

- **Ajouter un stage** : créer `stages/mon_stage.sh` commençant par `STAGE=nom; . "${INIT_LIB:-$(dirname "$0")/../lib/lib.sh}"` (donne `log`, `echec`, `telecharger`, `bashrc_ajouter`, `$ARCH_GO`, `$ARCH_NODE`, le `PATH`), puis l'ajouter à `STAGES` dans `init.sh`. `echec "…"` quitte avec le code 1.
- **Essayer une branche** : `BASE_URL=https://raw.githubusercontent.com/jefflance/onyxia-init-scripts/<branche-ou-sha> bash init.sh`. `main` est suivi par défaut : tout push s'applique au prochain service. Pour épingler, mettre un SHA ou un tag dans l'URL de `init.sh` et dans `INIT_REF`.
- **Rejouable** : chaque stage vérifie ce qui est déjà en place.
- **Journal** : `~/init-onyxia.log`. `init.sh` rend toujours 0 : lire le bilan en fin de journal.

## Alias git : GitHub ↔ Forge

`setup_git.sh` installe ces alias quand un remote `forge` existe. La **Forge est la référence** (son `main` ne change que par merge request) ; le `main` de GitHub n'en est que le miroir. SSPCloud n'atteint pas la Forge : le VSCode Nubonyxia, qui voit Forge et GitHub, sert de passerelle.

| Alias | Où | Effet |
| --- | --- | --- |
| `git forge-pull [main]` | Nubonyxia | Recopie `main` de la Forge vers GitHub, en avance rapide seulement |
| `git feat <nom>` | SSPCloud | Nouvelle branche depuis `origin/main` (le miroir) |
| `git ship <nom>` | Nubonyxia | Rebase sur `forge/main`, republie sur GitHub (`--force-with-lease`), puis `forge-push` |
| `git forge-push` | Nubonyxia | Envoie la branche courante à la Forge (refuse `main`) |

```bash
git forge-pull                           # 1. Nubonyxia : miroir à jour
git feat filtre-onglet4                  # 2. SSPCloud : coder avec claude, puis
git add app/onglet4.R && git commit -m "Onglet 4 : ajouter le filtre par bureau"
git push -u origin HEAD
git ship filtre-onglet4                  # 3. Nubonyxia : livrer, puis merge request sur la Forge
git forge-pull                           # 4. Nubonyxia, après fusion : miroir à jour
```

En cas de conflit au rebase de `git ship` : résoudre, `git rebase --continue`, relancer `git ship`. Ne jamais pousser sur le `main` de la Forge ni fusionner à la main dans celui de GitHub.
