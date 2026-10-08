# Recuperar los paquetes existentes

Los tres ZIP originales se conservan en `dist/` y también están incluidos en el repositorio de GitHub. No hay que recompilar, exportar ni ejecutar `tools/package.py` para recuperarlos.

## Descargar desde el repositorio

Estos enlaces sirven incluso antes de publicar GitHub Releases. En la página de cada archivo, pulsa **Download raw file** si el navegador no inicia la descarga.

- [Windows — Mancebo-Robles-Windows.zip](https://github.com/kevinesku/mancebo-robles-el-imperio/blob/main/dist/Mancebo-Robles-Windows.zip?raw=true)
- [HTML — Mancebo-Robles-HTML.zip](https://github.com/kevinesku/mancebo-robles-el-imperio/blob/main/dist/Mancebo-Robles-HTML.zip?raw=true)
- [Godot y fuentes — Mancebo-Robles-Fuentes.zip](https://github.com/kevinesku/mancebo-robles-el-imperio/blob/main/dist/Mancebo-Robles-Fuentes.zip?raw=true)

Para repositorios privados necesitas iniciar sesión en GitHub con una cuenta que tenga acceso. También puedes pulsar **Code → Download ZIP** en el repositorio y encontrar los tres paquetes dentro de `dist/` tras descomprimirlo.

## Publicar v0.1.0 desde tu ordenador sin reconstruir

Necesitas [GitHub CLI](https://cli.github.com/), Git, Python 3 y permisos de escritura en el repositorio. En Linux/macOS o Git Bash con Python 3:

```bash
gh auth login --hostname github.com
gh repo clone kevinesku/mancebo-robles-el-imperio
cd mancebo-robles-el-imperio
bash tools/publish_existing_release.sh --verify-only
bash tools/publish_existing_release.sh
```

El script valida los hashes y CRC originales, crea un borrador v0.1.0 si aún no existe, sube únicamente los tres ZIP, los descarga para comprobar sus bytes y finalmente publica la versión. Si ya hay archivos con el mismo nombre, comprueba sus hashes y se detiene si son diferentes; no sobrescribe archivos de otra entrega.

La página de descarga, una vez publicada, será:

https://github.com/kevinesku/mancebo-robles-el-imperio/releases/tag/v0.1.0

La autenticación necesita acceso **Contents: read and write** para este repositorio. Con un token clásico: `repo` para un repositorio privado o `public_repo` para uno público. GitHub Actions usa `GITHUB_TOKEN` con `contents: write`. Introduce credenciales solo mediante el flujo seguro de `gh auth login` o los ajustes de GitHub; nunca en el chat.

Tras descargar Windows, descomprime su ZIP y abre el EXE. Para HTML, descomprime y abre el archivo `.html`. No necesitas las herramientas de publicación para jugar.
