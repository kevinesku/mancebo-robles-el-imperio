# Mancebo Robles: El Imperio

Videojuego jugable de economía, exploración y estrategia en una ciudad mediterránea nocturna. Empiezas con 500 €, un móvil y un apartamento; construyes tu imperio mediante comercio de mercancías imaginarias, contactos y negocios. Todos los personajes son caricaturas ficticias y los nombres no describen a personas reales.

## Jugar

- **Windows 64 bits:** descomprime `dist/Mancebo-Robles-Windows.zip` y abre `Mancebo-Robles-El-Imperio.exe`. Los recursos están incrustados: no necesitas instalar Godot ni descargar nada para jugar. Usa un equipo con OpenGL 3.3.
- **HTML:** abre `dist/html/Mancebo-Robles-El-Imperio.html` en un navegador de escritorio. Es un único archivo con el juego completo. También está en `dist/Mancebo-Robles-HTML.zip`.
- **Fuente editable:** descomprime `dist/Mancebo-Robles-Fuentes.zip`, abre `godot/project.godot` con Godot **4.6.3** y pulsa F5. La versión web está en `web/`.

Las ediciones Godot y HTML tienen el mismo concepto, personajes y objetivo, con precios, rutas de misiones y equilibrio propios. Sus partidas no son intercambiables.

## Controles

| Tecla | Acción |
|---|---|
| WASD / flechas | Moverte por la ciudad |
| E | Hablar con un NPC o entrar en casa |
| I / Tab | Inventario y estadísticas |
| M | Mapa de los seis barrios |
| Esc | Cerrar diálogo / pausar |
| F5 | Guardar partida |
| Shift | Correr, en Godot |
| J | Misiones, en Godot |

Compra y vende con el ratón en los diálogos. Las ventanas detienen el tiempo y las patrullas. La edición HTML también tiene controles táctiles.

## Primeros pasos

Habla con Monfe, junto a tu apartamento. En **Windows/Godot**, compra tres Brumas azules y véndelas a Lola en el **Centro**. En **HTML**, compra cinco y véndelas a Lola en el **Barrio**. El indicador de misión y el mapa te guían. El Centro ya está abierto en Godot; en HTML se abre con la reputación de las primeras operaciones.

Compra barato a Monfe o Alejandro Peralta y vende en zonas con mejores precios. Los clientes tienen presupuesto y demanda limitados; el mercado se renueva cada día. Evita las patrullas cuando suba la sospecha. Las propiedades producen ingresos y cuentan para el objetivo de **15.000 € de patrimonio y tres negocios**. Completa las doce misiones para alcanzar el final; puedes seguir jugando después.

## Implementado

- Ciudad 2D cenital con seis distritos, edificios con colisiones, iluminación y personajes animados.
- Diez NPC: Monfe, Scot, García, Toni Escrig, Navarro («50 Cent el Europeo»), Alejandro Peralta, Xoxi, Soto, Cristian Martín y Lola.
- Diálogos y funciones diferenciadas; tres productos ficticios y precios variables por barrio y eventos.
- Dinero, capacidad de inventario, presupuestos, gastos, reputación, barrios bloqueados y estadísticas.
- Doce misiones con recompensas, mejoras, propiedades e inversiones.
- Patrullas, sospecha, persecución, multas, confiscación y recuperación en el barrio.
- Menú, nueva partida, continuar, ajustes, HUD, mapa, inventario, retratos, notificaciones y sonidos sintetizados.
- Introducción, final narrativo y guardado automático persistente.

Arte, mapas, retratos y sonidos creados en código; no requieren recursos externos. El juego funciona sin APIs ni credenciales.

## Guardado

Godot guarda en `user://imperio_save_v1.json`, dentro de la carpeta de datos del usuario. Se guarda periódicamente, después de operaciones y al cerrar.

HTML guarda en el almacenamiento local del navegador, clave `mancebo-robles-save-v1`, cada diez segundos y después de operaciones. Usa el mismo navegador, ubicación de archivo u origen HTTP. El modo privado o las restricciones de almacenamiento pueden impedir la persistencia; la interfaz avisa si falla. Nueva partida solicita confirmación si existe una partida válida.

## Desarrollo y pruebas

No hay dependencias npm. Necesitas Python 3 para empaquetar/servir, Node.js para las pruebas de reglas y Godot 4.6.3 para el proyecto nativo. Playwright y Chromium solo se necesitan para la prueba del navegador.

```bash
python3 tools/build_html.py
node --test tests/web_model.test.js
python3 tests/browser_smoke.py
```

Para servir la edición web durante el desarrollo:

```bash
python3 -m http.server 8000 --bind 127.0.0.1 --directory web
```

En Linux configura directorios de datos escribibles y aislados antes de importar/probar Godot. Esto protege tus partidas de desarrollo:

```bash
mkdir -p /tmp/imperio-check/{data,cache,config}
export XDG_DATA_HOME=/tmp/imperio-check/data
export XDG_CACHE_HOME=/tmp/imperio-check/cache
export XDG_CONFIG_HOME=/tmp/imperio-check/config
godot --headless --path godot --editor --import
godot --headless --path godot --script res://tests/smoke.gd
```

`tests/visual.gd` verifica renderizado, movimiento y proximidad con una pantalla gráfica. `tests/browser_smoke.py` verifica con teclado y botones reales comercio, guardado, pausa y ajustes, y registra capturas en `tests/artifacts/`.

## Exportar y empaquetar

```bash
MANCEBO_CACHE_DIR=/workspace/.cache/mancebo-robles tools/export_windows.sh
python3 tools/package.py
```

El exportador descarga las plantillas oficiales 4.6.3 (1,26 GB) cuando faltan, conserva TLS y verifica el SHA-512 oficial antes de extraerlas. Reutiliza la caché. Exporta un PE64 con PCK incrustado, verifica su estructura y ejecuta el paquete y las pruebas con el Godot local antes de reemplazar el ejecutable anterior. Para descargar/verificar solo las plantillas: `tools/export_windows.sh --prepare`.

## Alcance y comprobaciones

Esta entrega es una campaña compacta jugable. Quedan fuera vehículos controlables, combate, multijugador, doblaje, mando y una campaña extensa con ramificaciones. La edición HTML dispone de una marca de destino; Godot tiene un minimapa permanente.

Las reglas web se prueban con recorridos reales por el mapa y una campaña completa sin añadir dinero. Godot se prueba en fuente y en el paquete exportado, además de renderizado real en Linux. El ejecutable se ha generado y su paquete compilado se ha probado; **su ejecución nativa en Windows no se ha comprobado en este entorno**. Consulta `dist/RESULTADOS.md` y `dist/windows/VERIFICACION.txt` para los resultados concretos.

El navegador administrado de este entorno bloquea el esquema `file://`; el HTML autocontenido se valida servido por HTTP y sin dependencias externas. La apertura por doble clic debe comprobarse en el navegador del usuario.

Código y recursos propios bajo MIT. La distribución Windows incluye las licencias de Godot y sus componentes.
