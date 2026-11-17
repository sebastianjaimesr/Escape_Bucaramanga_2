class_name ChapterStory
extends RefCounted
## Textos de los capítulos 2 a 4: pasos (con sus tres pistas), objetos del
## inventario y diálogos. La lógica está en cada misión (RoboPlazaMission,
## CallejonMission, PersecucionMission); aquí solo hay datos.
##
## "checkpoint": true en un paso = al cumplirlo se guarda un punto de control
## (si te atrapan, vuelves ahí).

const ITEMS := {
	# --- Capítulo 2 ---
	"huella": {"name": "Foto de una huella", "icon": "footprint",
		"text": "Una huella de tenis con suela de cuadros, talla grande, junto al kiosco. Va hacia la plaza."},
	"boton": {"name": "Botón verde", "icon": "button",
		"text": "Un botón verde oliva de chaqueta, arrancado de un tirón. La testigo habló de una chaqueta verde."},
	"tiquete": {"name": "Tiquete de bus", "icon": "ticket",
		"text": "Un tiquete usado de la ruta que sube por la calle norte. Al ladrón se le cayó corriendo."},
	"sobre": {"name": "Sobre de la natillera", "icon": "envelope",
		"text": "El sobre con los ahorros de la natillera del barrio, todavía cerrado. Adentro hay también una nota: «Para A. P. — la bodega del norte»."},
	# --- Capítulo 3 ---
	"foto_guia": {"name": "Foto de la guía de carga", "icon": "camera",
		"text": "Guía de carga sin remitente: «Mercancía de los robos del barrio — entregar a A. P.»."},
	"foto_factura": {"name": "Foto de una factura falsa", "icon": "camera",
		"text": "Una factura de una «fundación» que nunca existió, por obras que nunca se hicieron."},
	"foto_placa": {"name": "Foto de la placa del camión", "icon": "camera",
		"text": "La placa del camión que recoge la mercancía cada jueves en la madrugada."},
	"libro": {"name": "Libro de cuentas", "icon": "book",
		"text": "Pagos a ladrones, a un vigilante y a «un amigo en la estación». Todas las páginas las firma A. Pabón."},
	# --- Capítulo 4 ---
	"impermeable": {"name": "Impermeable de Gordo", "icon": "raincoat",
		"text": "Un impermeable amarillo con capucha. Si te lo pones, la policía deja de reconocerte (baja dos niveles de búsqueda).",
		"use": "disguise"},
	# --- Capítulo 5 ---
	"nota_clave": {"name": "Nota del escritorio", "icon": "doc",
		"text": "Letra de Pabón: «La clave de siempre: el año en que se fundó la ciudad. Lo dice la placa del monumento del parque.»"},
	"contrato": {"name": "Contrato de Inversiones La Meseta", "icon": "envelope",
		"text": "El contrato que une a «El Búho» con Aurelio Pabón y la red de la bodega. Con esto, Lucía puede contarlo todo."},
	# --- Capítulo 6 (2.0) ---
	"mensaje_cigarra": {"name": "Mensaje de La Cigarra", "icon": "doc",
		"text": "«Casillero 27 del Parque de las Cigarras. La clave son cuatro números que dejé pintados junto a mis cigarras: una en el Parque Santander, otra en el García Rovira y otra en la 27. — La Cigarra»"},
	"senal_santander": {"name": "Señal del Parque Santander", "icon": "photo",
		"text": "Una cigarra pintada en el pedestal de la estatua. Debajo: «1.º — ¿Cuántas alas tiene una cigarra?»"},
	"senal_rovira": {"name": "Señal del García Rovira", "icon": "photo",
		"text": "Una cigarra pintada en una banca de la plaza. Debajo: «2.º — ¿Cuántos robos cometió Sebastián?»"},
	"senal_27": {"name": "Señal de la 27", "icon": "photo",
		"text": "Una cigarra pintada en el techo del paradero. Debajo: «3.º y 4.º — El número de esta carrera.»"},
	"grabacion": {"name": "Grabación de La Cigarra", "icon": "usb",
		"text": "Una memoria con una grabación: el «amigo en la estación» del libro de cuentas recibiendo el pago de Pabón. Se le oye decir su nombre: sargento Ordóñez."},
}

