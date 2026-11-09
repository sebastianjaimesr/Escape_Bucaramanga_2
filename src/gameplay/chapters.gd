class_name Chapters
extends RefCounted
## Datos de la campaña: capítulos, niveles, habilidades, tienda, logros y
## postales coleccionables. Solo datos (para revisarlos y traducirlos en un
## solo lugar); la lógica está en PlayerProfile y en cada misión.

const FIRST := "malentendido"
## XP por cada objetivo cumplido.
const STEP_XP := 50
## Rangos al terminar un capítulo (de mejor a peor).
const RANKS := ["Detective impecable", "Buen ojo", "Salvado por los amigos"]

## Capítulos en orden. "time" = hora del día (TimeOfDay), "rain" = lluvia.
## Cada uno se desbloquea al terminar el anterior.
const LIST := [
	{
		"id": "malentendido", "number": 1, "title": "Las pruebas del malentendido",
		"win_title": "¡Malentendido aclarado!",
		"place": "La manzana de la plaza", "time": "tarde", "rain": false,
		"xp": 600, "money": 150, "lives": -1,
		"summary": "La policía te confunde con un ladrón. Reúne pruebas, abre lo que está cerrado y aclara lo que pasó a las 17:42.",
		"tags": ["Acertijos", "Exploración", "Sigilo"],
		"pedestrians": [
			["¡Uy, qué calor tan berraco!", "Por la carrera vi pasar a un policía hace ratico.", "Dicen que el ladrón tenía una gorra roja."],
			["Los granizados del parque son los mejores.", "Si lo persiguen, métase entre los matorrales y agáchese.", "En el túnel de la plaza hay una cámara de seguridad."],
			["¿Usted no es el muchacho de las noticias?", "La policía no ve bien si uno va agachadito.", "Arriba de las escaleras de la plaza vi algo brillando."],
			["Ojo con correr cerca de los tombos, que lo oyen.", "Al fondo de la calle, por el lado oriental, alguien dejó un celular.", "¡Qué pena, voy de afán!"],
		],
	},
	{
		"id": "robo_plaza", "number": 2, "title": "El robo de la plaza",
		"win_title": "¡La natillera está a salvo!",
		"outro": "Doña Rosa recuperó los ahorros del barrio. Pero la nota del sobre decía «Para A. P. — la bodega del norte»: el ladrón no trabajaba solo.",
		"place": "Centro · la tienda de Doña Rosa", "time": "manana", "rain": false,
		"xp": 800, "money": 200, "lives": 3,
		"summary": "Se robaron el sobre de la natillera del barrio. Habla con la testigo, encuentra pistas, identifica al ladrón y síguelo sin que te vea.",
		"tags": ["Investigación", "Seguimiento", "Escape"],
		"pedestrians": [
			["¡Pobre Doña Rosa! Esa plata era de todo el barrio.", "Yo vi a un muchacho salir corriendo hacia la plaza."],
			["Dicen que el ladrón tiene una chaqueta verde.", "La policía anda patrullando más que nunca."],
			["Si va a seguir a alguien, no se le pegue tanto.", "Los ladrones siempre miran para atrás."],
			["Una lata tirada lejos distrae a cualquiera.", "Por los callejones entre los edificios se llega a los patios de atrás."],
		],
	},
	{
		"id": "callejon", "number": 3, "title": "Sombras en el callejón",
		"win_title": "¡Tienes el libro de cuentas!",
		"outro": "Fotos de la guía de carga, de la factura falsa y de la placa del camión, y un libro firmado por A. Pabón. Pero alguien vio a Sebastián salir de la bodega…",
		"place": "Patio de la bodega de la calle norte", "time": "noche", "rain": false,
		"xp": 1000, "money": 250, "lives": 3,
		"summary": "El ladrón trabajaba para alguien. De noche, entra a la bodega, fotografía los documentos y sácale el libro de cuentas a la red.",
		"tags": ["Infiltración", "Cámaras", "Distracciones"],
		"pedestrians": [
			["A esta hora es mejor no andar solo.", "Esa bodega de la calle norte nunca tiene el letrero prendido."],
			["Los vigilantes de la bodega hacen siempre la misma ronda.", "Las cámaras giran despacio; hay que esperar el momento."],
			["Por el callejón entre los edificios se llega al patio.", "Dicen que hay una rejilla por donde cabe una persona agachada."],
			["¡Qué noche tan fresca!", "Yo no me meto en problemas, mijo."],
		],
	},
	{
		"id": "persecucion", "number": 4, "title": "Persecución urbana",
		"win_title": "¡A salvo bajo la lluvia!",
		"outro": "En el refugio, los cuatro amigos leen la última página del libro: «Todo se le reporta a El Búho». ¿Quién es El Búho? Una periodista quiere saberlo también…",
		"place": "Toda la manzana, bajo la lluvia", "time": "noche", "rain": true,
		"xp": 1200, "money": 300, "lives": 3,
		"summary": "Alguien de la red avisó a la policía. Con el libro de cuentas en la mochila, cruza la ciudad bajo la lluvia, pierde a las patrullas y llega al refugio.",
		"tags": ["Persecución", "Alerta máxima", "Puntos de control"],
		"pedestrians": [
			["¡Corra, mijo, que vienen!", "Métase al túnel de la plaza, ahí no lo ven."],
			["Con este aguacero nadie ve nada.", "Las patrullas están cerrando las esquinas."],
			["Si se cambia de chaqueta, a lo mejor no lo reconocen.", "Escóndase y espere a que pasen."],
			["¡Qué aguacero tan verraco!", "Yo no he visto nada, yo no he visto nada."],
		],
	},
	{
		"id": "gran_huida", "number": 5, "title": "La gran huida",
		"win_title": "¡En vivo desde el Puente de la Novena!",
		"outro": "Al amanecer, Lucía Rangel transmitió en vivo: El Búho era Aurelio Pabón, dueño de Inversiones La Meseta. Con el contrato, el libro y las fotos, el caso quedó en manos de la Fiscalía. Sebastián, por fin, ya no es sospechoso de nada.",
		"place": "Cabecera · Parque de las Palmas", "map": "cabecera", "time": "madrugada", "rain": false,
		"xp": 1500, "money": 400, "lives": 3,
		"summary": "Una periodista puede contar toda la verdad al amanecer. Sube a las terrazas de Cabecera, saca el contrato de la oficina de El Búho y huye hasta el Puente de la Novena antes de que salga el sol.",
		"tags": ["Parkour", "Drones", "Huida final"],
		"pedestrians": [
			["¿Usted qué hace despierto a esta hora, mijo?", "Dicen que por las terrazas se cruza toda la cuadra."],
			["Esos drones nuevos alumbran todo el parque.", "Debajo de un toldo no lo ven desde arriba."],
			["En la placa del monumento está el año en que se fundó la ciudad.", "Yo madrugo a trotar por el parque, ¡qué fresquito!"],
			["Si cae de muy alto, ruede al caer, como los muchachos del parkour.", "Por la tirolesa del mirador se baja volando."],
		],
	},
]

