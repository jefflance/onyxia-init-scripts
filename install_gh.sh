#!/bin/bash
# install_gh.sh — CLI GitHub (gh), en espace utilisateur
#
# L'archive officielle est dépliée dans ~/.local/share/gh : ni root ni apt,
# donc la même voie sur SSPCloud et sur Nubonyxia (GitHub y est joignable).
#
# Authentification : aucun « gh auth login », aucun token écrit sur le disque.
# ~/.local/bin/gh est un lanceur qui lit GITHUB_TOKEN dans Vault à chaque
# appel, avec le helper installé par setup_git.sh, puis passe la main au
# vrai binaire.

BRIQUE=gh
. "${INIT_LIB:-$(dirname "$0")/lib.sh}"

GH_DIR="$HOME/.local/share/gh"
VERSION_SECOURS="2.102.0"         # si la dernière version ne peut pas être lue

[ -n "$ARCH_GO" ] || echec "architecture non prévue : $(uname -m)"

# -- 1. Dernière version -----------------------------------------------------
# Lue dans la redirection de /releases/latest : l'API GitHub, elle, est
# limitée à 60 appels par heure et par adresse IP sans token.
VERSION=$(curl -fsSI --max-time 15 https://github.com/cli/cli/releases/latest 2>/dev/null \
  | tr -d '\r' | sed -n 's#^[Ll]ocation: .*/tag/v##p')
if [ -z "$VERSION" ]; then
  VERSION="$VERSION_SECOURS"
  log "dernière version non déterminée, on prend $VERSION"
fi

# -- 2. Archive, vérifiée par sa somme de contrôle ---------------------------
if "$GH_DIR/bin/gh" --version 2>/dev/null | grep -q "gh version $VERSION "; then
  log "déjà présent en $VERSION"
else
  tmp="$(mktemp -d)"
  nom="gh_${VERSION}_linux_${ARCH_GO}.tar.gz"
  url="https://github.com/cli/cli/releases/download/v${VERSION}"

  { telecharger "$url/$nom" "$tmp/$nom" 180 \
      && telecharger "$url/gh_${VERSION}_checksums.txt" "$tmp/sommes" 30 \
      && (cd "$tmp" && grep " $nom\$" sommes | sha256sum -c --status); } \
    || echec "téléchargement ou somme de contrôle de $nom"

  rm -rf "$GH_DIR"; mkdir -p "$GH_DIR"
  tar -xzf "$tmp/$nom" -C "$GH_DIR" --strip-components=1 || echec "extraction de $nom"
  rm -rf "$tmp"
fi
[ -x "$GH_DIR/bin/gh" ] || echec "pas de binaire dans $GH_DIR/bin"

# -- 3. Lanceur : le token vient de Vault à chaque appel ---------------------
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/gh" << 'EOF'
#!/bin/bash
# Lanceur de gh, écrit par install_gh.sh. Le token GitHub est lu dans Vault
# (ou dans l'environnement) à chaque appel : il n'est jamais stocké.
if [ -z "${GH_TOKEN:-}" ] && [ -z "${GITHUB_TOKEN:-}" ]; then
  GH_TOKEN="$("$HOME/.local/bin/git-credential-vault" secret GITHUB_TOKEN 2>/dev/null)"
  [ -n "$GH_TOKEN" ] && export GH_TOKEN
fi
exec "$HOME/.local/share/gh/bin/gh" "$@"
EOF
chmod +x "$BIN_DIR/gh"

log "OK — $("$GH_DIR/bin/gh" --version | head -1). Token : clé GITHUB_TOKEN de Vault (gh auth status pour vérifier)."