const STEPS := {
	"gran_huida": [
		{"id": "periodista", "title": "Encuentra a Lucía, la periodista, en la fuente", "requires": [], "hints": [
			"Lucía te espera en la fuente del centro del Parque de las Palmas.",
			"Sigue el sendero de palmas hacia el centro del parque.",
			"Es la mujer de chaqueta morada junto a la fuente. Acércate y pulsa Interactuar.",
		]},
		{"id": "terrazas", "title": "Sube a las terrazas por la escalera de incendios", "requires": ["periodista"], "checkpoint": true, "hints": [
			"La escalera está al otro lado de la Carrera 33, en el costado sur de los edificios bajos.",
			"Cruza la avenida hacia el este y busca la escalera en la esquina con la calle sur.",
			"Sube la escalera exterior hasta la primera terraza (sigue la columna de luz).",
		]},
		{"id": "oficina", "title": "Cruza las terrazas hasta la oficina de El Búho", "requires": ["terrazas"], "checkpoint": true, "hints": [
			"Ve hacia el norte saltando de terraza en terraza. Los saltos largos se hacen corriendo.",
			"Entre la segunda y la tercera hay una tabla; el salto a la cuarta es el más largo: toma impulso. Si te caes, hay una escalera en ese callejón.",
			"Esquiva la luz del dron (bajo los toldos no te ve) y entra a la caseta de la última terraza por la puerta oeste.",
		]},
		{"id": "caja", "title": "Abre la caja fuerte y saca el contrato", "requires": ["oficina"], "hints": [
			"Sobre el escritorio hay una nota con la pista de la clave.",
			"La clave es el año en que se fundó Bucaramanga; está en la placa del monumento del parque (y en una de las postales).",
			"La clave es 1622.",
		]},
		{"id": "tirolesa", "title": "Escapa por la tirolesa hacia el parque", "requires": ["caja"], "checkpoint": true, "hints": [
			"La tirolesa sale del borde oeste de la última terraza, junto a la oficina.",
			"Párate junto al poste del borde oeste y pulsa Interactuar.",
			"Si te persiguen en la terraza, corre hacia el poste: la tirolesa te deja en el mirador del parque.",
		]},
		{"id": "puente", "title": "Cruza el Puente de la Novena antes del amanecer", "requires": ["tirolesa"], "hints": [
			"El puente está al sur del parque, sobre la cañada. Lucía transmite al otro lado.",
			"Baja del mirador, cruza el parque hacia el sur y la calle sur hasta el puente.",
			"Evita la patrulla del cruce de la calle sur: entra al puente por el andén del parque.",
		]},
	],
	"cigarra": [
		{"id": "lucia", "title": "Habla con Lucía en el Parque Santander", "requires": [], "hints": [
			"Lucía te espera junto a la estatua, en el centro del Parque Santander.",
			"El parque está al noroeste del cruce de la Carrera 27 con la Calle 36. Sigue los senderos hacia la estatua.",
			"Es la mujer de chaqueta morada al pie del pedestal. Acércate y pulsa Interactuar.",
		]},
		{"id": "senal_santander", "title": "Encuentra la señal de La Cigarra en el Parque Santander", "requires": ["lucia"], "hints": [
			"La Cigarra deja sus señales en lugares que todo el mundo ve pero nadie mira.",
			"Mira alrededor del pedestal de la estatua del general Santander.",
			"Rodea el pedestal: la cigarra pintada brilla en el costado norte.",
		]},
		{"id": "senal_rovira", "title": "Encuentra la señal en el Parque García Rovira", "requires": ["lucia"], "hints": [
			"El Parque García Rovira está al sur de la Calle 36, del lado occidental de la 27.",
			"Busca entre las bancas que rodean la estatua de la plaza.",
			"Está en la banca del lado este de la estatua.",
		]},
		{"id": "senal_27", "title": "Encuentra la señal en la Carrera 27", "requires": ["lucia"], "hints": [
			"Sobre la 27, al sur de la Calle 36, hay un paradero de bus.",
			"La señal está en el techo del paradero. Hay que subir.",
			"Sube a la jardinera, luego a la caja de luz verde y de ahí salta al techo del paradero.",
		]},
		{"id": "casillero", "title": "Abre el casillero 27 en el Parque de las Cigarras", "requires": ["senal_santander", "senal_rovira", "senal_27"], "checkpoint": true, "hints": [
			"El kiosco de los casilleros está al fondo del Parque de las Cigarras, en la esquina sureste. La clave son los cuatro números de las señales.",
			"Revisa las señales en el inventario: alas de una cigarra, robos de Sebastián y el número de la carrera.",
			"La clave es 4027.",
		]},
		{"id": "entrega", "title": "Lleva la grabación a Lucía en el Parque García Rovira", "requires": ["casillero"], "hints": [
			"La patrulla de Ordóñez llegó al Centro: escóndete en los matorrales si te ven.",
			"Sal del parque de las Cigarras por el puente de madera o por las piedras de la quebrada y cruza la 27 hacia el oeste.",
			"Lucía y tus amigos esperan al lado de la estatua del García Rovira (sigue la columna de luz).",
		]},
	],
	"robo_plaza": [
		{"id": "testigo", "title": "Habla con Doña Rosa, la testigo", "requires": [], "hints": [
			"Doña Rosa atiende el kiosco junto a la calle, al oeste del punto de inicio.",
			"Es la señora de delantal al lado del kiosco.",
			"Acércate a ella y pulsa Interactuar.",
		]},
		{"id": "pistas", "title": "Investiga la escena: encuentra 3 pistas", "requires": ["testigo"], "hints": [
			"Las pistas brillan en azul y están cerca del kiosco y de la plaza.",
			"Hay una junto al kiosco, otra al pie de las escaleras y otra cerca del carrito de granizados.",
			"Huella: al lado del kiosco. Botón: frente a las escaleras de la plaza. Tiquete: junto a los granizados.",
		]},
		{"id": "sospechoso", "title": "Identifica al ladrón entre la gente de la plaza", "requires": ["pistas"], "checkpoint": true, "hints": [
			"La testigo dijo chaqueta verde y morral naranja. Los dos detalles tienen que coincidir.",
			"Hay gente con chaqueta verde y gente con morral naranja; solo uno tiene las dos cosas.",
			"Busca a quien lleve chaqueta verde Y morral naranja y señálalo con Interactuar.",
		]},
		{"id": "seguir", "title": "Sigue al ladrón sin que te vea", "requires": ["sospechoso"], "checkpoint": true, "hints": [
			"Mantente cerca, pero no demasiado: si se aleja más de 30 m lo pierdes.",
			"Cuando se detenga a mirar atrás, escóndete detrás de algo o agáchate.",
			"Camina agachado a unos 12-20 m y no corras: hace ruido.",
		]},
		{"id": "recuperar", "title": "Recupera el sobre de la natillera", "requires": ["seguir"], "checkpoint": true, "hints": [
			"El ladrón escondió el sobre en una caneca del patio y se quedó vigilando.",
			"Lanza una lata (G) lejos de la caneca: irá a ver qué fue.",
			"Mientras revisa el ruido, acércate a la caneca y saca el sobre.",
		]},
		{"id": "escapar", "title": "Vuelve donde Doña Rosa sin que te atrapen", "requires": ["recuperar"], "hints": [
			"El ladrón gritó y la policía viene: primero piérdela.",
			"Escóndete en un matorral agachado hasta que baje la búsqueda.",
			"Con la búsqueda en Tranquilo o Sospecha, entrégale el sobre a Doña Rosa en el kiosco.",
		]},
	],
	"callejon": [
		{"id": "entrar", "title": "Entra al patio de la bodega", "requires": [], "checkpoint": true, "hints": [
			"El patio de la bodega está detrás de los edificios del noreste.",
			"Hay dos entradas: un callejón angosto desde la calle norte-sur y un paso al fondo de la calle oriental.",
			"El callejón empieza en el andén este de la calle norte, a unos 20 m al norte del cruce.",
		]},
		{"id": "documentos", "title": "Fotografía 3 documentos de la red", "requires": ["entrar"], "hints": [
			"Los documentos brillan en azul: uno en el patio, uno en el camión y uno dentro de la bodega.",
			"La guía de carga está sobre las cajas del patio, la placa en la parte trasera del camión y la factura en la bodega.",
			"Usa las latas (G) para mover a los vigilantes y las sombras de los contenedores para pasar.",
		]},
		{"id": "libro", "title": "Saca el libro de cuentas de la oficina", "requires": ["entrar"], "checkpoint": true, "hints": [
			"La oficina está dentro de la bodega, en la esquina del fondo.",
			"Se entra por la puerta grande del sur o, agachado, por la rejilla del costado oriental.",
			"El libro está sobre el escritorio de la oficina, al noreste dentro de la bodega.",
		]},
		{"id": "salir", "title": "Sal sin que te atrapen y encuéntrate con Buitrago", "requires": ["documentos", "libro"], "hints": [
			"Buitrago te espera en el paradero de bus de la calle oriente-occidente.",
			"Sal por el callejón o por el paso del fondo y cruza al oeste.",
			"El paradero está en el andén norte, al oeste del cruce. Busca la columna de luz.",
		]},
	],
	"persecucion": [
		{"id": "tunel", "title": "Llega al túnel de la plaza", "requires": [], "checkpoint": true, "hints": [
			"Diaz te espera al otro lado del túnel bajo de la plaza, al suroeste.",
			"Cruza la calle hacia el sur y sigue por la plaza hasta el túnel.",
			"El túnel está al sur de las escaleras; entra agachado.",
		]},
		{"id": "perder", "title": "Pierde a la policía (búsqueda en Tranquilo)", "requires": ["tunel"], "hints": [
			"Rompe la línea de vista: ve detrás de los edificios y escóndete.",
			"En un matorral, agachado, la búsqueda baja el doble de rápido.",
			"Quédate escondido hasta que el indicador de búsqueda quede vacío.",
		]},
		{"id": "mochila", "title": "Recoge la mochila que te dejó Gordo", "requires": ["perder"], "checkpoint": true, "hints": [
			"Gordo la dejó en el callejón del sureste, entre los edificios.",
			"El callejón empieza en el andén este de la calle norte-sur, al sur del cruce.",
			"Busca la columna de luz dentro del callejón del sureste.",
		]},
		{"id": "refugio", "title": "Llega al refugio con tus amigos", "requires": ["mochila"], "hints": [
			"Tus amigos te esperan en la zona verde del suroeste.",
			"Si te vuelven a ver, usa el impermeable del inventario para despistarlos.",
			"Llega a la zona verde con la búsqueda en Tranquilo o Sospecha.",
		]},
	],
}

## Capítulo 2: personas de la plaza. Solo una coincide con lo que dijo la testigo.
const SUSPECTS := [
	{"name": "un muchacho de chaqueta verde", "jacket": true, "bag": true, "thief": true},
	{"name": "un señor de chaqueta verde", "jacket": true, "bag": false},
	{"name": "una muchacha de morral naranja", "jacket": false, "bag": true},
	{"name": "un muchacho de gorra azul", "jacket": false, "bag": false},
]

const WITNESS_LINES := [
	"Doña Rosa: «¡Sebas, mijo! Me robaron el sobre de la natillera. Era un muchacho de chaqueta verde con un morral naranja.»",
	"Doña Rosa: «Salió corriendo hacia la plaza. Mire a ver si dejó algo tirado.»",
]


static func steps(chapter_id: String) -> Array:
	return STEPS.get(chapter_id, [])