## Lo que se ve en la selección de capítulos después del último.
const NEXT_TEASER := "Fin de la primera temporada. Repite capítulos para mejorar tus rangos y busca las 15 postales."

## Buitrago, Diaz y Gordo: [nombre, apariencia, posición relativa al punto de encuentro].
const FRIENDS := [
	["Buitrago", {"skin": Color(0.6, 0.42, 0.3), "shirt": Color(0.95, 0.75, 0.15), "sleeves": false,
			"pants": Color(0.15, 0.15, 0.17), "shoes": Color(0.1, 0.1, 0.1)}, Vector3(-0.9, 0, 0)],
	["Diaz", {"skin": Color(0.93, 0.8, 0.72), "shirt": Color(0.15, 0.35, 0.7), "sleeves": false,
			"pants": Color(0.55, 0.5, 0.42), "height": 1.1, "hair": Color(0.3, 0.2, 0.1)}, Vector3(0.9, 0, 0.2)],
	["Gordo", {"skin": Color(0.7, 0.5, 0.38), "shirt": Color(0.2, 0.55, 0.3), "sleeves": false,
			"pants": Color(0.25, 0.3, 0.45), "girth": 1.35, "cap": Color(0.75, 0.1, 0.1)}, Vector3(0, 0, -0.9)],
]

## Niveles: XP total necesaria y nombre. Cada nivel nuevo da 1 punto de habilidad.
const LEVELS := [
	[0, "Novato"], [300, "Explorador"], [800, "Investigador"], [1500, "Infiltrado"],
	[2500, "Experto urbano"], [3800, "Especialista"], [5500, "Maestro del sigilo"],
	[7500, "Leyenda del barrio"], [10000, "Sombra urbana"], [13000, "Leyenda de la ciudad"],
]

