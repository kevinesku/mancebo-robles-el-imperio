#!/usr/bin/env bash
# Publish the three existing, verified packages. Never builds or replaces them.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REPO=${GH_REPO:-${GITHUB_REPOSITORY:-kevinesku/mancebo-robles-el-imperio}}
TAG=v0.1.0
TARGET=main
VERIFY_ONLY=false

usage() {
    cat <<'EOF'
Uso: bash tools/publish_existing_release.sh [--verify-only] [--repo OWNER/REPO] [--target BRANCH_OR_SHA]

Valida y publica únicamente los tres ZIP ya existentes en dist/.
--verify-only no accede a la red ni necesita autenticación.
Para publicar se necesitan Python 3, GitHub CLI (gh) y acceso Contents: write.
Inicia sesión con gh auth login; nunca introduzcas tokens en el chat.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verify-only) VERIFY_ONLY=true; shift ;;
        --repo|--target)
            [[ $# -ge 2 && -n "$2" ]] || { usage >&2; exit 2; }
            if [[ "$1" == --repo ]]; then REPO=$2; else TARGET=$2; fi
            shift 2
            ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'Argumento desconocido: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
    printf 'Repositorio inválido: %s\n' "$REPO" >&2; exit 2;
}
command -v python3 >/dev/null || { printf 'Falta Python 3.\n' >&2; exit 1; }

ARCHIVES=(Mancebo-Robles-Windows.zip Mancebo-Robles-HTML.zip Mancebo-Robles-Fuentes.zip)

# Both recorded checksum sources must agree, and every ZIP must pass CRC checks.
python3 - "$ROOT/dist" "${ARCHIVES[@]}" <<'PY'
import hashlib
import json
from pathlib import Path
import sys
import zipfile

root = Path(sys.argv[1])
manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))['sha256']
sums = {}
for line in (root / 'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():
    if line.strip():
        digest, name = line.split(maxsplit=1)
        sums[name.strip().lstrip('*')] = digest
for name in sys.argv[2:]:
    path = root / name
    if not path.is_file():
        raise SystemExit(f'Falta el ZIP existente: {path}. No se reconstruirá.')
    expected = manifest.get(name)
    if not expected or expected != sums.get(name):
        raise SystemExit(f'Manifest y SHA256SUMS no coinciden: {name}')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected:
        raise SystemExit(f'SHA256 incorrecto: {name}. No se publicará.')
    with zipfile.ZipFile(path) as archive:
        bad = archive.testzip()
        if bad:
            raise SystemExit(f'CRC incorrecto: {name}: {bad}')
    print(f'OK {name}: {path.stat().st_size} bytes; SHA256 {digest}')
PY

if [[ "$VERIFY_ONLY" == true ]]; then
    printf 'Verificación local completada; no se ha accedido a la red.\n'
    exit 0
fi

command -v gh >/dev/null || { printf 'Falta GitHub CLI: https://cli.github.com/\n' >&2; exit 1; }
NOTES="$ROOT/RELEASE_NOTES_v0.1.0.md"
[[ -f "$NOTES" ]] || { printf 'Faltan las notas de versión: %s\n' "$NOTES" >&2; exit 1; }
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mancebo-release.XXXXXX")
trap 'rm -rf -- "$TEMP_DIR"' EXIT
find_release_id() {
    # The list endpoint also includes drafts for authenticated collaborators.
    gh api "repos/$REPO/releases?per_page=100" --paginate \
        --jq ".[] | select(.tag_name == \"$TAG\") | .id"
}

# A failed authentication/network request must never be mistaken for a missing release.
if ! RELEASE_ID=$(find_release_id 2>"$TEMP_DIR/api-error.txt"); then
    cat "$TEMP_DIR/api-error.txt" >&2
    printf 'No se pudo consultar GitHub. Revisa gh auth login, Contents: read/write y api.github.com.\n' >&2
    exit 1
fi
[[ "$RELEASE_ID" != *$'\n'* ]] || { printf 'Hay varias versiones con el tag %s.\n' "$TAG" >&2; exit 1; }
if [[ -z "$RELEASE_ID" ]]; then
    TAG_ARGS=(--target "$TARGET")
    if gh api "repos/$REPO/git/ref/tags/$TAG" --silent 2>"$TEMP_DIR/tag-error.txt"; then
        TAG_ARGS+=(--verify-tag)
    elif ! python3 - "$TEMP_DIR/tag-error.txt" <<'PY'
from pathlib import Path
import sys
sys.exit(0 if 'HTTP 404' in Path(sys.argv[1]).read_text() else 1)
PY
    then
        cat "$TEMP_DIR/tag-error.txt" >&2
        printf 'No se pudo verificar el tag existente. No se crea ni reemplaza ningún tag.\n' >&2
        exit 1
    fi
    gh release create "$TAG" --repo "$REPO" "${TAG_ARGS[@]}" \
        --title "Mancebo Robles: El Imperio $TAG" --notes-file "$NOTES" --draft
    RELEASE_ID=$(find_release_id)
fi

[[ "$RELEASE_ID" =~ ^[0-9]+$ ]] || { printf 'No se encontró una versión única para %s.\n' "$TAG" >&2; exit 1; }
ENDPOINT="repos/$REPO/releases/$RELEASE_ID"

asset_id() {
    gh api "repos/$REPO/releases/$RELEASE_ID/assets?per_page=100" --paginate \
        --jq ".[] | select(.name == \"$1\") | .id"
}

verify_download() {
    local archive=$1 directory=$2
    mkdir -p -- "$directory"
    gh release download "$TAG" --repo "$REPO" --pattern "$archive" --dir "$directory"
    python3 - "$ROOT/dist/manifest.json" "$directory/$archive" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))['sha256']
