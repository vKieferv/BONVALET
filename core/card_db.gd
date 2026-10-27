class_name CardDB
extends RefCounted

# Cartas como datos. Dos fuentes:
# - data/cards.json: el catálogo de cartas del DT (load_catalog, por id) y el mazo clásico de 19
#   (load_templates/load_deck, que respetan "count"; el de antes de M2, para pruebas y comparaciones).
# - data/decks.json: el mazo estándar, las cartas de rasgo y el crecimiento por arquetipo (D-23).
#   archetype_templates arma las cartas del DT de un arquetipo; el mazo de un club (con las firmas de
#   sus titulares y los canteranos asignados) lo arma SquadManager.

const CARDS_PATH := "res://data/cards.json"
const DECKS_PATH := "res://data/decks.json"
const TRAIT_SLOT := "@rasgo"   # en decks.json "estandar": el lugar de la carta de rasgo del arquetipo

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


# Todas las cartas de cards.json por id (también las de count 0), sin "count".
static func load_catalog(path: String = CARDS_PATH) -> Dictionary:
	var out := {}
	var data = _read_json(path)
	if not (data is Dictionary and data.get("cards") is Array):
		return out
	for d in data["cards"]:
		var c: Dictionary = (d as Dictionary).duplicate(true)
		c.erase("count")
		out[String(c["id"])] = c
	return out


# decks.json: {estandar, rasgos, crecimiento}. {} si no existe o no se puede leer.
static func load_deck_lists(path: String = DECKS_PATH) -> Dictionary:
	var data = _read_json(path)
	return data if data is Dictionary else {}


# Ids de las cartas del DT de un arquetipo: el mazo estándar con TRAIT_SLOT convertido en su carta de
# rasgo y, después, las primeras `extra` cartas de su crecimiento (en orden). `lists` = decks.json o
# una variante del laboratorio de balance.
static func deck_ids(lists: Dictionary, archetype: String, extra: int = 0) -> Array:
	var ids: Array = []
	for id in lists.get("estandar", []):
		if id == TRAIT_SLOT:
			var trait_id = lists.get("rasgos", {}).get(archetype)
			if trait_id != null:
				ids.append(String(trait_id))
		else:
			ids.append(String(id))
	var growth: Array = lists.get("crecimiento", {}).get(archetype, [])
	ids.append_array(growth.slice(0, clampi(extra, 0, growth.size())))
	return ids


# Plantillas (una por copia, listas para build_deck) a partir de ids del catálogo. Las que no están
# en el catálogo se omiten: las pruebas de datos comprueban que decks.json no nombre cartas inexistentes.
static func templates_from_ids(ids: Array, catalog: Dictionary) -> Array:
	var out: Array = []
	for id in ids:
		if catalog.has(id):
			out.append((catalog[id] as Dictionary).duplicate(true))
	return out


# Cartas del DT de un arquetipo (sin firmas ni canteranos asignados): lo que miden sim.gd y el panel
# de simulación por arquetipo.
static func archetype_templates(catalog: Dictionary, lists: Dictionary, archetype: String, extra: int = 0) -> Array:
	return templates_from_ids(deck_ids(lists, archetype, extra), catalog)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())


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
