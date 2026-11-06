# Pruebas

## Cómo ejecutarlas

```bash
# Juego 3D: 54 pruebas de integración
godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn

# Capturas de pantalla (necesita ventana; no funciona con --headless)
godot --path . res://tests/screenshots.tscn -- <carpeta> <bajo|medio|alto>

# Versión 2D clásica
godot --headless --path clasico-2d res://tests/test_runner.tscn
godot --headless --path clasico-2d --fixed-fps 60 res://tests/bot_runner.tscn
```

`test_runner` sale con código 0 si todo pasa y 1 si algo falla. Usa su propio archivo de configuración (`user://test_settings.cfg`) y lo borra al terminar: no toca la configuración del jugador.

## Resultados de la versión 0.4.0 (5 de noviembre de 2026)

Entorno: Godot 4.7.2 estable, Linux, headless, física a 60 Hz. **54 OK, 0 fallos.** Las 39 anteriores siguen pasando (`test_evidence_pickup` y `test_friends_complete_mission` se adaptaron al escape room) y se agregaron 15:

| Prueba | Qué comprueba |
|---|---|
| test_story_data_is_consistent | Tres pistas por paso, dependencias hacia atrás, la clave es la hora de la foto, respuestas válidas, objetos completos |
| test_inventory_and_hint_units | Sin repetidos, reemplazo en orden, carga con datos inválidos, tres pistas y límite al cargar |
| test_hints_follow_current_step | Las pistas apuntan al objetivo pendiente; no hay cuarta pista |
| test_lock_box_code | Revisar la caja agachado en el túnel; hora equivocada, incompleta y correcta; entrega la USB; el panel se cierra |
| test_phone_pattern_reveals_cap | Celular bloqueado al inventario, patrón equivocado y la Z; aparece la gorra |
| test_diaz_tells_the_pattern | Diaz dice la pista; «Usar» en el inventario abre el patrón |
| test_deduction_wrong_then_right | Contrarreloj de 15 min, respuestas incompletas y equivocadas (+30 s), victoria y rango |
| test_inventory_and_hint_panels_toggle | Tab abre y cierra (también con la tecla real), H y Esc; con la pausa no se abren paneles |
| test_save_and_continue | Guardar y continuar: modo, objetivos, inventario, tiempo, pistas, caja abierta, pruebas recogidas |
| test_corrupt_save_is_ignored | Partida dañada: se aparta y se empieza de cero |
| test_time_limit_ends_game | Se acaba el tiempo: pantalla y controles bloqueados |
| test_restart_from_pause | La pausa guarda; reiniciar pide confirmación y descarta la partida |
| test_touch_controls_drive_actions | Palanca, botón Saltar y cámara con el dedo |
| test_ui_scales_with_orientation | Base 1280×720 o 720×1280, tema y tipografías cargados |
| test_audio_buses_and_volume | Buses, archivos de audio, volumen, silencio y bucle |

**Prueba manual de la versión web** (exportada con la plantilla sin hilos, servida localmente y abierta en Chromium con SwiftShader mediante Playwright): carga con la pantalla propia, portada, elección de modo, juego, Tab abre y cierra el inventario, H abre las pistas. Con un celular emulado (Pixel 7 en horizontal, toques reales) los toques en la portada y el modo funcionan y aparecen los controles táctiles. No hubo errores de JavaScript en la consola. No se pudo probar en un celular físico ni medir FPS (no hay GPU en este entorno).

## Resultados de la versión 0.3.0 (4 de noviembre de 2026)

Entorno: Godot 4.7.2 estable, Linux, modo headless, física a 60 Hz fija. **39 OK, 0 fallos** (tres corridas seguidas iguales). Las 24 pruebas de la Fase 2 siguen pasando (se ejecutan con la policía apagada para que no interfiera) y se agregaron 15:

| Prueba | Qué comprueba | Resultado |
|---|---|---|
| test_navmesh_and_paths | La navmesh se hornea y hay ruta desde el inicio a las pruebas de la calle, los amigos, el vendedor y las rutas de patrulla | OK |
| test_police_patrols | Un policía recorre su ruta (cruza la calle y sube el bordillo) | OK |
| test_police_sees_player_in_open | A 11 m de frente y sin obstáculos lo ve y lo persigue | OK |
| test_police_blind_through_buildings | Con un edificio en medio no lo detecta | OK |
| test_police_does_not_see_behind | Detrás y quieto no lo ve | OK |
| test_crouching_reduces_view | Agachado a 12 m no lo ve | OK |
| test_police_catches_player | Lo atrapa, bloquea los controles, muestra la pantalla, lo devuelve con los amigos y la policía vuelve a patrullar tras 3 s | OK |
| test_hidden_player_is_lost | En persecución, se esconde en un matorral: la policía busca, se rinde y vuelve a su ruta sin atraparlo | OK |
| test_radio_calls_nearby_officer | Al empezar una persecución, otro policía cercano recibe el aviso | OK |
| test_hiding_requires_crouch | En el matorral solo queda escondido agachado | OK |
| test_evidence_pickup | Recoger una prueba con E; la misión y el HUD la cuentan | OK |
| test_vendor_granizado | El granizado llena la resistencia y correr no la gasta durante el efecto | OK |
| test_friends_complete_mission | Sin las pruebas no termina; con las 5 se gana y sale la pantalla de victoria | OK |
| test_civilians_walk | Los peatones caminan por la manzana | OK |
| test_traffic_lights_cycle | Los semáforos de los dos ejes están coordinados (verde/rojo, luego amarillo) | OK |

