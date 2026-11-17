class_name SideQuests
extends RefCounted
## Misiones secundarias y secretos de la versión 2.0 (solo datos).
##
## Cada misión la entrega un personaje del Centro: aparece con un «!» dorado
## sobre la cabeza mientras está disponible y con un «?» cuando ya se puede
## entregar. Los objetivos tienen un contador ("count"); los opcionales
## ("optional": true) dan un bono si se cumplen, pero no hacen falta para
## terminar. La recompensa se cobra una sola vez (PlayerProfile.complete_quest).
## La lógica de cada una vive en CentroMission.

const LIST := {
	"obleas": {
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
		"title": "Postales vivas", "giver": "Mariana", "zone": "Parque Santander",
		"summary": "Mariana estudia turismo y arma una guía del Centro. Le faltan fotos de tres lugares que todo el mundo debería conocer.",
		"objectives": [
			{"id": "fotos", "text": "Toma fotos de la Catedral, la Capilla de los Dolores y la Casa de Bolívar", "count": 3},
			{"id": "volver", "text": "Muéstrale las fotos a Mariana", "count": 1},
		],
		"reward": {"xp": 200, "money": 80, "rep": 2},
	},
	"firulais": {
		"title": "¿Dónde está Firulais?", "giver": "Doña Carmen", "zone": "Parque García Rovira",
		"summary": "Firulais, el perro de Doña Carmen, se soltó persiguiendo una ardilla hacia el Parque de las Cigarras.",
		"objectives": [
			{"id": "encontrar", "text": "Encuentra a Firulais en el Parque de las Cigarras", "count": 1},
			{"id": "traer", "text": "Llévalo de vuelta con Doña Carmen (te sigue)", "count": 1},
		],
		"reward": {"xp": 250, "money": 100, "rep": 5},
	},
	"raponero": {
		"title": "¡Raponazo!", "giver": "Una señora", "zone": "Carrera 27",
		"summary": "Un raponero le arrancó el bolso a una señora en la 27. Si lo alcanzas, suelta el bolso.",
		"event": true,
		"objectives": [
			{"id": "alcanzar", "text": "Alcanza al raponero antes de que se pierda", "count": 1},
			{"id": "devolver", "text": "Devuélvele el bolso a la señora", "count": 1},
		],
		"reward": {"xp": 150, "money": 60, "rep": 6},
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


static func objective(quest_id: String, obj_id: String) -> Dictionary:
	for o: Dictionary in LIST.get(quest_id, {}).get("objectives", []):
		if o["id"] == obj_id:
			return o
	return {}
