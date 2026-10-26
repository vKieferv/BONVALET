class_name Card
extends RefCounted

enum Type { BASIC, TACTICAL, ELITE, PENALTY }
# Ataque: CONTROL..PAUSE. Defensa: PRESS..CLEARANCE (ver DEFENSIVE_KINDS).
enum Kind { CONTROL, PASS, DRIBBLE, CROSS, SHOT, PAUSE, PRESS, BLOCK, INTERCEPT, CLEARANCE }

const TYPE_MAP := {"basic": Type.BASIC, "tactical": Type.TACTICAL, "elite": Type.ELITE}
const KIND_MAP := {
	"control": Kind.CONTROL, "pass": Kind.PASS, "dribble": Kind.DRIBBLE, "cross": Kind.CROSS,
	"shot": Kind.SHOT, "pause": Kind.PAUSE,
	"press": Kind.PRESS, "block": Kind.BLOCK, "intercept": Kind.INTERCEPT, "clearance": Kind.CLEARANCE,
}
const DEFENSIVE_KINDS := [Kind.PRESS, Kind.BLOCK, Kind.INTERCEPT, Kind.CLEARANCE]

var id: String = ""
var display_name: String = ""
var type: Type = Type.BASIC
var kind: Kind = Kind.PASS
var energy_cost: int = 3
var bonus: float = 0.05          # 0.05 = +5% de éxito
var tags: Array = []             # "fisica", "bloque_bajo", "linea_alta"...
var wear: int = 0                # oxidación/degradación: cada punto resta 2% al bono
var flow_uses: int = 0           # reusos dentro del Flow actual (sube el costo)
var playable: bool = true        # las cartas de penalización no se pueden jugar
var is_temporary: bool = false
# Metadatos de jugador. owner_id = "" -> carta colectiva (del DT), sin dueño.
# owner_id identifica al Ejecutor Natural y cuenta para el plantel en las reglas de liga.
var owner_id: String = ""
var nationality: String = ""     # código de 3 letras (CHI, ARG...); si está, define si es extranjero
var is_foreigner: bool = false
var age: int = 0


func effective_bonus() -> float:
	return maxf(bonus - 0.02 * wear, 0.0)


func is_defensive() -> bool:
	return kind in DEFENSIVE_KINDS


static func from_dict(d: Dictionary) -> Card:
	var c := Card.new()
	c.id = d["id"]
	c.display_name = d["name"]
	c.type = TYPE_MAP[d["type"]]
	c.kind = KIND_MAP[d["kind"]]
	c.energy_cost = int(d["cost"])
	c.bonus = float(d["bonus"])
	c.tags = d.get("tags", [])
	c.owner_id = String(d.get("owner_id", d.get("player_id", "")))   # player_id: nombre anterior (v10)
	c.nationality = String(d.get("nationality", ""))
	c.is_foreigner = bool(d.get("foreign", false))
	c.age = int(d.get("age", 0))
	return c