## Habilidades: se compran con puntos de habilidad desde el nivel indicado.
const SKILLS := {
	"paso_ligero": {"name": "Paso ligero", "level": 2, "icon": "shoe",
		"text": "Correr hace menos ruido: la policía te oye a la mitad de distancia."},
	"pulmones": {"name": "Pulmones de acero", "level": 2, "icon": "lungs",
		"text": "40 % más de resistencia para correr."},
	"parkour": {"name": "Parkour", "level": 3, "icon": "climb",
		"text": "Escalas muros de hasta 1,9 m (sin la habilidad, hasta 1,3 m)."},
	"buen_brazo": {"name": "Buen brazo", "level": 3, "icon": "can",
		"text": "Lanzas las latas más lejos y llevas 2 más en cada capítulo."},
	"sombra": {"name": "Sombra", "level": 4, "icon": "eye",
		"text": "La policía, los vigilantes y las cámaras te ven desde un 25 % menos de distancia."},
	"escapista": {"name": "Escapista", "level": 5, "icon": "run",
		"text": "El nivel de búsqueda baja el doble de rápido cuando no te ven."},
}

## Tienda de Doña Rosa: cada objeto tiene un efecto real en el juego.
const SHOP := {
	"tenis": {"name": "Tenis silenciosos", "price": 150, "icon": "shoe",
		"text": "Al correr haces 30 % menos ruido."},
	"latas": {"name": "Bolsa de latas", "price": 100, "icon": "can",
		"text": "Empiezas cada capítulo con 3 latas más para distraer."},
	"termo": {"name": "Termo de granizado", "price": 120, "icon": "cup",
		"text": "Empiezas cada capítulo con 20 s de resistencia sin límite."},
	"chaqueta": {"name": "Chaqueta reversible", "price": 250, "icon": "jacket",
		"text": "Una vez por capítulo, cámbiate de chaqueta (Q) para bajar dos niveles de búsqueda."},
}

## Logros: XP y dinero que dan al conseguirlos.
const ACHIEVEMENTS := {
	"caso_cerrado": {"name": "Caso cerrado", "text": "Termina el capítulo 1.", "xp": 100},
	"natillera": {"name": "La natillera está a salvo", "text": "Termina el capítulo 2.", "xp": 100},
	"sombra_noche": {"name": "Sombra en la noche", "text": "Termina el capítulo 3.", "xp": 100},
	"a_salvo": {"name": "A salvo bajo la lluvia", "text": "Termina el capítulo 4.", "xp": 150},
	"fantasma": {"name": "Fantasma", "text": "Termina un capítulo sin que nadie te persiga.", "xp": 200},
	"impecable": {"name": "Impecable", "text": "Termina un capítulo con el rango «Detective impecable».", "xp": 150},
	"postales_5": {"name": "Turista", "text": "Encuentra 5 postales de Bucaramanga.", "xp": 100},
	"postales_10": {"name": "Ciudad de los Parques", "text": "Encuentra las 10 postales.", "xp": 300},
	"distraccion": {"name": "¿Qué fue ese ruido?", "text": "Distrae a un policía o vigilante con una lata.", "xp": 50},
	"escapista": {"name": "Escurridizo", "text": "Baja una búsqueda de nivel 3 o más hasta cero.", "xp": 150},
	"nivel_5": {"name": "Experto urbano", "text": "Llega al nivel 5.", "xp": 0},
	"cliente": {"name": "Cliente de Doña Rosa", "text": "Compra algo en la tienda.", "xp": 50},
	"gran_huida": {"name": "La gran huida", "text": "Termina el capítulo 5.", "xp": 200},
	"rey_terrazas": {"name": "Rey de las terrazas", "text": "Cruza de la escalera a la oficina de El Búho en menos de 75 s sin bajar a la calle.", "xp": 200},
	"acrobata": {"name": "Acróbata", "text": "Rueda 10 veces al caer de alto (Agacharse al aterrizar).", "xp": 100},
	"postales_15": {"name": "Bumangués de corazón", "text": "Encuentra las 15 postales.", "xp": 400},
}

