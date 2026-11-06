# Rediseño como escape room (versión 0.4.0)

4 de noviembre de 2026. Este documento resume la auditoría, las decisiones de diseño y la arquitectura del rediseño de «Escape de Bucaramanga» como escape room.

## 1. Auditoría de la versión 0.3.0

### Tecnología

- **Godot 4.7** (GDScript), no HTML/CSS/JS a mano. La versión web es la exportación de Godot: WebAssembly y WebGL 2 dibujando en un `<canvas>`, con la plantilla HTML de Godot.
- Renderizador Forward+ en PC y Compatibilidad (WebGL 2) en web. Física Jolt. Navegación con `NavigationAgent3D` sobre una navmesh horneada al cargar.
- Todo el mundo se genera por código (texturas procedurales, MultiMesh para piezas repetidas). Casi no hay archivos de recursos: un `.pck` de menos de 1 MB.
- 39 pruebas de integración que corren dentro del motor (`tests/test_runner.tscn`).

**Se mantiene Godot.** Migrar a otro motor o a un framework web obligaría a rehacer el mundo 3D, la física, la policía y las pruebas sin ninguna ventaja para este proyecto.

### Problemas encontrados

| Problema | Efecto | Solución en 0.4.0 |
|---|---|---|
| No había controles táctiles | En celulares y tabletas no se podía jugar: el juego esperaba teclado y ratón capturado | Controles táctiles multitáctiles (`TouchControls`) |
| Interfaz en píxeles fijos (`stretch/mode="disabled"`) | Texto diminuto en pantallas de alta densidad (celulares) y enorme en monitores pequeños | `canvas_items` con base 1280×720 en horizontal y 720×1280 en vertical |
| Sin audio | Experiencia plana; nada avisaba de una persecución salvo el texto | Música, ambiente y efectos con buses y volúmenes |
| La misión era «recoge 5 cosas y entrégalas» | No había acertijos, inventario, pistas ni guardado | Escape room de 7 objetivos con 3 acertijos |
| Las acciones Inventario (Tab) y Mapa (M) existían sin función | Teclas que no hacían nada | Tab ahora abre el inventario; M sigue oculta en la configuración hasta que exista el mapa |
| En el navegador, soltar el ratón abría la pausa siempre | En una pantalla táctil la pausa se abriría sola | Con controles táctiles no se captura el ratón |
| La pausa no permitía reiniciar | Había que volver al menú | «Reiniciar la partida» (con confirmación) |
| El README enlazaba al sitio del repositorio anterior | Enlaces viejos | Enlaces corregidos |
| Fuente por defecto del motor y estilos repetidos en cada pantalla | Aspecto de prototipo | Tema global con tipografías y paleta propias (`UiStyle.theme()`) |

### Qué se conservó

La manzana 3D, el jugador, la cámara, la policía (patrulla, visión, oído, radio, búsqueda), los matorrales, el vendedor de granizados, los peatones, los semáforos, el minimapa, los perfiles de calidad, la reasignación de teclas, la pantalla de carga y la versión 2D clásica. La historia del malentendido y los personajes (Sebastián, Buitrago, Diaz y Gordo) son los mismos.

### Riesgos

- **Rendimiento web en celulares de gama media.** WebGL 2 en un celular dibuja a la resolución física de la pantalla. Se mantuvo el perfil Bajo por defecto en web (escala 3D 0,75, sin sombras de alta resolución) y la interfaz no agrega pasadas de render costosas. No se pudo medir en un celular real desde este entorno.
- **Audio en el navegador.** Los navegadores no dejan sonar nada hasta el primer clic o toque; el juego empieza a sonar en ese momento.
- **Cambios en la misión.** Las pruebas viejas que dependían de la misión anterior se adaptaron; las de movimiento y policía no cambiaron.

## 2. Diseño del escape room

### Historia

Son las 17:42 y alguien roba en la manzana. Una foto muestra a una persona con gorra roja, y la camiseta de Sebastián también es roja: la policía cree que fue él. Con sus amigos tiene que reunir las pruebas, abrir lo que está cerrado y reconstruir lo que pasó.

Todos los lugares y nombres comerciales son ficticios. No se agregó ningún dato sobre Bucaramanga que no estuviera ya en el juego.

### Objetivos y acertijos

| # | Objetivo | Cómo se resuelve | De dónde sale la respuesta |
|---|---|---|---|
| 1 | Encuentra la foto del robo | Subir las escaleras de la plaza | — |
| 2 | Recupera tu recibo | Saltar de caja en caja hasta la más alta | — |
| 3 | Abre la caja de grabación del túnel | **Acertijo 1:** teclado de 4 dígitos (HHMM). Clave: `1742` | La foto dice «17:42» |
| 4 | Encuentra el celular de Diaz | Al fondo de la calle del oriente | Lo dice Diaz |
| 5 | Desbloquea el celular | **Acertijo 2:** patrón 3×3 con forma de Z (1-2-3-5-7-8-9) | Diaz: «la última letra del abecedario» |
| 6 | Encuentra la gorra del ladrón | Solo aparece después de ver el video del celular | El video dice «al fondo de la calle norte» |
| 7 | Reconstruye lo que pasó | **Acertijo 3:** tres preguntas de opción múltiple con tus amigos | La hora (foto y video), la coartada (recibo) y el porqué de la confusión (gorra roja y camiseta roja) |

Los objetivos 1 a 4 se pueden hacer en cualquier orden. El 5 necesita el 4, el 6 necesita el 5 y el 7 necesita todos.

### Pistas

Cada objetivo tiene tres pistas que se revelan de una en una: la primera orienta, la segunda acerca y la tercera da la solución. Se piden con **H** o con el bombillo del HUD y siempre apuntan al primer objetivo pendiente que se puede hacer. No restan tiempo, pero se cuentan en el resultado final.

