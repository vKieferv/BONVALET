class_name Habilidades
extends RefCounted

# Habilidades de los jugadores para el modo de duelos (D-29, D-32, D-40; T-13).
# habilidad = nivel (skill_rating) + ajuste del puesto + perfil (+6), tope 95. El arquero solo tiene
# Atajada (= nivel + perfil). Los perfiles de la élite están en data/perfiles_2006.json.
# El motor recibe a cada jugador como un diccionario simple (MatchEngine.duel_players), sin depender
# de scripts/: {id, name, role, pase, regate, remate, quite, lectura, atajada, perfil}.

const PERFILES_PATH := "res://data/perfiles_2006.json"
const SKILLS := ["pase", "regate", "remate", "quite", "lectura"]
const PROFILE_BONUS := 6
const MAX_SKILL := 95
# Ajuste del puesto (D-32): los positivos no pasan de +3.
const ROLE_ADJUST := {
    "DFC": {"pase": -10, "regate": -20, "remate": -25, "quite": 3, "lectura": 3},
    "LAT": {"pase": -5, "regate": -5, "remate": -20, "quite": 0, "lectura": -5},
    "MCD": {"pase": 0, "regate": -10, "remate": -15, "quite": 3, "lectura": 3},
    "MCO": {"pase": 3, "regate": 0, "remate": -5, "quite": -15, "lectura": -10},
    "EXT": {"pase": -5, "regate": 3, "remate": -5, "quite": -20, "lectura": -15},
    "DEL": {"pase": -10, "regate": 0, "remate": 3, "quite": -25, "lectura": -20},
}

var tipos := {}      # tipo de perfil -> habilidad que sube
var perfiles := {}   # id del jugador -> tipo de perfil


func load_profiles(path: String = PERFILES_PATH) -> bool:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return false
    var d = JSON.parse_string(f.get_as_text())
    if not d is Dictionary:
        return false
    tipos = d.get("tipos", {})
    perfiles = d.get("perfiles", {})
    return true


# Habilidades de un jugador del plantel ({id, name, role, skill_rating}).
func of(player: Dictionary) -> Dictionary:
    var role := String(player.get("role", ""))
    var level := int(player.get("skill_rating", 0))
    var perfil := String(perfiles.get(String(player.get("id", "")), ""))
    var boosted := String(tipos.get(perfil, ""))
    var out := {"id": String(player.get("id", "")), "name": String(player.get("name", "")), "role": role,
        "perfil": perfil, "atajada": 0}
    for s in SKILLS:
        out[s] = 0
    if role == "POR":
        out["atajada"] = mini(MAX_SKILL, level + (PROFILE_BONUS if boosted == "atajada" else 0))
        return out
    var adjust: Dictionary = ROLE_ADJUST.get(role, {})
    for s in SKILLS:
        var v := level + int(adjust.get(s, 0)) + (PROFILE_BONUS if boosted == s else 0)
        out[s] = clampi(v, 1, MAX_SKILL)
    return out
