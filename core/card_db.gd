class_name CardDB
extends RefCounted

const PENALTY_NAMES := {
	"calambre": "Calambre",
	"falta_aire": "Falta de Aire",
	"nervios": "Nervios",
}


static func load_deck(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	var out: Array = []
	for d in data["cards"]:
		for i in int(d.get("count", 1)):
			out.append(Card.from_dict(d))
	return out


# Lee el JSON una sola vez; útil para simular miles de partidos (incluso en hilos).
static func load_templates(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	var out: Array = []
	for d in data["cards"]:
		for i in int(d.get("count", 1)):
			out.append(d)
	return out


static func build_deck(templates: Array) -> Array:
	var out: Array = []
	for d in templates:
		out.append(Card.from_dict(d))
	return out


static func make_penalty(id: String) -> Card:
	var c := Card.new()
	c.id = id
	c.display_name = PENALTY_NAMES[id]
	c.type = Card.Type.PENALTY
	c.ap_cost = 0
	c.stamina_cost = 0.0
	c.bonus = 0.0
	c.playable = false
	c.is_temporary = true
	return c
