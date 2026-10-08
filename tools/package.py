#!/usr/bin/env python3
"""Create redistributable packages, keeping caches and local saves out."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'dist'


def make_zip(name, files, base):
    target = DIST / name
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=8) as out:
        for path in sorted(files):
            out.write(path, str(path.relative_to(base)))
    with zipfile.ZipFile(target) as out:
        error = out.testzip()
        if error:
            raise RuntimeError(f'Archive integrity failure: {error}')
    print(f'{target.name}: {target.stat().st_size:,} bytes')
    return target


def main():
    DIST.mkdir(exist_ok=True)
    executable = DIST / 'windows/Mancebo-Robles-El-Imperio.exe'
    if not executable.is_file():
        raise SystemExit('Exporta primero el juego Windows con tools/export_windows.sh')
    html = DIST / 'html/Mancebo-Robles-El-Imperio.html'
    if not html.is_file():
        raise SystemExit('Genera primero el HTML con tools/build_html.py')
    shutil.copyfile(ROOT / 'LICENSE', DIST / 'windows/LICENSE.txt')
    shutil.copyfile(ROOT / 'LICENSE', DIST / 'html/LICENSE.txt')
    files = []
    for top in ('godot', 'web', 'shared', 'tests', 'tools'):
        for path in (ROOT / top).rglob('*'):
            if not path.is_file():
                continue
            if any(part in ('.godot', '__pycache__', 'artifacts') for part in path.parts):
                continue
            if path.suffix in ('.pyc', '.import'):
                continue
            files.append(path)
    for name in ('README.md', 'BRIEF.md', 'LICENSE', '.gitignore'):
        files.append(ROOT / name)
    if (DIST / 'RESULTADOS.md').exists():
        files.append(DIST / 'RESULTADOS.md')
    # Include executable engine licensing in sources for future redistributions.
    for name in ('GODOT_LICENSE.txt', 'GODOT_COPYRIGHT.txt'):
        notice = DIST / 'windows' / name
        if notice.exists():
            files.append(notice)
    archives = [
        make_zip('Mancebo-Robles-Windows.zip', list((DIST / 'windows').glob('*')), DIST / 'windows'),
        make_zip('Mancebo-Robles-HTML.zip', list((DIST / 'html').glob('*')), DIST / 'html'),
        make_zip('Mancebo-Robles-Fuentes.zip', files, ROOT),
    ]
    selected = archives + [executable, html]
    sums = {str(path.relative_to(DIST)): hashlib.sha256(path.read_bytes()).hexdigest() for path in selected}
    (DIST / 'SHA256SUMS.txt').write_text(''.join(f'{digest}  {name}\n' for name,digest in sums.items()), encoding='utf-8')
    (DIST / 'manifest.json').write_text(json.dumps({'title':'Mancebo Robles: El Imperio','sha256':sums},ensure_ascii=False,indent=2)+'\n', encoding='utf-8')
    print('Integridad de los ZIP comprobada; SHA256SUMS.txt generado.')


if __name__ == '__main__':
    main()
