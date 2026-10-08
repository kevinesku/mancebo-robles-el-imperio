# Mancebo Robles: El Imperio — v0.1.0

Entrega jugable para Windows y navegador, con proyecto Godot editable. Esta versión publica los ZIP existentes, sin reconstruir ni modificar el juego.

## Descargar y jugar

- **Mancebo-Robles-Windows.zip:** descomprime y ejecuta `Mancebo-Robles-El-Imperio.exe`. Windows de 64 bits; gráficos compatibles con OpenGL 3.3. No requiere instalar Godot.
- **Mancebo-Robles-HTML.zip:** descomprime y abre `Mancebo-Robles-El-Imperio.html` en tu navegador. Incluye el juego en un único archivo.
- **Mancebo-Robles-Fuentes.zip:** proyecto completo; abre `godot/project.godot` con Godot 4.6.3. También contiene fuentes HTML, herramientas, pruebas y documentación.

Controles: WASD/flechas para moverte, E para interactuar, I/Tab para inventario, M para mapa, Esc para pausa y F5 para guardar. Las ediciones Godot y HTML guardan partidas independientes.

## Integridad de los archivos originales

| Archivo | Bytes | SHA256 |
|---|---:|---|
| Mancebo-Robles-Windows.zip | 36.027.739 | `63b3ff9d8f98d4b25ff2d3113925326f8b3bbc9a93f44ef3d8646e04f5df369b` |
| Mancebo-Robles-HTML.zip | 28.089 | `37a0683f73160015c14c73ec3fe58e7870f10e5166e5f09a89b80097680c760f` |
| Mancebo-Robles-Fuentes.zip | 116.111 | `87574bb329564a3b9a61a39917623751c429f27cb71377b232a683911a2c22ee` |

Los tres ZIP pasan la comprobación CRC y coinciden con `dist/manifest.json` y `dist/SHA256SUMS.txt`. Las pruebas previas de entrega constan en `dist/RESULTADOS.md`: 107 comprobaciones de Godot, 14 pruebas de reglas web y pruebas de navegador. El paquete compilado de Windows fue comprobado con Godot en Linux; la ejecución nativa del EXE en Windows queda por comprobar.

Código y recursos propios bajo licencia MIT. El paquete Windows incluye las licencias de Godot y sus componentes.
