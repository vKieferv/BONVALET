class_name CardDB
extends RefCounted

# Cartas como datos. data/cards.json es el catálogo de cartas del DT (y el mazo clásico de 19 que usan
# las pruebas de reglas, por "count"); data/decks.json dice con qué cartas juega cada estilo: el mazo
# estándar, la carta de rasgo de cada arquetipo y su lista de crecimiento (D-23). Aquí se arma la lista
# del DT por arquetipo; SquadManager la lleva a un club (firmas de los titulares, canteranos, tope de 20).

const CARDS_PATH := "res://data/cards.json"
const DECKS_PATH := "res://data/decks.json"
const SIGNATURES_PATH := "res://data/signature_cards.json"
const RASGO := "@rasgo"   # en decks.json, el lugar de la carta de rasgo dentro del mazo estándar

const PENALTY_NAMES := {
	"calambre": "Calambre",
	"falta_aire": "Falta de Aire",
	"nervios": "Nervios",
}


# Catálogo: id -> plantilla de la carta, sin mirar "count" (también las que no están en el mazo clásico).
static func load_catalog(path: String = CARDS_PATH) -> Dictionary:
	var out := {}
	var data = _read(path)
	if data is Dictionary:
		for d in data.get("cards", []):
			out[String(d["id"])] = d
	return out


# data/decks.json: {estandar: [ids], rasgos: {arquetipo: id}, crecimiento: {arquetipo: [ids]}}.
static func load_decks(path: String = DECKS_PATH) -> Dictionary:
	var data = _read(path)
	return data if data is Dictionary else {}


# Cartas del DT de un estilo como plantillas, una por copia y en orden: el mazo estándar con su carta de
# rasgo en el lugar de "@rasgo", más las primeras `extra` cartas de su crecimiento. Los ids que no están
# en el catálogo se omiten (las pruebas de engine_rules revisan que no haya ninguno).
static func archetype_templates(catalog: Dictionary, decks: Dictionary, archetype: String, extra: int = 0) -> Array:
	var ids: Array = []
	for id in decks.get("estandar", []):
		if id == RASGO:
			var rasgo = decks.get("rasgos", {}).get(archetype)
			if rasgo != null:
				ids.append(rasgo)
		else:
			ids.append(id)
	var growth: Array = decks.get("crecimiento", {}).get(archetype, [])
	ids.append_array(growth.slice(0, clampi(extra, 0, growth.size())))
	var out: Array = []
	for id in ids:
		if catalog.has(id):
			out.append((catalog[id] as Dictionary).duplicate(true))
	return out


# El mazo de un club cualquiera de ese estilo, para simular arquetipos sin plantel: el de
# archetype_templates más la firma genérica de una figura ("Sello de la figura", sin dueño, así que
# no activa el Ejecutor Natural). Sin una firma, el mazo estándar no trae remates de 2 PA y un bot
# prudente como Catenaccio no encuentra jugadas que valgan la pena.
static func club_like_templates(catalog: Dictionary, decks: Dictionary, archetype: String, extra: int = 0) -> Array:
	var out := archetype_templates(catalog, decks, archetype, extra)
	var sig = _read(SIGNATURES_PATH)
	if sig is Dictionary and sig.has("template"):
		var d: Dictionary = (sig["template"] as Dictionary).duplicate(true)
		d["id"] = "sello_generico"
		d["name"] = String(d["name"]) % "la figura"
		out.append(d)
	return out


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())


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
