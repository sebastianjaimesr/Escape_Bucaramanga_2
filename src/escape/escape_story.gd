class_name EscapeStory
extends RefCounted
## Datos de la historia del escape room «Las pruebas del malentendido».
##
## Todo lo que el jugador necesita para resolver los acertijos está en estos
## textos: la hora del robo sale de la foto, la coartada del recibo, el patrón
## del celular de lo que dice Diaz, y la reconstrucción final de las pruebas.
## La lógica vive en EscapeMission; aquí solo hay datos para poder revisarlos
## (y traducirlos) en un solo lugar.

## Hora del robo: aparece en la foto y en el video. Es la clave de la caja (HHMM).
const ROBBERY_TIME := "17:42"
const CAMERA_CODE := "1742"
## Patrón del celular de Diaz: una Z en la cuadrícula 3×3 (puntos 1 a 9).
const PHONE_PATTERN := [1, 2, 3, 5, 7, 8, 9]

const TIME_LIMIT_SECONDS := 15 * 60
const WRONG_ANSWER_PENALTY := 30.0

## Modos de juego. "time_limit" = 0 significa sin límite.
const MODES := {
	"explorador": {"label": "Explorador", "time_limit": 0,
		"description": "Sin límite de tiempo. Para recorrer la manzana con calma."},
	"contrarreloj": {"label": "Contrarreloj", "time_limit": TIME_LIMIT_SECONDS,
		"description": "15 minutos. Cada respuesta equivocada en la reconstrucción resta 30 s."},
}

## Objetos del inventario: nombre, texto al inspeccionarlo e icono (ItemIcon).
const ITEMS := {
	"foto": {
		"name": "Foto borrosa del robo",
		"icon": "photo",
		"text": "La tomó un vecino desde lo alto de la plaza. En la esquina se lee la hora: 17:42. Se ve a alguien con gorra roja que corre hacia el túnel.",
	},
	"recibo": {
		"name": "Tu recibo de la tienda",
		"icon": "receipt",
		"text": "Tienda Doña Rosa · 2 gaseosas y un paquete de papas · 17:42. Se te voló del bolsillo mientras corrías. A la hora del robo tú estabas pagando: es tu coartada.",
	},
	"usb": {
		"name": "Memoria USB con el video",
		"icon": "usb",
		"text": "El video de la cámara del túnel, a las 17:42: el ladrón pasa agachado, con gorra roja. Detrás viene Diaz grabando con su celular… y se le cae.",
	},
	"celular_bloqueado": {
		"name": "Celular de Diaz (bloqueado)",
		"icon": "phone_locked",
		"text": "Tiene la pantalla rota y pide un patrón de desbloqueo. Diaz sabe cuál es.",
		"use": "phone",
	},
	"celular": {
		"name": "Celular de Diaz",
		"icon": "phone",
		"text": "En la galería hay un video de Diaz: el ladrón se quita la gorra roja y la tira en una caneca al fondo de la calle norte.",
	},
	"gorra": {
		"name": "Gorra roja del ladrón",
		"icon": "cap",
		"text": "Una gorra roja con la visera doblada. Tu camiseta también es roja: por eso la policía te confundió.",
	},
}

## Pasos de la misión en el orden en que se cuentan. "requires" = pasos que
## tienen que estar hechos antes (para pistas y para mostrarlo como disponible).
## Cada paso tiene tres pistas: orientan, acercan y la última da la solución.
const STEPS := [
	{"id": "foto", "title": "Encuentra la foto del robo", "requires": [], "hints": [
		"Alguien tomó una foto desde lo alto. Busca un sitio elevado en la plaza.",
		"Sube por las escaleras de la plaza, en el lado oeste.",
		"La foto está en la plataforma de arriba de las escaleras.",
	]},
	{"id": "recibo", "title": "Recupera tu recibo", "requires": [], "hints": [
		"Se te voló el recibo mientras corrías. Mira encima de las cosas de la plaza.",
		"Está sobre la caja de madera más alta, junto a las otras dos.",
		"Sube a la caja baja, salta a la mediana y de ahí a la alta.",
	]},
	{"id": "caja", "title": "Abre la caja de grabación del túnel", "requires": [], "hints": [
		"La cámara del túnel de la plaza guarda el video por hora. Necesitas saber a qué hora fue el robo.",
		"La foto del robo tiene la hora en la esquina. Revísala en el inventario.",
		"Escribe la hora sin los dos puntos: 1742.",
	]},
	{"id": "celular", "title": "Encuentra el celular de Diaz", "requires": [], "hints": [
		"Diaz perdió el celular persiguiendo al ladrón. Pregúntale a tus amigos.",
		"Se le cayó en la calle del oriente, la que sale del cruce hacia el este.",
		"Camina por la calle del este hasta el fondo, por el andén sur.",
	]},
	{"id": "desbloqueo", "title": "Desbloquea el celular", "requires": ["celular"], "hints": [
		"Diaz sabe el patrón. Habla con tus amigos.",
		"Diaz dijo que su patrón es la última letra del abecedario.",
		"Es una Z: une 1-2-3, baja en diagonal al 5 y al 7, y termina en 8-9.",
	]},
	{"id": "gorra", "title": "Encuentra la gorra del ladrón", "requires": ["desbloqueo"], "hints": [
		"El video del celular muestra dónde tiró la gorra el ladrón.",
		"La tiró en una caneca al fondo de la calle norte.",
		"Sigue la calle que sale del cruce hacia el norte hasta el final, por el andén oeste.",
	]},
	{"id": "reconstruccion", "title": "Reconstruye lo que pasó con tus amigos",
			"requires": ["foto", "recibo", "caja", "desbloqueo", "gorra"], "hints": [
		"Cada respuesta está en una prueba. Revisa el inventario antes de contestar.",
		"La hora está en la foto y en el video. Tu coartada está en el recibo.",
		"Compara el color de tu camiseta con el de la gorra del ladrón.",
	]},
]

## Reconstrucción final con los amigos. "answer" es el índice correcto.
const DEDUCTION := [
	{"question": "¿A qué hora fue el robo?",
		"options": ["17:24", "17:42", "18:42"], "answer": 1,
		"source": "La foto y el video marcan las 17:42."},
	{"question": "¿Dónde estaba Sebastián a esa hora?",
		"options": ["Escondido en el túnel de la plaza", "Pagando en la Tienda Doña Rosa", "Comprando un granizado"],
		"answer": 1, "source": "El recibo dice Tienda Doña Rosa, 17:42."},
	{"question": "¿Por qué la policía confundió a Sebastián con el ladrón?",
		"options": ["Porque tenía el celular de Diaz", "Porque corrió al ver a la policía",
			"Porque los dos iban de rojo: él con la camiseta y el ladrón con la gorra"],
		"answer": 2, "source": "La gorra roja y tu camiseta roja."},
]


static func step(id: String) -> Dictionary:
	for s: Dictionary in STEPS:
		if s["id"] == id:
			return s
	return {}


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func mode(id: String) -> Dictionary:
	return MODES.get(id, MODES["explorador"])