Construir la manzana (texturas procedurales, edificios, utilería, navmesh, personajes) y avanzar 30 cuadros toma ≈ 0,9 s en este entorno (CPU, sin GPU).

## Resultados de la Fase 2 (3 de noviembre de 2026)

Entorno: Godot 4.7.2 estable, Linux, modo headless, física a 60 Hz fija.

| Prueba | Qué comprueba | Resultado |
|---|---|---|
| test_project_configuration | Forward+ en PC, Compatibilidad en web, Jolt, autoloads | OK |
| test_input_actions_exist | Las teclas del encargo (WASD, Shift, Espacio, C, E, F, Tab, M, Esc) | OK |
| test_rebind_and_persist | Reasignar, guardar, "reiniciar" y restaurar | OK |
| test_rebind_swaps_conflicting_key | Intercambio de teclas en conflicto; Esc reservada | OK |
| test_settings_roundtrip_and_corrupt_file | Guardado de configuración; archivo dañado → valores por defecto y copia `.bad` | OK |
| test_world_builds | Manzana, sombras, ventanas con MultiMesh (>100 instancias), cámara activa | OK |
| test_player_lands_on_ground | Cae y queda apoyado en la acera | OK |
| test_walk_relative_to_camera | Avanza hacia donde mira la cámara a velocidad de caminar | OK |
| test_run_is_faster_and_uses_stamina | Correr es más rápido, gasta y recupera resistencia | OK |
| test_stamina_exhaustion_forces_walk | Sin resistencia pasa a caminar | OK |
| test_jump_height | Salto entre 1,0 y 1,3 m y aterrizaje | OK |
| test_short_jump_is_lower | Soltar el salto pronto lo hace más bajo | OK |
| test_wall_blocks_player | No atraviesa fachadas | OK |
| test_step_up_curb | Sube el bordillo de 15 cm caminando | OK |
| test_climb_stairs | Sube 8 escalones de 17 cm hasta la plataforma | OK |
| test_walk_up_ramp | Sube la rampa de 15° | OK |
| test_steep_slope_not_climbable | No sube la pendiente de 50° | OK |
| test_box_heights | Caja de 0,3 m caminando; 0,6 m solo saltando | OK |
| test_crouch_tunnel | De pie no entra; agachado sí; no se levanta bajo el techo; fuera sí | OK |
| test_camera_does_not_clip_wall | Con una pared detrás, la cámara se acerca y queda fuera del edificio | OK |
| test_camera_rotation_moves_player_direction | Girar la cámara cambia la dirección de avance y el cuerpo gira | OK |
| test_quality_profiles_apply | Los tres perfiles cambian escala, distancia de dibujo y sombras | OK |
| test_scene_loader_missing_scene | Escena inexistente → pantalla de error, sin bloquear el cargador | OK |
| test_fall_reset | Caer fuera del mapa devuelve al inicio | OK |
| **Total** | | **24 OK, 0 fallos** |

Versión 2D en `clasico-2d/` después de moverla: **14 OK, 0 fallos**; bot: **7 de 7 niveles**.

## Prueba en navegador (Fase 2)

Chromium sin pantalla (Playwright) con WebGL 2 por software (SwiftShader), sirviendo `build/web` en local:

| Comprobación | Resultado |
|---|---|
| Carga y muestra el menú | Sí (captura `capturas/fase2/web_menu.jpg`) |
| "Jugar el prototipo" carga la manzana | Sí |
| W mueve al personaje | Sí |
| Esc abre la pausa | Sí (captura `capturas/fase2/web_pausa.jpg`) |
| Errores en la consola | Ninguno (se corrigieron dos: una función de teclado no soportada en web y FXAA en Compatibilidad) |

## Capturas

`capturas/v0.3/`: `pc_alto_*` con Forward+ (Vulkan por software, perfil Alto) y `compat_bajo_*` con el renderizador de Compatibilidad (el mismo de la versión web) en perfil Bajo, generadas con `tests/screenshots.tscn`. La versión web exportada no se volvió a probar en el navegador en esta versión.

`capturas/fase2/`: `pc_alto_*` con Forward+ (Vulkan por software, perfil Alto) y `web_*` con la exportación web en Chromium (perfil Bajo).

## Rendimiento

**Todavía no hay mediciones válidas de FPS.** Este entorno no tiene tarjeta gráfica: todo se dibuja por software en la CPU (Xeon de 4 núcleos), y en el navegador marcó 2-3 FPS, lo que **no representa** el rendimiento en un PC real.

Para medir en tu PC: abre el juego o la versión web, pulsa **F3** y anota FPS y tiempo de cuadro en el cruce, con cada perfil. Datos que conviene anotar:

| Equipo (CPU / GPU / RAM) | Plataforma (PC o navegador y versión) | Perfil | Resolución | FPS | Tiempo de cuadro |
|---|---|---|---|---|---|
| (pendiente) | | | | | |

Valores de la escena medidos con el medidor (independientes de la GPU): en el cruce, ≈ 360 llamadas de dibujo y ≈ 465 objetos visibles con el perfil Bajo en web. Reducir las llamadas de dibujo (unir geometría estática, más instancing) es parte de la Fase 11.
