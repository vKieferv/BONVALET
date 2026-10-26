class_name Card
extends RefCounted

enum Type { BASIC, TACTICAL, ELITE, PENALTY }
enum Kind { CONTROL, PASS, DRIBBLE, CROSS, SHOT }

const TYPE_MAP := {"basic": Type.BASIC, "tactical": Type.TACTICAL, "elite": Type.ELITE}
const KIND_MAP := {"control": Kind.CONTROL, "pass": Kind.PASS, "dribble": Kind.DRIBBLE, "cross": Kind.CROSS, "shot": Kind.SHOT}

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
# Metadatos de jugador (reglas de liga). age = 0 -> carta de acción genérica, sin jugador asociado.
var is_foreigner: bool = false
var age: int = 0
var player_id: String = ""


func effective_bonus() -> float:
	return maxf(bonus - 0.02 * wear, 0.0)


static func from_dict(d: Dictionary) -> Card:
	var c := Card.new()
	c.id = d["id"]
	c.display_name = d["name"]
	c.type = TYPE_MAP[d["type"]]
	c.kind = KIND_MAP[d["kind"]]
	c.energy_cost = int(d["cost"])
	c.bonus = float(d["bonus"])
	c.tags = d.get("tags", [])
	c.is_foreigner = bool(d.get("foreign", false))
	c.age = int(d.get("age", 0))
	c.player_id = String(d.get("player_id", ""))
	return c
