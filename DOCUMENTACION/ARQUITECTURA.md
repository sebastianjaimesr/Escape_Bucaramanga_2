# Arquitectura — Escape de Bucaramanga 3D

Estado: aprobada el 3 de noviembre de 2026. Implementado hasta la Fase 2: `src/core` (EventBus, Settings, InputConfig, SceneLoader), `src/player`, `src/camera`, `src/physics`, `src/config` (perfiles de calidad), `src/ui` (menú, pausa, configuración, HUD básico, medidor, carga) y `src/world/prototype` (manzana de prueba).

Adelantos de la versión 0.3.0 (ver sección 8): `src/characters/humanoid_body.gd`, `src/ai/common` (personaje no jugable con navegación), `src/ai/police`, `src/ai/civilians`, `src/interaction` (interactuables, pruebas, escondites), `src/missions/escape_mission.gd`, `src/world/texture_factory.gd`, `src/world/navigation_builder.gd`, `src/world/props` (semáforo, luces de patrulla) y `src/ui` (minimapa, pantallas de la misión). El resto está por construir.

## 1. Tecnología

| Pieza | Elección |
|---|---|
| Motor | Godot 4.7.x estable (versión estándar, no .NET) |
| Lenguaje | GDScript con tipado estático |
| Renderizador PC | Forward+ (Vulkan / Direct3D 12) |
| Renderizador web | Compatibilidad (WebGL 2), exportación sin hilos |
| Física | Jolt Physics (incluido en Godot) |
| Navegación | NavigationServer3D + NavigationAgent3D con evitación RVO |
| Animación | AnimationTree con máquinas de estado y BlendSpaces; esqueleto humanoide común con retargeting |
| Modelado y horneado | Blender (por scripts, reproducible), exportación glTF 2.0 |
| Datos | JSON en `data/` |
| Pruebas | Escenas de prueba headless (`tests/`) + capturas con renderizado por software + bot de recorrido |

## 2. Estructura de carpetas

```
/                         proyecto Godot 3D
├─ project.godot
├─ export_presets.cfg     "Windows Desktop" y "Web"
├─ src/
│  ├─ core/               autoloads: game_state, event_bus, scene_loader, settings, input_config
│  ├─ save/               save_system (espacios, integridad, respaldo, migraciones)
│  ├─ characters/         personaje base, salud y resistencia, animación, apariencia
│  ├─ player/             controlador, estados (idle, walk, run, sprint, jump, fall, crouch,
│  │                      dodge, interact, stairs, vehicle_enter/exit, hurt, celebrate)
│  ├─ camera/             cámara tercera persona (SpringArm3D), cámara de conducción, cinemáticas
│  ├─ physics/            capas de colisión, detección de suelo, ayudas para escaleras y pendientes
│  ├─ ai/
│  │  ├─ common/          percepción (visión, oído), máquina de estados genérica
│  │  ├─ companions/      seguimiento en formación, reagrupar, cubrirse, subir al vehículo
│  │  ├─ police/          patrulla → sospecha → detección → persecución → búsqueda → pérdida → retorno
│  │  └─ civilians/       peatones y tráfico
│  ├─ vehicles/           vehículo por rayos, entrada/salida, IA de conducción, tráfico
│  ├─ missions/           mission_manager, objetivos, disparadores, recompensas
│  ├─ inventory/          inventario, dinero, estadísticas, desbloqueos
│  ├─ dialogue/           sistema de diálogos (reutiliza el formato actual)
│  ├─ world/              zonas, carga por partes, ciclo día/noche, clima, semáforos, señalización
│  ├─ ui/                 menús, HUD, minimapa, mapa, diario, inventario, opciones, pantallas
│  ├─ audio/              buses, música adaptativa, ambiente por zona, efectos 3D
│  └─ config/             perfiles de calidad Bajo / Medio / Alto
├─ scenes/
│  ├─ characters/         sebastian.tscn, companion.tscn, police_officer.tscn, civilian.tscn
│  ├─ vehicles/           car_*.tscn, patrol_car.tscn
│  ├─ world/
│  │  ├─ world.tscn       raíz: jugador, cámara, gestor de zonas, cielo, clima
│  │  └─ zones/           una escena por zona (centro_garcia_rovira.tscn, ...)
│  ├─ props/              farolas, semáforos, señales, bancas, árboles, puestos
│  └─ ui/
├─ assets/
│  ├─ models/             .glb (personajes, vehículos, edificios modulares, props)
│  ├─ animations/         biblioteca de animaciones humanoides
│  ├─ textures/           PBR (albedo, normal, ORM) en resoluciones 1K/2K
│  ├─ audio/              music/, sfx/, ambience/, voice/
│  └─ fonts/
├─ data/
│  ├─ characters.json     nombres configurables de Sebastián y los tres amigos
│  ├─ dialogues/*.json
│  ├─ missions/*.json
│  ├─ items.json
│  └─ zones/*.json        metadatos de cada zona (puntos de interés, rutas, escondites)
├─ tools/
│  ├─ blender/            scripts de modelado, horneado de AO y exportación glTF
│  ├─ osm/                importación de calles desde OpenStreetMap
│  └─ validate_project.py
├─ tests/                 unit/, integration/, bot/, screenshots/
├─ clasico-2d/            versión 2D actual, intacta y jugable (movida con git mv)
├─ DOCUMENTACION/
├─ README.md
└─ CHANGELOG.md
```

