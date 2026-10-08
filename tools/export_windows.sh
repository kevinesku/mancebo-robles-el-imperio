#!/usr/bin/env bash
# Exportación reproducible de Windows 64 bits con Godot oficial 4.6.3.
set -euo pipefail

mode="${1:-export}"
if [[ "$mode" != "export" && "$mode" != "--prepare" ]]; then
  printf 'Uso: %s [--prepare]\n' "$0" >&2
  exit 1
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
cache_dir="${MANCEBO_CACHE_DIR:-${TMPDIR:-/tmp}/mancebo-robles-cache}"
release="4.6.3-stable"
archive_name="Godot_v${release}_export_templates.tpz"
archive_path="$cache_dir/downloads/$archive_name"
base_url="https://github.com/godotengine/godot-builds/releases/download/$release"
# SHA-512 publicado en el SHA512-SUMS.txt oficial de este lanzamiento.
expected_sha512="da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68"

export XDG_DATA_HOME="$cache_dir/godot-data"
export XDG_CACHE_HOME="$cache_dir/xdg-cache"
export XDG_CONFIG_HOME="$cache_dir/xdg-config"
mkdir -p "$cache_dir/downloads" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME/fontconfig" "$repo_dir/dist/windows"
version="$("$godot_bin" --version)"
case "$version" in
  4.6.3.stable*) ;;
  *) printf 'Se necesita Godot 4.6.3 estable; versión encontrada: %s\n' "$version" >&2; exit 1 ;;
esac

if [[ ! -f "$archive_path" ]]; then
  curl --fail --location --retry 2 --connect-timeout 20 --max-time 900 \
    --output "$archive_path.download" "$base_url/$archive_name"
  mv -- "$archive_path.download" "$archive_path"
fi

actual_sha512="$(sha512sum "$archive_path" | cut -d ' ' -f 1)"
if [[ "$actual_sha512" != "$expected_sha512" ]]; then
  printf 'Verificación SHA-512 fallida. No se usarán las plantillas descargadas.\n' >&2
  exit 1
fi
printf 'Plantillas oficiales verificadas: SHA-512 %s\n' "$actual_sha512"

template_dir="$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"
python3 - "$archive_path" "$template_dir" <<'PY'
import pathlib, sys, zipfile
archive, destination = map(pathlib.Path, sys.argv[1:])
destination.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(archive) as bundle:
    required = {"windows_release_x86_64.exe", "windows_debug_x86_64.exe", "version.txt"}
    names = {pathlib.PurePosixPath(n).name: n for n in bundle.namelist()}
    if not required.issubset(names):
        raise SystemExit("El paquete oficial no contiene todas las plantillas esperadas")
    selected = required | {n for n in names if n.startswith("windows_") and "x86_64" in n}
    for name in selected:
        (destination / name).write_bytes(bundle.read(names[name]))
print("Plantillas Windows x86_64 instaladas en", destination)
PY

# Incluye las atribuciones del motor y sus dependencias en cada distribución.
for notice in LICENSE COPYRIGHT; do
  notice_cache="$cache_dir/downloads/Godot_${release}_${notice}.txt"
  notice_output="$repo_dir/dist/windows/GODOT_${notice}.txt"
  if [[ ! -f "$notice_output" ]]; then
    if [[ ! -f "$notice_cache" ]]; then
      curl --fail --location --retry 2 --connect-timeout 20 --max-time 90 \
        --output "$notice_cache.download" \
        "https://raw.githubusercontent.com/godotengine/godot/$release/$notice.txt"
      mv -- "$notice_cache.download" "$notice_cache"
    fi
    cp -- "$notice_cache" "$notice_output"
  fi
done

if [[ "$mode" == "--prepare" ]]; then
  printf 'Preparación lista; ejecuta el script sin --prepare para exportar el juego.\n'
  exit 0
fi

"$godot_bin" --headless --path "$repo_dir/godot" --editor --import 2>&1 | tee "$cache_dir/import.log"
if rg -q 'ERROR:|SCRIPT ERROR|Parse Error|Failed to load script' "$cache_dir/import.log"; then
  printf 'El proyecto contiene errores de importación; consulta %s\n' "$cache_dir/import.log" >&2
  exit 1
fi
output="$repo_dir/dist/windows/Mancebo-Robles-El-Imperio.exe"
staging_dir="$(mktemp -d "$repo_dir/dist/windows/.export-XXXXXX")"
trap 'rm -rf -- "$staging_dir"' EXIT
staging_output="$staging_dir/Mancebo-Robles-El-Imperio.exe"
"$godot_bin" --headless --path "$repo_dir/godot" \
  --export-release "Windows Desktop" "$staging_output" 2>&1 | tee "$cache_dir/export-windows.log"
if rg -q 'ERROR:|SCRIPT ERROR|Parse Error|Export failed' "$cache_dir/export-windows.log"; then
  printf 'La exportación produjo errores; consulta %s\n' "$cache_dir/export-windows.log" >&2
  exit 1
fi
python3 "$repo_dir/tools/export_verify.py" "$staging_output"
# El motor local carga el PCK del EXE. Valida el paquete sin ejecutar el PE Windows.
mkdir -p "$staging_dir/smoke-data" "$staging_dir/smoke-config"
XDG_DATA_HOME="$staging_dir/smoke-data" XDG_CONFIG_HOME="$staging_dir/smoke-config" \
  "$godot_bin" --headless --main-pack "$staging_output" --quit-after 120 \
  2>&1 | tee "$cache_dir/pack-smoke.log"
if rg -q 'ERROR:|SCRIPT ERROR|Parse Error' "$cache_dir/pack-smoke.log"; then
  printf 'El paquete no supera la prueba de arranque; consulta %s\n' "$cache_dir/pack-smoke.log" >&2
  exit 1
fi
if [[ -f "$repo_dir/godot/tests/smoke.gd" ]]; then
  XDG_DATA_HOME="$staging_dir/smoke-data" XDG_CONFIG_HOME="$staging_dir/smoke-config" \
    "$godot_bin" --headless --main-pack "$staging_output" --script res://tests/smoke.gd \
    2>&1 | tee "$cache_dir/pack-tests.log"
  if rg -q 'ERROR:|SCRIPT ERROR|Parse Error' "$cache_dir/pack-tests.log" || \
      ! rg -q 'GODOT SMOKE PASS' "$cache_dir/pack-tests.log"; then
    printf 'El paquete no supera sus pruebas; consulta %s\n' "$cache_dir/pack-tests.log" >&2
    exit 1
  fi
fi
mv -- "$staging_output" "$output"
verification_file="$repo_dir/dist/windows/VERIFICACION.txt"
python3 "$repo_dir/tools/export_verify.py" "$output" > "$verification_file"
{
  printf '\nMotor: %s\n' "$version"
  printf 'Plantillas: %s (archivo oficial con SHA-512 verificado)\n' "$release"
  printf 'Arranque del PCK exportado con el motor local: correcto.\n'
  if [[ -f "$repo_dir/godot/tests/smoke.gd" ]]; then
    rg 'GODOT SMOKE PASS' "$cache_dir/pack-tests.log"
  fi
  printf 'La ejecución del ejecutable PE en Windows requiere una comprobación en Windows.\n'
} >> "$verification_file"
printf '\nExportación lista: %s\n' "$output"
