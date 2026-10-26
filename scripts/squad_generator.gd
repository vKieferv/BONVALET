class_name SquadGenerator
extends RefCounted

# Autocompleta el plantel de un club sin datos reales: 18 jugadores balanceados que cumplen las
# reglas de liga (mín. Sub-21, máx. extranjeros). Es determinista por id de club, así que no hace
# falta guardar los planteles generados: se regeneran iguales cada vez.
# Los nombres son ficticios; solo la figura del club (signature_card de teams_chile_2006.json) es real.

# 4-4-2 con recambio: 2 POR, 3 DFC, 3 LAT, 3 MCD, 2 MCO, 2 EXT, 3 DEL.
const SLOTS := ["POR", "POR", "DFC", "DFC", "DFC", "LAT", "LAT", "LAT",
    "MCD", "MCD", "MCD", "MCO", "MCO", "EXT", "EXT", "DEL", "DEL", "DEL"]
const LINES := {"POR": "POR", "DFC": "DEF", "LAT": "DEF", "MCD": "MED", "MCO": "MED", "EXT": "MED", "DEL": "DEL"}
const FIRST_NAMES := ["Juan", "Luis", "Carlos", "Jorge", "Rodrigo", "Cristián", "Felipe", "Sebastián",
    "Diego", "Matías", "Nicolás", "Pablo", "Francisco", "Andrés", "Gonzalo", "Mauricio", "Patricio",
    "Claudio", "Marcelo", "Héctor", "Raúl", "Óscar", "Víctor", "Esteban", "Ignacio", "Javier"]
const SURNAMES := ["González", "Muñoz", "Rojas", "Díaz", "Pérez", "Soto", "Contreras", "Silva",
    "Martínez", "Sepúlveda", "Morales", "Rodríguez", "López", "Fuentes", "Hernández", "Torres",
    "Araya", "Flores", "Espinoza", "Valenzuela", "Castillo", "Tapia", "Reyes", "Gutiérrez", "Castro",
    "Pizarro", "Álvarez", "Vásquez", "Cáceres", "Fernández", "Carrasco", "Cortés", "Núñez", "Bravo"]
const FOREIGN := [["ARG", ["Benítez", "Cabrera", "Ledesma", "Romero", "Acosta"]],
    ["URU", ["Olivera", "Pereyra", "Rodales", "Sosa"]],
    ["PAR", ["Giménez", "Cardozo", "Ortiz", "Báez"]],
    ["COL", ["Mosquera", "Valencia", "Zapata", "Arboleda"]]]


# team: diccionario de teams_chile_2006.json. rules: rules de league_config.json.
static func generate(team: Dictionary, rules: Dictionary) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = String(team["id"]).hash()
    var size := int(rules.get("max_squad_size", 18))
    var min_sub21 := int(rules.get("mandatory_sub21_cards", 2))
    var sub21_limit := int(rules.get("sub21_age_limit", 21))
    var max_foreign := int(rules.get("max_foreigners_in_deck", 6))
    var level := int(team.get("facilities_level", 1))
    var base := 50 + 6 * level + (4 if team.get("division") == "Primera A" else 0)

    var slots: Array = SLOTS.slice(0, size)
    var figure := String(team.get("signature_card")) if team.get("signature_card") != null else ""
    var figure_slot := slots.rfind("DEL") if figure != "" else -1
    var figure_foreign := figure != "" and String(team.get("signature_nationality", "CHI")) != "CHI"
    # La figura y los arqueros quedan fuera de la cuota juvenil; la figura extranjera cuenta para el tope.
    var youth := _pick_indices(rng, slots.size(), min_sub21, [0, 1, figure_slot])
    var foreign_count := mini(max_foreign - (1 if figure_foreign else 0), rng.randi_range(0, 1 + level))
    var foreigners := _pick_indices(rng, slots.size(), foreign_count, youth + [figure_slot])

    var players: Array = []
    var used_names := {}
    for i in slots.size():
        var role: String = slots[i]
        var p := {
            "id": "%s_%02d" % [team["id"], i + 1],
            "name": "",
            "age": rng.randi_range(17, sub21_limit - 1) if youth.has(i) else rng.randi_range(sub21_limit, 34),
            "nationality": "CHI",
            "position": LINES[role],
            "role": role,
            "stamina_max": rng.randi_range(58, 84),
            "skill_rating": clampi(base + rng.randi_range(-7, 7) - (8 if youth.has(i) else 0), 40, 99),
            "signature_card_id": null,
            "generated": true,
        }
        if i == figure_slot:
            # La figura real del club: nombre y nacionalidad de la base de equipos; la edad no se conoce.
            p["id"] = SquadManager.slug(figure)
            p["name"] = figure
            p["age"] = null
            p["nationality"] = String(team.get("signature_nationality", "CHI"))
            p["skill_rating"] = clampi(base + 14, 40, 99)
            p.erase("generated")
        elif foreigners.has(i):
            var f: Array = FOREIGN[rng.randi_range(0, FOREIGN.size() - 1)]
            p["nationality"] = f[0]
            p["name"] = _unique_name(rng, used_names, f[1])
        else:
            p["name"] = _unique_name(rng, used_names, SURNAMES)
        if p["age"] != null and int(p["age"]) >= 32:
            p["stamina_max"] = int(p["stamina_max"]) - 8
        players.append(p)
    return players


# count índices distintos en [0, n) que no estén en excluded.
static func _pick_indices(rng: RandomNumberGenerator, n: int, count: int, excluded: Array) -> Array:
    var pool: Array = []
    for i in n:
        if not excluded.has(i):
            pool.append(i)
    var out: Array = []
    while out.size() < count and not pool.is_empty():
        out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
    return out


static func _unique_name(rng: RandomNumberGenerator, used: Dictionary, surnames: Array) -> String:
    for attempt in 20:
        var n := "%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)],
                surnames[rng.randi_range(0, surnames.size() - 1)]]
        if not used.has(n):
            used[n] = true
            return n
    return "Jugador %d" % used.size()