## 3. Sistemas y sus responsabilidades

Cada sistema tiene una responsabilidad y se comunica con los demás por señales a través de `EventBus`, nunca leyendo el estado interno de otro.

| Sistema | Responsabilidad | Se comunica con |
|---|---|---|
| `GameState` | Datos de la partida en curso (historia, misiones, inventario, estadísticas) | Todos, solo lectura salvo sus dueños |
| `SaveSystem` | Escribir y leer espacios de guardado | `GameState`, `Settings` |
| `Settings` | Gráficos, audio, controles, accesibilidad | `SaveSystem`, `QualityProfiles`, `AudioManager` |
| `InputConfig` | Acciones y reasignación de teclas | `Settings` |
| `SceneLoader` | Pantalla de carga, carga en segundo plano, errores de carga | `ZoneManager`, menús |
| `ZoneManager` | Cargar/descargar zonas según la posición del jugador | `SceneLoader` |
| `PlayerController` | Movimiento, estados, interacción, entrada a vehículos | Cámara, vehículos, misiones |
| `CompanionAI` | Cada amigo con su propia máquina de estados | Jugador, `HeatSystem`, vehículos |
| `PoliceAI` + `HeatSystem` | Percepción, estados de la policía y nivel de alerta global | HUD, audio, misiones |
| `Vehicle` | Conducción con física, asientos, daños básicos | Jugador, compañeros, IA de tráfico |
| `MissionManager` | Estados de misión, objetivos, recompensas | `GameState`, HUD, diálogos |
| `Inventory` | Objetos, dinero, desbloqueos | `GameState`, HUD |
| `AudioManager` | Buses Música/Efectos/Ambiente/Voces, música de persecución | `HeatSystem`, zonas |
| `DayNight` + `Weather` | Hora del día, luces de calle y locales, lluvia y superficies mojadas | Zonas, `QualityProfiles` |

## 4. Diseño de los sistemas principales

### Personaje y cámara
- `CharacterBody3D` con cápsula, detección de suelo por `is_on_floor()` más un rayo hacia abajo para pendientes y escaleras (subida de escalón).
- Estados separados como en el 2D. La velocidad y la resistencia (sprint) dependen del estado.
- `AnimationTree`: BlendSpace1D para idle/caminar/correr/sprint, estados para salto/caída/aterrizaje, capa superior para interactuar.
- Cámara: `SpringArm3D` (evita atravesar paredes), suavizado, sensibilidad e inversión configurables. Cámara de conducción propia.

### Compañeros (los tres amigos)
- Cada uno es una instancia de `companion.tscn` con su propia máquina de estados: `Follow`, `Wait`, `Regroup`, `Alert`, `TakeCover`, `EnterVehicle`, `InVehicle`, `MissionTask`, `CatchUp`.
- Formación: cada amigo tiene un punto relativo a Sebastián (izquierda, derecha, atrás) que se proyecta sobre la navmesh. Así no se amontonan en el mismo punto.
- `NavigationAgent3D` con evitación entre ellos y con peatones.
- Si quedan a más de cierta distancia o atascados varios segundos: corren; si no es posible, reaparecen fuera de la vista de la cámara cerca del jugador (`CatchUp`).
- Nombres, colores y modelos desde `data/characters.json`.

