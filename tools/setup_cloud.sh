#!/usr/bin/env bash
# Prepare the existing isolated checkout without changing source or lockfiles.
set -euo pipefail
cd /workspace/mancebo-robles-el-imperio
export XDG_DATA_HOME=/workspace/.cache/mancebo-robles/godot-data
export XDG_CACHE_HOME=/workspace/.cache/mancebo-robles/xdg-cache
export XDG_CONFIG_HOME=/workspace/.cache/mancebo-robles/xdg-config
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME/fontconfig" "$XDG_CONFIG_HOME"
command -v python3 >/dev/null
command -v node >/dev/null
case "$(godot --version)" in
  4.6.3.stable*) ;;
  *) printf 'Este proyecto requiere Godot 4.6.3 estable.\n' >&2; exit 1 ;;
esac
python3 tools/build_html.py
godot --headless --path godot --editor --import
# Windows templates are retained in the snapshot. To refresh them or export,
# run MANCEBO_CACHE_DIR=/workspace/.cache/mancebo-robles tools/export_windows.sh.
