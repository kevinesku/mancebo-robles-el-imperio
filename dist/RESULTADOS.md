# Resultados de entrega — 8 de octubre de 2026

## Godot / Windows

- Godot 4.6.3 oficial; renderer Compatibility.
- Importación del proyecto: correcta, sin errores.
- **107 comprobaciones** de economía, restricciones de comercio, progresión de doce misiones, policía, recuperación tras bancarrota, guardado/carga y partidas corruptas: pasan.
- Se ejercitaron botones reales de compra y venta, los diez diálogos y pantallas de inventario, mapa, ajustes, pausa y final.
- Renderizado real en Linux mediante Xorg/OpenGL: menú, ciudad, diálogos y mapa comprobados; movimiento WASD y proximidad verificados.
- Plantillas Windows obtenidas de la distribución oficial y verificadas con su SHA-512 publicado. TLS y checksums se conservaron.
- Exportación Windows release x86_64: correcta, PE32+ con PCK incrustado.
- El **paquete compilado dentro del EXE** arranca con Godot Linux y pasa las mismas 107 comprobaciones, sin errores ni fugas.
- **No ejecutado el binario PE en Windows**: este entorno no dispone de Windows ni Wine. Es necesaria una comprobación en un equipo Windows para confirmar compatibilidad gráfica y arranque nativo.

## HTML

- **14 pruebas Node**: pasan. Incluyen dinero, capacidad, presupuestos, demanda, precios sin recompra rentable en el mismo contacto, propiedades, inversiones, patrullas, corrupt saves y doce misiones hasta el final.
- La prueba de campaña camina por rutas transitables respetando barrios bloqueados, sin teletransportar al personaje ni inyectar efectivo. La fortuna final se obtiene con comercio y rentas reales.
- Playwright/Chromium con entradas reales: nueva partida, introducción, WASD en cuatro direcciones, E, compra de cinco Brumas a Monfe, recorrido hasta Lola, venta de cinco, tres primeras misiones, HUD, pausa, ajustes/volumen con teclado, inventario, mapa y marca de destino: correcto.
- Guardar/recargar/continuar conserva dinero (955 €), inventario, posición y progreso. Cero errores JavaScript observados.
- Archivo HTML autocontenido probado por HTTP con todas las peticiones adicionales bloqueadas: solo se pide el HTML inicial y al recargar; no existen dependencias de red externas.
- Pantallas táctiles simuladas de 390×844 y 800×450: menú completo, movimiento, interacción E, compra y pausa pasan.
- El esquema `file://` está bloqueado por la política del Chromium administrado de este entorno. Se comprobó el archivo entregado por HTTP; no se ejercitó su apertura por doble clic aquí.

## Correcciones realizadas

Se corrigieron beneficios de recompra en HTML, reputación por encima del límite que invalidaba el guardado, cargas corruptas, teclado de ajustes bloqueado por los controles del juego, notificaciones sobre los diálogos, símbolos sin glifo, cámara fuera de la ciudad y controles táctiles en horizontal. En Godot se corrigieron etiquetas comprimidas, roles de comercio, validación atómica del guardado y el bloqueo económico por bancarrota.

## Entrega

Se incluyen ejecutable autónomo, HTML autónomo, proyecto Godot editable, código web, contenido narrativo, scripts de generación/exportación/empaquetado, pruebas, controles y licencias. Los ZIP se comprueban con `ZipFile.testzip`; `SHA256SUMS.txt` identifica los artefactos entregados. El ZIP de fuentes se extrajo en una carpeta limpia: Godot importó desde cero y se ejecutaron otra vez las 107 comprobaciones nativas y las 14 pruebas de reglas HTML, todas correctas.

Se guardaron `install_script` y `start_skill` en el borrador del entorno. Eso no publica ni activa la configuración: el usuario debe revisarla, guardarla y publicar el entorno en sus ajustes.

Pendientes de alcance: vehículos controlables, combate, multijugador, mando, doblaje y una campaña más extensa. Las partidas Godot y HTML son independientes.