### Policía
- Percepción con cono de visión, distancia y rayo de línea de vista (los edificios bloquean), más oído (sprint, choques).
- Estados: `Patrol → Suspicious → Detected → Chase → Search → Lost → ReturnToPatrol`.
- La policía solo conoce la **última posición vista**. En `Search` revisa esa zona y puntos cercanos de la navmesh; los escondites (`HidingSpot`) reducen la visibilidad.
- `HeatSystem` lleva el nivel de alerta (0 a 3), que muestra el HUD y que decide cuántas patrullas participan.
- Sin armas ni violencia: ser atrapado es una condición de fallo de la misión.

### Vehículos
- Vehículo por rayos (suspensión, tracción, derrape) sobre `RigidBody3D`, que da más control que `VehicleBody3D`. Se evaluarán los dos en la Fase 7 y se documentará la elección.
- Asientos con nodos marcadores; los compañeros ocupan los libres al entrar Sebastián.
- Solo los vehículos con el componente `Drivable` se presentan como interactivos.

### Misiones
Formato de datos (`data/missions/m01_*.json`):

```json
{
  "id": "M01",
  "name": "La noche del malentendido",
  "type": "main",
  "description": "...",
  "location": "centro_garcia_rovira",
  "start_conditions": [{"type": "story_flag", "flag": "intro_done"}],
  "objectives": [
    {"id": "meet_friends", "type": "reach_area", "area": "parque_garcia_rovira", "text": "..."},
    {"id": "escape", "type": "lose_police", "text": "..."}
  ],
  "fail_conditions": [{"type": "caught_by_police"}],
  "rewards": {"money": 20000, "items": ["..."], "unlocks": ["M02"]},
  "save_on_complete": true
}
```

Estados: `locked → available → active → completed` o `failed` (con reintento desde el último punto de control de la misión).

