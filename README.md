# Sky Rush

Prototipo 3D arcade de aviones hecho en Godot 4 con GDScript. El proyecto tiene dos modos jugables:

- `Carrera de anillos`: ruta de 15 anillos con cuenta regresiva y tiempo limite.
- `Mision de combate`: combate aereo arcade contra 5 aviones enemigos.

## Como abrir el proyecto

1. Abre Godot 4.7.
2. Importa o abre esta carpeta: `C:\Users\valen\OneDrive\Documentos\Juego`.
3. La escena principal configurada es `res://scenes/main.tscn`.

Tambien puedes usar `abrir_editor_godot.bat` desde esta carpeta.

## Como ejecutar el juego

- Desde Godot: pulsa `F5`.
- Desde Windows: ejecuta `abrir_juego.bat`.
- Para ver errores de consola: ejecuta `abrir_juego_con_errores.bat`.

Al iniciar aparece un menu con:

- `Carrera de anillos`
- `Mision de combate`
- `Controles`
- `Salir`

Durante una carrera o mision, pulsa `Escape` para abrir pausa. Desde ahi puedes continuar, reiniciar o volver al lobby principal.

## Controles

- `W`: bajar la nariz del avion.
- `S`: subir la nariz del avion.
- `A`: moverse/girar hacia la izquierda con inclinacion.
- `D`: moverse/girar hacia la derecha con inclinacion.
- `Q`: guinada hacia la izquierda.
- `E`: guinada hacia la derecha.
- `Shift`: activar turbo.
- `Click izquierdo`: ametralladora.
- `Click derecho`: misil.
- `C`: cambiar entre camara de tercera persona y camara cercana/cabina.
- `R`: reiniciar carrera o mision.
- `Escape`: pausar o reanudar. En pausa puedes volver al lobby.

## Carrera de anillos

- El avion empieza sobre un portaaviones.
- Hay una cuenta regresiva de 3 segundos.
- La carrera dura 2 minutos.
- Los anillos se activan en orden.
- El ultimo anillo completa la carrera.

## Mision de combate

- El jugador aparece en el aire sobre la zona del portaaviones.
- El objetivo es destruir 5 aviones enemigos.
- El HUD muestra vida, temperatura de ametralladora, misiles, fijacion y enemigos restantes.
- Si todos los enemigos son destruidos, se gana.
- Si la vida del jugador llega a cero o se estrella, se pierde.
- `R` reinicia la mision.

## Estructura de carpetas

- `scenes/main.tscn`: menu principal.
- `scenes/race/ring_race.tscn`: carrera de anillos.
- `scenes/combat/combat_mission.tscn`: mision de combate.
- `scenes/aircraft/`: avion del jugador.
- `scenes/enemies/`: avion enemigo reutilizable.
- `scenes/weapons/`: proyectil y misil.
- `scenes/camera/`: rig de camaras.
- `scenes/rings/`: anillos/checkpoints reutilizables.
- `scenes/ui/`: HUD.
- `scripts/aircraft/`: movimiento y estado del avion.
- `scripts/components/`: componentes reutilizables como vida.
- `scripts/weapons/`: ametralladora, misiles y proyectiles.
- `scripts/enemies/`: IA del avion enemigo.
- `scripts/game/`: reglas de carrera.
- `scripts/combat/`: reglas de mision de combate.
- `scripts/menu/`: menu principal.
- `scripts/ui/`: HUD y menu de pausa.
- `materials/`: materiales simples del prototipo.
- `resources/`: reservado para datos configurables futuros.

## Como modificar valores

Avion:

- Abre `scenes/aircraft/aircraft.tscn`.
- Selecciona el nodo `Aircraft`.
- Ajusta velocidades, aceleracion, giros, turbo, limites de altura y vida desde el inspector.

Armas:

- En `scenes/aircraft/aircraft.tscn`, selecciona `WeaponController`.
- Ajusta cadencia, dano, alcance, dispersion, calor, misiles y tiempo de fijacion.

Enemigos:

- Abre `scenes/enemies/enemy_aircraft.tscn`.
- Ajusta vida, velocidad, deteccion, distancia de ataque, dano y cadencia.

## Problemas pendientes

- Los modelos siguen hechos con formas simples; son mas legibles, pero no son arte final.
- La fijacion de misiles usa un cono frontal, no una reticula 2D exacta de pantalla.
- La IA ya tiene estados y evita obstaculos con raycast frontal, pero necesita ajuste manual fino para sentirse competitiva.
- El sonido de la ametralladora es procedural temporal y muy simple.
- No hay particulas reales; las explosiones y flashes son mallas/materiales temporales.

## Pruebas locales

Comandos usados para validar:

- Parseo de todos los scripts `.gd` con `--check-only`.
- `tests/validate_sky_rush.gd`
- `tests/validate_combat_systems.gd`
- Ejecucion headless corta de menu, carrera y combate.
