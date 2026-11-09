# Cambios

## 0.6.0 — La gran huida (9 de noviembre de 2026)

Detalle: [DOCUMENTACION/GRAN_HUIDA.md](DOCUMENTACION/GRAN_HUIDA.md).

### Campaña
- **Capítulo 5 · La gran huida** (de madrugada, en Cabecera): Lucía en la fuente, escalera de incendios, cinco terrazas, oficina de El Búho con caja fuerte (clave 1622), alarma con patrullas y drones, tirolesa al parque y carrera al Puente de la Novena antes de que salga el sol (170 s).
- El capítulo 4 lleva ahora al 5, que cierra la primera temporada.

### Mundo
- Mapa nuevo de 140 × 140 m inspirado en Cabecera del Llano: Parque de las Palmas con fuente y chorros, palmas, monumento y kiosco; Carrera 33 con separador; terrazas; torres con luz de aviación; centro comercial; cañada con puente en arco.
- Títulos de zona al entrar por primera vez a cada lugar.
- Horas «madrugada» y «amanecer», con el cielo aclarándose durante la huida.
- El minimapa dibuja el mapa de cada capítulo.

### Movimiento y juego
- Rodar al caer de alto (C, o venir corriendo), caída dura que aturde y caída muy alta que quita un corazón.
- Tirolesa (E para colgarse, Espacio para soltarse).
- Drones de vigilancia con cono de luz y estados (patrulla, seguimiento, búsqueda, regreso).
- Sacudida de cámara en golpes, caídas y alarmas (reducida con «Reducir animaciones»).
- Pasos con sonido.

### Cinemáticas e interfaz
- Tres cinemáticas cortas con franjas y subtítulos; se saltan con E, Espacio, Esc, clic o toque.
- Páginas de Créditos y Estadísticas; Esc vuelve a la portada desde cualquier página del menú.
- Pantallas de derrota nuevas: «Caída» y «Salió el sol».
- 4 logros nuevos (16) y 5 postales nuevas (15).

### Audio
- Música del final, bucles del dron y de la tirolesa, y 8 efectos nuevos, todos sintetizados.

### Correcciones
- En la selección de capítulos faltaba el nombre de la hora de la madrugada (quedaba «· ·»).

### Pruebas
- 17 pruebas nuevas (89 en total) y capturas con `tests/v06_screenshots.tscn`.

## 0.5.0 — Aventura urbana en capítulos (8 de noviembre de 2026)

Detalle del diseño y los sistemas: [DOCUMENTACION/AVENTURA_URBANA.md](DOCUMENTACION/AVENTURA_URBANA.md).

### Campaña
- Cuatro capítulos que se desbloquean en orden. El 1 es el escape room de la 0.4 sin cambios.
- **Capítulo 2 · El robo de la plaza** (de mañana): testigo, tres pistas, identificar al ladrón entre cuatro personas, seguirlo sin que te vea (te ve si mira hacia atrás; lo pierdes a más de 30 m), distraerlo con una lata para sacar el sobre de la natillera y volver sin que te atrape la policía.
- **Capítulo 3 · Sombras en el callejón** (de noche): bodega nueva en el patio noreste con puerta, rejilla para entrar agachado y oficina; tres vigilantes, dos cámaras de seguridad, tres documentos para fotografiar y el libro de cuentas.
- **Capítulo 4 · Persecución urbana** (de noche, con lluvia): empieza en Persecución; túnel, perder a la policía, mochila con impermeable (disfraz) y refugio.
- Tres corazones y puntos de control desde el capítulo 2; sin corazones, derrota con «Reintentar».

### Progresión (se guarda aparte, en `user://perfil.cfg`)
- 10 niveles con XP por objetivo, capítulo, bonos, logros y postales; un punto de habilidad por nivel.
- 6 habilidades, tienda con 4 objetos, 12 logros y 10 postales con datos de Bucaramanga.
- Recompensas al terminar cada capítulo (XP, dinero y reputación); repetir paga el 25 %.

### Jugabilidad
- Nivel de búsqueda de 5 niveles (Tranquilo a Cerco) con refuerzos desde Persecución.
- Latas para distraer (G), cámaras de seguridad, disfraz (Q).
- Trepar muros bajos saltando contra ellos y deslizarse agachándose al correr.