### Guardado
- **3 espacios manuales + 1 automático.** Cada archivo guarda: posición, zona, historia, misiones, inventario, dinero, estadísticas y versión.
- **Integridad:** cada archivo incluye una suma SHA-256 del contenido. Al cargar, si no coincide, se usa la copia de respaldo `.bak` y se avisa al jugador. Si las dos están dañadas, el espacio se muestra como "dañado" y no se sobrescribe sin confirmación.
- **Escritura segura:** se escribe a un archivo temporal y luego se reemplaza.
- **Migraciones:** el campo `version` se usa para actualizar guardados antiguos.
- **PC:** `user://` (en Windows, `%APPDATA%\Escape de Bucaramanga\`).
- **Navegador:** `user://` se guarda en IndexedDB. Limitaciones: se pierde si el usuario borra los datos del sitio, en ventanas privadas y, en algunos navegadores, si el almacenamiento se libera por falta de espacio. Se pedirá almacenamiento persistente al navegador y se ofrecerá **exportar e importar la partida** como archivo.
- La suma de integridad detecta daños, **no impide** que alguien edite su propio guardado.

### Calidad gráfica

| Ajuste | Bajo (web) | Medio | Alto (PC) |
|---|---|---|---|
| Renderizador | Compatibilidad | Compatibilidad o Forward+ | Forward+ |
| Sombras | 1 luz, 1.024 px, distancia 30 m | 2.048 px, 60 m | 4.096 px, 4 cascadas, 100 m |
| Distancia de dibujo | 150 m | 300 m | 500 m |
| Escala de resolución | 0,75 | 1,0 | 1,0 |
| Antialiasing | FXAA | MSAA 2× | MSAA 4× o TAA |
| SSAO / SSR / niebla volumétrica | No (AO horneado) | No | Sí |
| Partículas de lluvia | 25 % | 60 % | 100 % |
| Densidad de peatones y tráfico | Baja | Media | Alta |

## 5. Construcción de la ciudad

- **Calles:** trazado basado en datos de OpenStreetMap (licencia ODbL; se cita en créditos). Se convierte en una red de calles, aceras e intersecciones con `tools/osm/`.
- **Edificios:** kit modular propio (fachadas, balcones, rejas, locales, techos, avisos) hecho en Blender por script, con variaciones de color, altura, alero y ventanas para que no se repita. Usa instancing (MultiMesh) donde se pueda.
- **Lugares emblemáticos:** se modelan como versiones **inspiradas** en los reales, con referencias de fotografías públicas. No se presentan como reproducciones exactas.
- **Zonas:** cada zona es una escena con su navmesh, rutas de policía, escondites, rutas de tráfico y puntos de misión. Se pueden añadir zonas nuevas sin tocar las anteriores.

## 6. Recursos y licencias

Solo se usan recursos propios o con licencias que permitan distribuirlos dentro de un repositorio público. Cada recurso se registra en `DOCUMENTACION/RECURSOS_Y_LICENCIAS.md` con su fuente, autor y licencia **verificada en el momento de descargarlo**.

| Necesidad | Fuente prevista | Licencia esperada |
|---|---|---|
| Cuerpos humanos realistas | MPFB / MakeHuman para Blender | CC0 para los modelos exportados (a verificar) |
| Animaciones humanoides | Quaternius (Universal Animation Library) | CC0 (a verificar) |
| Texturas PBR | Poly Haven, ambientCG | CC0 |
| Cielos HDRI | Poly Haven | CC0 |
| Edificios, vehículos, props | Modelos propios por script en Blender; complementos CC0 | Propios / CC0 |
| Sonidos | Freesound (solo CC0), generados por script | CC0 / propios |
| Música | Composición propia generada | Propia |
| Calles | OpenStreetMap | ODbL (atribución obligatoria) |

Mixamo **no** se usará salvo que lo decidas: su licencia permite usarlo en juegos, pero no redistribuir los archivos sueltos, y el repositorio es público.

## 7. Pruebas

| Tipo | Qué cubre | Dónde corre |
|---|---|---|
| Unitarias | Guardado e integridad, misiones, inventario, percepción, máquinas de estado | Headless aquí |
| Integración | Jugador sobre la zona real, compañeros siguiendo, policía detectando y perdiendo, vehículo | Headless aquí |
| Bot | Completar la misión principal de principio a fin | Headless aquí |
| Capturas | Imagen de cada zona y pantalla en los dos renderizadores | Renderizado por software aquí |
| Web | Que la exportación cargue en Chromium sin errores en consola | Navegador headless aquí |
| Rendimiento | FPS y tiempo de cuadro en un recorrido fijo, por perfil | **Tu PC** (no hay GPU en este entorno) |


## 8. Lo implementado en la versión 0.3.0

| Pieza | Archivo | Notas |
|---|---|---|
| Cuerpo humano de primitivas | `src/characters/humanoid_body.gd` | Paleta y accesorios por personaje; lo usan Sebastián (`PrototypeBody`), la policía y los civiles. Se reemplaza en la Fase 3. |
| Personaje no jugable | `src/ai/common/npc_character.gd` | `CharacterBody3D` + `NavigationAgent3D`, sube bordillos, gira y anima. |
| Policía | `src/ai/police/police_officer.gd` | Estados `PATROL → SUSPICIOUS → CHASE → SEARCH → RETURN`. Percepción: cono, distancia, rayo de línea de vista, oído al correr. Aviso por radio con `EventBus.police_radio`. Todavía no hay `HeatSystem` ni patrulla en vehículo (Fase 6 completa). |
| Civiles | `src/ai/civilians/civilian.gd` | Peatones que pasean, vendedor y amigos; se habla con E. |
| Interacción | `src/interaction/` | `Interactable` (Area3D en la capa `interactuables`), `EvidencePickup`, `HidingSpot`. El jugador elige el más cercano. |
| Misión | `src/missions/escape_mission.gd` | Coloca personajes y pruebas, cuenta pruebas, maneja atrapado/victoria. Las misiones de datos (`data/missions/*.json`) llegan en la Fase 8. |
| Navmesh | `src/world/navigation_builder.gd` | Se hornea al cargar desde las colisiones estáticas (mundo y carros). |
| Texturas procedurales | `src/world/texture_factory.gd` | Color + normales generados al iniciar; se reemplazan por texturas CC0 en la Fase 5. |
| HUD | `src/ui/hud.gd`, `minimap.gd`, `mission_overlay.gd` | Objetivo, alerta, escondido, avisos, minimapa, pantallas de atrapado y victoria. |
