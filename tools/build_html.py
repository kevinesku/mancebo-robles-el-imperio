#!/usr/bin/env python3
"""Build an offline HTML game, using only Python's standard library."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'web'
OUT = ROOT / 'dist' / 'html'


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    data = json.loads((ROOT / 'shared/content.json').read_text(encoding='utf-8'))
    content = '/* Original fictional story. */\nwindow.IMPERIO_CONTENT = ' + json.dumps(data, ensure_ascii=False) + ';\n'
    (WEB / 'content.js').write_text(content, encoding='utf-8')
    html = (WEB / 'index.html').read_text(encoding='utf-8')
    css = (WEB / 'style.css').read_text(encoding='utf-8')
    html = html.replace('<link rel="stylesheet" href="style.css">', '<style>\n' + css + '\n</style>')
    for name in ('content.js', 'model.js', 'game.js'):
        code = (WEB / name).read_text(encoding='utf-8').replace('</script', '<\\/script')
        html = html.replace('<script src="' + name + '"></script>', '<script>\n' + code + '\n</script>')
    target = OUT / 'Mancebo-Robles-El-Imperio.html'
    target.write_text(html, encoding='utf-8')
    (OUT / 'LEEME.txt').write_text(
        'MANCEBO ROBLES: EL IMPERIO — EDICIÓN HTML\n\n'
        'Abre Mancebo-Robles-El-Imperio.html en Chrome, Edge o Firefox.\n'
        'El archivo contiene todo el juego y funciona sin conexión.\n'
        'Controles: WASD/flechas mover; E hablar; I inventario; M mapa;\n'
        'Esc cerrar/pausa; F5 guardar. Usa el ratón para comerciar.\n'
        'Empieza con Monfe, compra 5 Brumas y véndelas a Lola en el barrio.\n'
        'Los diálogos pausan el tiempo. Descansa en tu apartamento para\n'
        'renovar los presupuestos y precios. Sigue las doce misiones.\n\n'
        'Guardado automático en el almacenamiento local del navegador.\n'
        'Usa el mismo navegador y archivo. El modo privado o las restricciones\n'
        'de almacenamiento pueden impedir la persistencia. El juego avisa.\n'
        'La edición HTML y la edición Godot tienen equilibrio y partidas separados.\n', encoding='utf-8')
    print(f'HTML offline generado: {target} ({target.stat().st_size:,} bytes)')


if __name__ == '__main__':
    build()