## Postales coleccionables: 50 XP y $20 cada una; cada 5, un punto de habilidad.
const COLLECTIBLES := [
	{"id": "parques", "name": "La Ciudad de los Parques", "position": Vector3(-46.0, 0.15, 46.5),
		"fact": "A Bucaramanga le dicen la Ciudad de los Parques por la cantidad de parques que tiene."},
	{"id": "bonita", "name": "La Ciudad Bonita", "position": Vector3(-28.5, 1.51, 24.5),
		"fact": "Otro apodo de Bucaramanga es «la Ciudad Bonita de Colombia»."},
	{"id": "hormigas", "name": "Hormigas culonas", "position": Vector3(-16.0, 0.75, 31.0),
		"fact": "Las hormigas culonas tostadas son un antojo típico de Santander."},
	{"id": "chicamocha", "name": "El Cañón del Chicamocha", "position": Vector3(54.0, 0.15, -54.0),
		"fact": "El Cañón del Chicamocha queda a poco más de una hora de la ciudad."},
	{"id": "fundacion", "name": "Fundada en 1622", "position": Vector3(-52.0, 0.15, -50.0),
		"fact": "Bucaramanga se fundó en 1622."},
	{"id": "meseta", "name": "La meseta", "position": Vector3(52.0, 0.15, 52.0),
		"fact": "La ciudad está sobre una meseta, a unos 960 m sobre el nivel del mar."},
	{"id": "bocadillo", "name": "Bocadillo veleño", "position": Vector3(-36.0, 0.15, -7.4),
		"fact": "El bocadillo veleño, de guayaba, viene de Vélez, en Santander."},
	{"id": "leopardo", "name": "El Leopardo", "position": Vector3(6.6, 0.15, -56.0),
		"fact": "Al Atlético Bucaramanga, el equipo de fútbol de la ciudad, le dicen el Leopardo."},
	{"id": "cafe", "name": "Café de la Mesa", "position": Vector3(57.0, 0.15, -6.6),
		"fact": "La Mesa de los Santos, cerca de la ciudad, es famosa por su café."},
	{"id": "agua", "name": "El Parque del Agua", "position": Vector3(-6.6, 0.15, 57.0),
		"fact": "El Parque del Agua es uno de los parques más visitados de la ciudad."},
	# --- Cabecera (capítulo 5) ---
	{"id": "capital", "name": "Capital de Santander", "map": "cabecera", "position": Vector3(-23.0, 2.6, -25.0),
		"fact": "Bucaramanga es la capital del departamento de Santander."},
	{"id": "garcia_rovira", "name": "Parque García Rovira", "map": "cabecera", "position": Vector3(-58.0, 0.15, -4.0),
		"fact": "En el Parque García Rovira, en el centro, empezó la ciudad."},
	{"id": "santisimo", "name": "El Santísimo", "map": "cabecera", "position": Vector3(24.0, 7.82, 9.5),
		"fact": "En el Cerro del Santísimo, en Floridablanca, una estatua gigante mira sobre toda el área metropolitana."},
	{"id": "casa_bolivar", "name": "Casa de Bolívar", "map": "cabecera", "position": Vector3(-44.0, 0.15, 66.0),
		"fact": "En el centro está la Casa de Bolívar, una casona colonial donde se alojó Simón Bolívar en 1828; hoy es museo."},
	{"id": "estadio", "name": "El Alfonso López", "map": "cabecera", "position": Vector3(30.5, 0.15, -19.5),
		"fact": "El estadio Alfonso López es la casa del Atlético Bucaramanga."},
]


static func get_chapter(id: String) -> Dictionary:
	for c: Dictionary in LIST:
		if c["id"] == id:
			return c
	return {}


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return -1


## El capítulo siguiente o "" si es el último.
static func next_id(id: String) -> String:
	var i := index_of(id)
	return LIST[i + 1]["id"] if i >= 0 and i + 1 < LIST.size() else ""


static func level_for_xp(xp: int) -> int:
	var level := 1
	for i in LEVELS.size():
		if xp >= int(LEVELS[i][0]):
			level = i + 1
	return level


static func level_name(level: int) -> String:
	return LEVELS[clampi(level, 1, LEVELS.size()) - 1][1]


## XP total para llegar a un nivel (el 11 no existe: devuelve la del 10).
static func level_xp(level: int) -> int:
	return int(LEVELS[clampi(level, 1, LEVELS.size()) - 1][0])


## Crea la misión del capítulo (el primero si el id no existe).
static func create_mission(id: String, world: PrototypeWorld) -> Mission:
	match id:
		"robo_plaza":
			return RoboPlazaMission.new(world)
		"callejon":
			return CallejonMission.new(world)
		"persecucion":
			return PersecucionMission.new(world)
		"gran_huida":
			return GranHuidaMission.new(world)
	return EscapeMission.new(world)
