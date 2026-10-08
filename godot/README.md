# Mancebo Robles: El Imperio — Godot

Proyecto editable completo para **Godot 4.6.3**. Abre `project.godot` y pulsa **F6/F5** (F5 ejecuta el juego completo). El ejecutable Windows exportado se entrega en la distribución principal; no requiere instalar Godot.

Todo el arte de la ciudad, los personajes, los retratos y los efectos son originales y se dibujan o sintetizan en el código. No hacen falta paquetes, APIs, credenciales ni conexión a Internet para jugar.

## Controles

| Tecla | Acción |
|---|---|
| WASD / flechas | Caminar |
| Shift | Correr |
| E | Hablar con un contacto cercano / entrar al apartamento |
| I / Tab | Inventario, propiedades y estadísticas |
| M | Mapa de los seis distritos y contactos |
| J | Lista de las doce misiones |
| F5 | Guardar la partida |
| Esc | Cerrar la ventana de diálogo / pausar |

Las ventanas pausan el movimiento y la simulación. Usa el ratón para comprar, vender, ajustar cantidades y adquirir mejoras.

## Cómo jugar

Empiezas con 500 €, una mochila de 20 unidades y un apartamento en el Barrio. Habla con **Monfe**, compra tres unidades de **Bruma azul** y véndelas a **Lola**, en el Centro. Las recompensas de las misiones dan dinero y reputación para acceder al resto de la ciudad.

Los tres productos ficticios son Bruma azul, Sol fantasma y Eco de cristal. Compra a Monfe o Alejandro Peralta; vende a Lola, García o Navarro. Los precios varían según distrito, día y acontecimientos económicos aleatorios. Los clientes tienen presupuesto y los proveedores stock. Se renuevan al comenzar cada día de 90 segundos de simulación.

Toni vende tres propiedades por 1.500 / 3.500 / 7.000 €, con ingresos de 90 / 210 / 420 € cada veinte segundos. Monfe amplía la mochila. Scot vende información de precios. Soto reduce sospecha y multas. Cristian ofrece hasta cinco inversiones de 1.000 €, cada una con 120 € de ingreso por ciclo.

Las ventas elevan la sospecha. A partir de 40 las patrullas cercanas persiguen al protagonista. Corre y mantén distancia: la sospecha baja con el tiempo. Una inspección resta efectivo, incauta un 25% del inventario y te devuelve a casa. También puedes descansar en el apartamento por 25 € para reducirla.

Si te quedas con menos de 100 €, sin mercancía, propiedades ni inversiones, Monfe te enviará 150 € al comenzar el próximo día. Así siempre podrás retomar el comercio incluso después de varias inspecciones.

Completa las doce misiones, consigue las tres propiedades y alcanza **15.000 € de patrimonio** para ver el final. Después puedes seguir jugando.

## Guardado

Automático cada veinte segundos de simulación, después de compras/interacciones y al cerrar la ventana. Nueva partida reemplaza la partida anterior. `Continuar` recupera el archivo persistente `user://imperio_save_v1.json`. En Windows Godot lo guarda bajo `%APPDATA%/Godot/app_userdata/Mancebo Robles- El Imperio/`.

## Arquitectura y comprobaciones

- `scripts/state.gd`: economía, inventario, progresión, policía y persistencia.
- `scripts/city.gd`: mundo 2D, movimiento, colisiones, NPCs y patrullas.
- `scripts/main.gd`: interfaz, controles, retratos, sonidos y pantallas.
- `tests/smoke.gd`: pruebas reales de la ruta de las doce misiones, economía, guardado y botones de interfaz.
- `tests/visual.gd`: renderizado, entrada WASD, proximidad y capturas de pantalla; requiere una pantalla gráfica.

Validación: `godot --headless --path godot --script res://tests/smoke.gd` desde la raíz del repositorio. Ejecuta las pruebas con un directorio de datos Godot separado para preservar tu partida. En Linux puedes asignar `XDG_DATA_HOME` a un directorio temporal.

El ejecutable Windows se exporta con el preset `Windows Desktop`, arquitectura x86_64 y renderer Compatibility. Requiere una GPU/controlador con OpenGL 3.3. La ciudad es una campaña compacta: no incluye vehículos controlables, combate, multijugador ni doblaje.

Todos los personajes son caricaturas ficticias; los nombres no hacen afirmaciones sobre personas reales.