### Gráficos y audio
- Mañana, tarde y noche con faroles encendidos; lluvia con partículas.
- Bodega, camión, contenedores y cajas; columnas de luz para los puntos de encuentro.
- 13 efectos nuevos (salto, aterrizaje, deslizada, lanzamiento, lata, moneda, alarma, nivel, punto de control, logro, cámara, compra) y ambiente de lluvia, todos sintetizados.

### Interfaz
- Portada con la campaña, selección de capítulos, páginas de perfil y habilidades, tienda y logros.
- HUD con corazones, latas, nivel de búsqueda, barra del capítulo, nivel/XP/dinero, aviso de nivel nuevo y de logros.
- Victoria con el detalle de recompensas y «Siguiente capítulo».
- Pausa con el perfil y la tienda, «Volver al punto de control» y «Reiniciar el capítulo».
- Botones táctiles Lata y Disfraz.

### Correcciones
- «Jugar otra vez» y «Reiniciar» cargaban siempre el capítulo 1 y su título; ahora usan el capítulo actual.
- Activar o desactivar un marcador dentro de su propia señal de entrada daba error de física; ahora se aplica al final del cuadro.

### Pruebas
- 18 pruebas nuevas (72 en total). `TEST_ONLY=...` corre solo las indicadas. Capturas nuevas con `tests/adventure_screenshots.tscn`.

## 0.4.0 — Rediseño como escape room (5 de noviembre de 2026)

### Gameplay
- La misión pasa a ser un escape room de 7 objetivos: foto del robo, recibo, caja de grabación del túnel (clave 1742, la hora de la foto), celular de Diaz, su patrón (Z, «la última letra del abecedario»), la gorra del ladrón (aparece después de ver el video) y la reconstrucción final con tres preguntas.
- Inventario (Tab o I) con descripción de cada prueba y botón Usar.
- Pistas por niveles (H): tres por objetivo, la última da la solución.
- Modos Explorador (sin límite) y Contrarreloj (15 min, +30 s por respuesta equivocada).
- Resultado final con tiempo, pistas, veces atrapado, errores y rango; pantalla de tiempo agotado.
- Guardado automático (`user://partida.cfg`) y «Continuar» en la portada; «Reiniciar la partida» en la pausa.

### Interfaz
- Portada nueva con fondo animado por shader, introducción, elección de modo, «Cómo se juega» y expediente del caso.
- Tema global con paleta propia y tipografías Cinzel y Outfit (OFL); foco visible en todos los botones.
- HUD nuevo: lista de objetivos, reloj, botones de inventario, pistas, sonido y pausa, tarjeta animada al descubrir una prueba, viñeta roja en persecución.
- Paneles de teclado, patrón y reconstrucción con respuesta visual y sonora al acertar o fallar.
- Interfaz escalada (`canvas_items`), con base vertical en celulares; plantilla HTML web propia con pantalla de carga.
- Opción «Reducir animaciones».

### Audio
- Música de portada, exploración y persecución (se mezcla según la alerta de la policía), ambiente de ciudad y 13 efectos. Volúmenes por separado y silencio.

### Táctil
- Palanca virtual, cámara con el dedo y botones Usar, Saltar, Agachar y Correr (multitáctil). Automático en pantallas táctiles o desde Configuración.

### Pruebas
- 15 pruebas nuevas (54 en total): datos de la historia, inventario y pistas, caja, patrón, Diaz, reconstrucción, paneles con teclado, guardado y partida dañada, contrarreloj, reinicio, táctil, escalado y audio.

## 0.3.0 — Gráficos, policía e interacción (4 de noviembre de 2026)

Adelanto de partes de las Fases 5 (ambiente), 6 (policía) y 8 (una misión) sobre la manzana de prueba, a pedido del usuario. La ciudad de Bucaramanga y el modelo definitivo de Sebastián siguen pendientes.

### Gráficos
- Luz de final de la tarde: sol bajo y cálido, sombras largas y suaves, cielo con degradado, niebla cálida, corrección de color, SSIL en el perfil Alto.
- Texturas procedurales con mapa de normales (`TextureFactory`): asfalto con grietas, baldosas de andén, ladrillo a la vista y adoquín de ladrillo en la plaza, revoque en las fachadas.
- Fachadas con franjas entre pisos, ventanas con marco y alféizar (algunas encendidas), balcones con baranda, zócalo, terraza con tanques de agua y aires acondicionados; uno de cada cuatro edificios es de ladrillo.
- Locales con vitrina de vidrio, interior iluminado, montantes, toldos de colores y letrero con nombre (nombres ficticios: «Tienda Doña Rosa», «Panadería El Santandereano»…).
- Utilería urbana: carros parqueados, patrulla con luces intermitentes, semáforos con ciclo real, faroles con brazo y bombillo, postes de concreto con cables, bolardos, canecas, paradero, kiosco, carrito de granizados, árboles más frondosos (algunos ocobos florecidos) y matorrales.
- Personajes con más detalle (rodillas y codos articulados, cara, orejas, pelo, gorra, chaleco reflectivo), compartidos por Sebastián y los demás.
- Las piezas repetidas (ventanas, marcos, balcones, barrotes, tanques, cables, bolardos) se dibujan con MultiMesh.

