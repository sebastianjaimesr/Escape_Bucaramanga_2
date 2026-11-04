# Cambios

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