### Modos

| Modo | Límite | Errores en la reconstrucción |
|---|---|---|
| Explorador | Sin límite | Sin castigo |
| Contrarreloj | 15 minutos | +30 s cada vez |

El reloj sigue corriendo con los paneles de acertijos abiertos (la policía se congela), pero no en el menú de pausa.

### Resultado

Tiempo, pistas usadas, veces atrapado, errores y un rango: «Detective impecable» (nada), «Buen ojo» (hasta 3 en total) o «Salvado por los amigos».

### Guardado

`user://partida.cfg`, con escritura en dos pasos como la configuración. Se guarda al lograr cada objetivo, al pedir una pista, al ser atrapado, al pausar y cada 20 s. «Continuar» retoma desde el punto de inicio con todo lo conseguido (no se guarda la posición). Un archivo dañado o de otra versión se aparta como `.bad` y se empieza de cero. La partida se borra al ganar, al perder por tiempo o al empezar una nueva.

## 3. Arquitectura

```
src/
  escape/                 Lógica pura del escape room (sin nodos)
    escape_story.gd       Datos: objetos, pasos, pistas, acertijos, modos
    inventory.gd          Inventario (identificadores)
    hint_system.gd        Pistas por niveles
    save_game.gd          Guardado de la partida
  missions/
    escape_mission.gd     Reglas: objetivos, acertijos, reloj, policía, guardado
  interaction/
    lock_box.gd           Caja de grabación del túnel (objeto 3D)
    evidence_pickup.gd    Pruebas (ahora pueden estar ocultas hasta revelarse)
  ui/
    escape/               Paneles: inventario, pistas, teclado, patrón, reconstrucción
      modal_panel.gd      Base común (congela el mundo, Esc, foco, animación)
      escape_ui.gd        Decide qué panel abrir (Tab, H, pedidos de la misión)
      item_icon.gd        Iconos vectoriales dibujados con primitivas
    hud.gd                HUD rediseñado
    touch_controls.gd     Controles táctiles
    main_menu.gd          Portada
    shaders/title_backdrop.gdshader   Fondo animado de la portada
    ui_style.gd           Paleta, tipografías, tema global
  audio/audio_manager.gd  Autoload de música, ambiente y efectos
  core/game_session.gd    Autoload: modo elegido y si se continúa la partida
assets/
  fonts/                  Cinzel y Outfit (SIL Open Font License, con su licencia)
  audio/                  Audio generado por tools/generate_audio.py
tools/generate_audio.py   Sintetiza todo el audio con numpy (sin muestras de terceros)
web/shell.html            Plantilla HTML de la versión web (carga con la identidad del juego)
```

Reglas que se siguieron:

- **Los datos de la historia están en un solo archivo** (`EscapeStory`): textos, soluciones y pistas se revisan juntos, y una prueba comprueba que sean coherentes (la clave es la hora de la foto, la respuesta correcta coincide con la prueba, cada paso depende de uno anterior).
- **La misión no conoce la interfaz.** Pide paneles con la señal `panel_requested` y los paneles llaman a `try_code`, `try_pattern` y `submit_deduction`, que devuelven si se acertó. Así la lógica se prueba sin dibujar nada.
- **Un solo panel abierto a la vez.** `EscapeUi` lo controla; el mundo se congela con `PrototypeWorld.open_modal` y vuelve con `close_modal`, que también recaptura el ratón en PC.
- **Los controles táctiles pulsan las mismas acciones del InputMap** que el teclado, así el jugador y la policía no necesitan código especial.

## 4. Interfaz y accesibilidad

- **Paleta:** fondo tinta `#0B0D12`, ámbar de farol `#E9A945` (acción principal), rojo `#E2483D` (alertas, la camiseta de Sebastián), menta `#5FD3A5` (aciertos). Textos con contraste mayor a 4,5:1 sobre los fondos.
- **Tipografías:** Cinzel (títulos) y Outfit (texto), ambas con licencia SIL OFL incluida en `assets/fonts/`.
- **Foco visible** para teclado y mando en todos los botones; los paneles reciben el foco al abrirse.
- **Alternativas al ratón:** todo se puede hacer con teclado (dígitos en el teclado de la caja, teclas 1-9 en el patrón), con mando o con el dedo.
- **Reducir animaciones** (Configuración → Interfaz): apaga el fondo animado, el grano y las transiciones.
- **Sonido:** volumen general, música, ambiente y efectos por separado, y un botón para silenciar en el HUD.
- **Pantallas verticales:** la portada pasa a una columna y el juego sugiere girar el teléfono.

## 5. Rendimiento

- Ningún recurso nuevo pesa: las tipografías son 236 KB y todo el audio 660 KB (Ogg Vorbis mono a 22 kHz). Los iconos son vectoriales y el fondo de la portada es un shader de una pasada.
- El HUD redibuja solo el minimapa y los controles táctiles en cada cuadro.
- La música se carga una vez y se repite en bucle; los efectos usan 6 reproductores reutilizables.

## 6. Mejoras futuras recomendadas

1. Medir en celulares reales de gama media y, si hace falta, bajar más la escala 3D en web móvil.
2. Una pasada de diseño de sonido con grabaciones reales con licencia libre (el audio actual es sintetizado).
3. El modelo definitivo de Sebastián y animaciones (Fase 3 del plan).
4. Más casos con la misma estructura: `EscapeStory` ya separa los datos de la lógica.
5. Traducción al inglés: todos los textos de la historia están en un solo archivo.
6. Plantilla web propia sin los módulos de Godot que no se usan, para bajar los ~10 MB comprimidos del motor.