### Policía (ficticia, sin violencia)
- Tres policías a pie patrullan rutas por andenes y calles con navegación (`NavigationAgent3D` sobre una navmesh horneada al cargar).
- Estados: patrulla, sospecha, persecución, búsqueda y regreso. Indicador «?» / «!» sobre la cabeza.
- Percepción: cono de visión de 110° y 17 m con línea de vista (edificios y carros tapan); agachado ven la mitad de lejos; corriendo te oyen a 6 m aunque estés detrás.
- Aviso por radio: al empezar una persecución, los policías a menos de 35 m van a buscar.
- Si te alcanzan, «¡Te atraparon!»: vuelves con tus amigos sin perder las pruebas y la policía regresa a sus rutas tras 3 s.

### Interacción y misión
- Tecla Interactuar (E) activa, con texto de ayuda en pantalla.
- Misión «Las pruebas del malentendido»: 5 pruebas repartidas (arriba de las escaleras, dentro del túnel, sobre la caja alta, al fondo de dos calles) que hay que llevar a Buitrago, Diaz y Gordo en la zona verde. Pantalla de victoria con tiempo y veces atrapado.
- Matorrales para esconderse: agachado adentro, la policía no te ve.
- Vendedor de granizados: resistencia sin límite durante 25 s.
- Peatones que caminan por la manzana y dan pistas al hablarles.
- HUD: objetivo y lista de pruebas, alerta de la policía, «ESCONDIDO», avisos, minimapa con policías y su cono de visión.

### Pruebas
- 15 pruebas nuevas (39 en total): navmesh y rutas, patrulla, detección con y sin línea de vista, por detrás, agachado, captura, escondite, radio, recoger pruebas, granizado, final de la misión, peatones y semáforos.


## 0.2.0 — Fase 2: prototipo 3D (3 de noviembre de 2026)

### Agregado
- Proyecto 3D en Godot 4.7 en la raíz del repositorio: Forward+ en PC, Compatibilidad (WebGL 2) en web, física Jolt.
- Autoloads `EventBus`, `Settings` (configuración en `user://settings.cfg` con escritura segura y recuperación de archivos dañados), `InputConfig` (controles del encargo, reasignables, con intercambio de teclas en conflicto) y `SceneLoader` (pantalla de carga y pantalla de error).
- Jugador con máquina de estados (quieto, caminar, correr, saltar, caer, agacharse), resistencia, tiempo de coyote, búfer de salto, salto variable, subida automática de bordillos y escalones de hasta 36 cm, y comprobación de techo al levantarse.
- Cámara en tercera persona sobre el hombro con SpringArm3D (no atraviesa paredes), ratón y palanca derecha, sensibilidad, inversión y campo de visión configurables.
- Manzana de prueba generada por código: calles, aceras, bordillos, pasos de cebra, edificios con ventanas instanciadas (MultiMesh), plaza de pruebas de movimiento, árboles, bancas y postes.
- Perfiles de calidad Bajo, Medio y Alto; medidor de rendimiento (F3).
- Menú principal, pausa y panel de configuración.
- 24 pruebas de integración (`tests/test_runner.tscn`) y capturas automáticas (`tests/screenshots.tscn`).
- Exportaciones Web y Windows; publicación de prueba en `/beta-3d/`.

### Cambiado
- La versión 2D completa se movió a `clasico-2d/` sin cambios de código (sus 14 pruebas y el bot de 7 niveles siguen pasando).

### Pendiente (no implementado todavía)
- Modelo y animaciones de Sebastián (Fase 3). El cuerpo actual es provisional.
- Sistema de interacción (E), vehículos (F), inventario (Tab) y mapa (M): las acciones existen internamente, pero no se muestran en el panel de controles hasta que sus funciones estén hechas.
- Guardado de partidas (Fase 9).

## 1.0.0 — Juego 2D

Ver `clasico-2d/README.md` y el historial de Git.