path = Path(sys.argv[2])
actual = hashlib.sha256(path.read_bytes()).hexdigest()
if actual != manifest[path.name]:
    raise SystemExit(f'Colisión: {path.name} ya existe en GitHub con otro SHA256. '
                     'No se reemplaza ningún archivo; revisa esa versión.')
print(f'Descarga verificada: {path.name}; SHA256 {actual}')
PY
}

# Verify every existing same-name asset BEFORE uploading anything new.
: >"$TEMP_DIR/missing.txt"
for archive in "${ARCHIVES[@]}"; do
    ID=$(asset_id "$archive")
    if [[ -n "$ID" ]]; then
        [[ "$ID" != *$'\n'* ]] || { printf 'Hay varios assets llamados %s.\n' "$archive" >&2; exit 1; }
        verify_download "$archive" "$TEMP_DIR/existing-$ID"
    else
        printf '%s\n' "$archive" >>"$TEMP_DIR/missing.txt"
    fi
done

while IFS= read -r archive; do
    # Deliberately no --clobber: concurrent or different uploads must fail safely.
    gh release upload "$TAG" "$ROOT/dist/$archive" --repo "$REPO"
done <"$TEMP_DIR/missing.txt"

# Confirm each uploaded object by downloading and checking its bytes before publication.
for archive in "${ARCHIVES[@]}"; do
    ID=$(asset_id "$archive")
    [[ -n "$ID" && "$ID" != *$'\n'* ]] || { printf 'Asset ausente o ambiguo: %s\n' "$archive" >&2; exit 1; }
    verify_download "$archive" "$TEMP_DIR/final-$ID"
done

gh api "$ENDPOINT" >"$TEMP_DIR/final-release.json"
IS_DRAFT=$(python3 - "$TEMP_DIR/final-release.json" <<'PY'
import json
import sys
print(str(json.load(open(sys.argv[1], encoding='utf-8'))['draft']).lower())
PY
)
if [[ "$IS_DRAFT" == true ]]; then
    gh release edit "$TAG" --repo "$REPO" --draft=false
fi
gh api "$ENDPOINT" --jq '.html_url'
printf 'Tres ZIP publicados y descargados con sus SHA256 originales; no se ha reconstruido el juego.\n'
