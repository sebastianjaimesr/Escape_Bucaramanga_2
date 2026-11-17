class_name SideQuests
extends RefCounted
## Misiones secundarias y secretos (solo datos).
##
## Cada misión pertenece a un capítulo ("chapter") y la entrega un personaje
## de ese mapa: aparece con un «!» dorado
## sobre la cabeza mientras está disponible y con un «?» cuando ya se puede
## entregar. Los objetivos tienen un contador ("count"); los opcionales
## ("optional": true) dan un bono si se cumplen, pero no hacen falta para
## terminar; los de entrega ("return": true) se cumplen hablando con quien dio
## la misión (el «?» aparece cuando solo falta eso). La recompensa se cobra una sola vez (PlayerProfile.complete_quest).
## La lógica de cada una vive en la misión del capítulo (CentroMission,
## RoboPlazaMission, GranHuidaMission); lo común está en Mission.

const LIST := {
	"obleas": {
		"chapter": "cigarra",
		"title": "Obleas a domicilio", "giver": "Don Aníbal", "zone": "Carrera 27",
		"summary": "A Don Aníbal le hicieron tres pedidos de obleas con arequipe y no puede dejar el puesto. Llévalos antes de que se ablanden.",
		"objectives": [
			{"id": "entregas", "text": "Entrega las obleas (Santander, García Rovira y las Cigarras)", "count": 3},
			{"id": "rapido", "text": "Opcional: entrégalas en menos de 150 s", "count": 1, "optional": true},
		],
		"reward": {"xp": 220, "money": 120, "rep": 3},
		"bonus": {"xp": 100, "money": 40},
	},
	"fotos": {
		"chapter": "cigarra",
		"title": "Postales vivas", "giver": "Mariana", "zone": "Parque Santander",
		"summary": "Mariana estudia turismo y arma una guía del Centro. Le faltan fotos de tres lugares que todo el mundo debería conocer.",
		"objectives": [
			{"id": "fotos", "text": "Toma fotos de la Catedral, la Capilla de los Dolores y la Casa de Bolívar", "count": 3},
			{"id": "volver", "text": "Muéstrale las fotos a Mariana", "count": 1, "return": true},
		],
		"reward": {"xp": 200, "money": 80, "rep": 2},
	},
	"firulais": {
		"chapter": "cigarra",
		"title": "¿Dónde está Firulais?", "giver": "Doña Carmen", "zone": "Parque García Rovira",
		"summary": "Firulais, el perro de Doña Carmen, se soltó persiguiendo una ardilla hacia el Parque de las Cigarras.",
		"objectives": [
			{"id": "encontrar", "text": "Encuentra a Firulais en el Parque de las Cigarras", "count": 1},
			{"id": "traer", "text": "Llévalo de vuelta con Doña Carmen (te sigue)", "count": 1},
		],
		"reward": {"xp": 250, "money": 100, "rep": 5},
	},
	"raponero": {
		"chapter": "cigarra",
		"title": "¡Raponazo!", "giver": "Una señora", "zone": "Carrera 27",
		"summary": "Un raponero le arrancó el bolso a una señora en la 27. Si lo alcanzas, suelta el bolso.",
		"event": true,
		"objectives": [
			{"id": "alcanzar", "text": "Alcanza al raponero antes de que se pierda", "count": 1},
			{"id": "devolver", "text": "Devuélvele el bolso a la señora", "count": 1},
		],
		"reward": {"xp": 150, "money": 60, "rep": 6},
	},
	# --- La manzana (capítulo 2, de mañana) ---
	"hojas": {
		"chapter": "robo_plaza",
		"title": "Las hojas de Valentina", "giver": "Valentina", "zone": "La plaza",
		"summary": "El viento de la mañana le voló a Valentina la tarea de sociales. Son tres hojas y la entrega hoy a primera hora.",
		"objectives": [
			{"id": "hojas", "text": "Recoge las hojas: una en lo alto, otra en una caja y otra en el túnel", "count": 3},
			{"id": "volver", "text": "Devuélveselas a Valentina", "count": 1, "return": true},
		],
		"reward": {"xp": 180, "money": 70, "rep": 2},
	},
	"aguacero": {
		"chapter": "robo_plaza",
		"title": "¡Aguacero!", "giver": "Don Pacho", "zone": "La plaza",
		"summary": "Se largó a llover de un momento a otro y las canastas de fruta de Don Pacho quedaron al aire. Hay que taparlas antes de que se pierdan.",
		"event": true,
		"objectives": [
			{"id": "tapar", "text": "Tapa las canastas de fruta antes de que se mojen", "count": 3},
			{"id": "volver", "text": "Avísale a Don Pacho", "count": 1, "return": true},
		],
		"reward": {"xp": 160, "money": 60, "rep": 4},
	},
	# --- Cabecera (capítulo 5, de madrugada) ---
	"pan": {
		"chapter": "gran_huida",
		"title": "Pan de madrugada", "giver": "Don Ricardo", "zone": "Parque de las Palmas",
		"summary": "Don Ricardo abre la panadería a las cuatro y el domiciliario no llegó. Hay dos pedidos de pan calientico esperando en el parque.",
		"objectives": [
			{"id": "entregas", "text": "Lleva el pan al celador del mirador y a la taxista de la 33", "count": 2},
			{"id": "sigilo", "text": "Opcional: que la policía no te vea mientras repartes", "count": 1, "optional": true},
		],
		"reward": {"xp": 200, "money": 90, "rep": 3},
		"bonus": {"xp": 80, "money": 30},
	},
}

## Cigarras pintadas escondidas por el Centro (secretos). id -> [pista, posición]
## La posición la pone CentroMission a partir de los puntos del mapa.
const SECRETS := {
	"cigarra_terraza": "En una terraza a la que se sube por una escalera de incendios.",
	"cigarra_campanario": "Detrás de la capilla, donde casi nadie mira.",
	"cigarra_claro": "En un claro escondido del bosque de las Cigarras.",
	"cigarra_pasaje": "Al fondo del pasaje de la 27, donde se acaban los bombillos.",
	"cigarra_catedral": "A la sombra de una torre de la catedral.",
}


## Las misiones de un capítulo, en el orden de LIST.
static func for_chapter(chapter_id: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in LIST:
		if LIST[id].get("chapter", "") == chapter_id:
			ids.append(id)
	return ids


## Todas las misiones de esos capítulos están en `done`.
static func all_done(chapter_ids: Array, done: Array) -> bool:
	for id: String in LIST:
		if LIST[id].get("chapter", "") in chapter_ids and not id in done:
			return false
	return true


static func objective(quest_id: String, obj_id: String) -> Dictionary:
	for o: Dictionary in LIST.get(quest_id, {}).get("objectives", []):
		if o["id"] == obj_id:
			return o
	return {}
