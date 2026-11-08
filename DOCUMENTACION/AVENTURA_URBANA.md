# Aventura urbana (versión 0.5.0)

Escape de Bucaramanga deja de ser un solo escape room y pasa a ser una aventura en capítulos sobre la misma manzana, con progresión que se conserva entre ellos. Se mantienen el nombre, Sebastián, Buitrago, Diaz y Gordo, la policía ficticia y no violenta, y el capítulo 1 tal como era.

## La campaña

| # | Capítulo | Hora | Qué se hace | Corazones |
|---|---|---|---|---|
| 1 | Las pruebas del malentendido | Atardecer | El escape room de la 0.4: 7 objetivos, 3 acertijos, modo libre o contrarreloj | Sin límite |
| 2 | El robo de la plaza | Mañana | Hablar con Doña Rosa, buscar 3 pistas, identificar al ladrón entre 4 personas (chaqueta verde **y** morral naranja), seguirlo sin que te vea, sacarle el sobre de la natillera con una lata de distracción y volver sin que te atrape la policía | 3 |
| 3 | Sombras en el callejón | Noche | Entrar al patio de la bodega del norte, fotografiar 3 documentos, sacar el libro de cuentas de la oficina (por la puerta o, agachado, por la rejilla) y encontrarse con Buitrago en el paradero. Tres vigilantes y dos cámaras | 3 |
| 4 | Persecución urbana | Noche con lluvia | Empezar en Persecución, llegar al túnel, perder a la policía, recoger la mochila de Gordo (con un impermeable que sirve de disfraz) y llegar al refugio | 3 |

Cada capítulo se desbloquea al terminar el anterior. El final del 4 deja abierta la pregunta por «El Búho» y la portada anuncia el capítulo 5.

Los textos de los capítulos 2 a 4 (pasos con sus tres pistas, objetos, sospechosos, frases) están en `src/gameplay/chapter_story.gd`; los datos de la campaña (capítulos, niveles, habilidades, tienda, logros, postales) en `src/gameplay/chapters.gd`.

## Sistemas nuevos

| Sistema | Archivo | Qué hace |
|---|---|---|
| Base de misiones | `src/missions/mission.gd` | Reloj, pasos y pistas, inventario, corazones y puntos de control, policía, escondites, vendedor, peatones, postales, disfraz, guardado y recompensas. Cada capítulo es una subclase (`EscapeMission`, `RoboPlazaMission`, `CallejonMission`, `PersecucionMission`). La interfaz solo conoce `Mission`. |
| Perfil | `src/gameplay/player_profile.gd` (autoload) | Nivel y XP (10 niveles), dinero, reputación, puntos y habilidades, objetos comprados, logros, postales y récords por capítulo. Se guarda aparte de la partida, en `user://perfil.cfg`, con escritura atómica; si se daña se aparta como `.bad`. |
| Búsqueda | `src/gameplay/wanted_system.gd` | «Calor» de 0 a 100 en cinco niveles: Tranquilo, Sospecha, Búsqueda, Persecución y Cerco. Sube con la policía, las cámaras y los avisos; baja cuando nadie te ve (más rápido escondido). Desde Persecución llegan hasta dos refuerzos. |
| Latas | `src/interaction/thrown_can.gd` | G lanza una lata; al caer hace ruido y la policía, los vigilantes y el ladrón cercanos van a mirar. |
| Cámaras de seguridad | `src/ai/security_camera.gd` | Barren de lado a lado con un cono visible; si te ven 1,1 s seguidos suena la alarma. |
| Movimiento | `src/player/states/vault_state.gd`, `slide_state.gd` | Trepar muros de hasta 1,3 m (1,9 m con Parkour) saltando contra ellos; deslizarse agachándose al correr. Aterrizajes con polvo y sonido. |
| Hora del día | `src/world/time_of_day.gd`, `rain_fx.gd` | Mañana, tarde y noche (faroles encendidos), lluvia con partículas y sonido. |
| Bodega | `src/world/prototype/bodega_builder.gd` | Galpón con puerta, rejilla y oficina, camión, contenedores y cajas en el patio noreste. |
| Vigilantes y sospechosos | `src/ai/police/guard.gd`, `src/ai/civilians/suspect.gd` | El vigilante usa la IA de la policía con otro uniforme y menos vista. El sospechoso camina, mira hacia atrás, vigila y se distrae. |

## Progresión

- **XP**: 50 por objetivo, la recompensa del capítulo (600 a 1200), bonos sin pistas (+100), sin que te atraparan (+150) y sin persecución (+200), postales (+50) y logros. Repetir un capítulo paga el 25 %.
- **Niveles**: Novato, Explorador, Investigador, Infiltrado, Experto urbano, Especialista, Maestro del sigilo, Leyenda del barrio, Sombra urbana y Leyenda de la ciudad (de 0 a 13 000 XP). Cada nivel da un punto de habilidad (y cada cinco postales, otro).
- **Habilidades**: Paso ligero (te oyen a la mitad), Pulmones de acero (+40 % de resistencia), Parkour (trepar más alto), Buen brazo (latas más lejos y 2 más), Sombra (te ven un 25 % menos lejos) y Escapista (la búsqueda baja el doble de rápido).
- **Tienda**: tenis silenciosos, bolsa de latas, termo de granizado y chaqueta reversible (disfraz una vez por capítulo).
- **Logros**: 12, entre ellos uno por capítulo, «Fantasma» (sin persecución), «Impecable», «¿Qué fue ese ruido?» (distraer con una lata), «Escurridizo» (bajar una Persecución a cero), «Turista» y «Ciudad de los Parques» (5 y 10 postales).
- **Postales**: 10 escondidas en la manzana, cada una con un dato de Bucaramanga.

## Interfaz

- Portada con la campaña a la derecha, botones de Jugar, Continuar, Perfil y habilidades, Tienda, Logros, Cómo se juega y Configuración.
- Selección de capítulo con lugar, hora, etiquetas, mejor tiempo y rango; los bloqueados dicen qué falta.
- HUD: corazones, latas, cuadritos de búsqueda con su nombre, barra especial del capítulo (distancia al ladrón), nivel, XP y dinero abajo a la derecha, «+XP» flotante, aviso de nivel nuevo y de logros, aviso de punto de control.
- Victoria con el detalle de las recompensas y «Siguiente capítulo»; derrota por corazones con «Reintentar».
- Pausa con Perfil, habilidades y tienda; «Volver al punto de control»; «Reiniciar el capítulo».
- Controles táctiles con botones Lata y Disfraz.

## Recursos

No se agregó ningún recurso de terceros. La geometría, las texturas y los íconos se generan en código; los 13 sonidos nuevos y la lluvia se sintetizan con `tools/generate_audio.py`.
