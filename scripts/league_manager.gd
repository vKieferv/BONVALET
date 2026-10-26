class_name LeagueManager
extends RefCounted

# Capa de datos y reglas de liga.
# Carga data/league_config.json y data/teams_chile_2006.json, valida mazos y
# entrega equipos / perfiles de bot / colores para el menú de selección.

const DEFAULT_CONFIG_PATH := "res://data/league_config.json"
const DEFAULT_TEAMS_PATH := "res://data/teams_chile_2006.json"
const TYPE_KEYS := ["basic", "tactical", "elite", "penalty"]   # mismo orden que Card.Type

var leagues: Dictionary = {}
var teams: Array = []
var load_errors: Array = []
var _by_id: Dictionary = {}


# ------------------------------------------------------------------ Carga

func load_all(config_path: String = DEFAULT_CONFIG_PATH, teams_path: String = DEFAULT_TEAMS_PATH) -> bool:
    load_errors.clear()
    leagues.clear()
    teams.clear()
    _by_id.clear()

    var cfg = _read_json(config_path)
    if cfg is Dictionary and cfg.has("leagues"):
        leagues = cfg["leagues"]
    else:
        load_errors.append("Configuración de liga inválida: %s" % config_path)

    var data = _read_json(teams_path)
    if data is Dictionary and data.has("teams"):
        teams = data["teams"]
        for t in teams:
            _by_id[t["id"]] = t
    else:
        load_errors.append("Base de equipos inválida: %s" % teams_path)
    return load_errors.is_empty()


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        load_errors.append("No existe el archivo: %s" % path)
        return null
    var f := FileAccess.open(path, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if parsed == null:
        load_errors.append("JSON con errores: %s" % path)
    return parsed


# ------------------------------------------------------------------ Consultas

func get_league(league_id: String) -> Dictionary:
    return leagues.get(league_id, {})


func get_rules(league_id: String) -> Dictionary:
    return get_league(league_id).get("rules", {})


func get_team(team_id: String) -> Dictionary:
    return _by_id.get(team_id, {})


# Equipos ordenados: Primera A antes que Primera B y, dentro, por nombre.
func get_teams(division: String = "") -> Array:
    var out: Array = []
    for t in teams:
        if division == "" or t["division"] == division:
            out.append(t)
    out.sort_custom(LeagueManager._cmp_teams)
    return out


static func _cmp_teams(a: Dictionary, b: Dictionary) -> bool:
    if a["division"] != b["division"]:
        return a["division"] < b["division"]   # "Primera A" < "Primera B"
    return String(a["name"]) < String(b["name"])


func dt_name(team: Dictionary) -> String:
    var dt = team.get("dt")
    return "Por definir" if dt == null else String(dt)


func signature_name(team: Dictionary) -> String:
    var s = team.get("signature_card")
    return "Figura de %s" % team.get("short_name", "?") if s == null else String(s)


# Perfil de bot del club según su arquetipo (el nombre del perfil pasa a ser el del club).
func profile_for_team(team: Dictionary) -> BotProfile:
    var p: BotProfile
    match String(team.get("archetype", "Directo")):
        "Tiki-Taka":
            p = BotProfile.tiki_taka()
        "Catenaccio":
            p = BotProfile.catenaccio()
        "Kamikaze":
            p = BotProfile.kamikaze()
        "Contragolpe":
            p = BotProfile.contragolpe()
        _:
            p = BotProfile.directo()
    p.profile_name = String(team.get("short_name", p.profile_name))
    return p


func team_colors(team: Dictionary) -> Array:
    return [Color.html(String(team.get("primary_color", "#FFFFFF"))),
            Color.html(String(team.get("secondary_color", "#000000")))]


# Color legible sobre fondo oscuro (el más claro de los dos; se aclara si es muy oscuro).
func team_display_color(team: Dictionary) -> Color:
    var cols := team_colors(team)
    var c: Color = cols[0] if cols[0].get_luminance() >= cols[1].get_luminance() else cols[1]
    return c.lightened(0.35) if c.get_luminance() < 0.25 else c


# ------------------------------------------------------------------ Validación de mazo

# deck_array: Cards (o diccionarios de cards.json). Devuelve
# {valid, errors[], foreigners, sub21, squad_size, payroll, rules}.
# Si se pasa team_id también se comprueba la masa salarial contra el presupuesto del club.
func validate_deck(deck_array: Array, league_id: String, team_id: String = "") -> Dictionary:
    var result := {"valid": false, "errors": [], "foreigners": 0, "sub21": 0,
        "squad_size": 0, "payroll": 0.0, "rules": {}}
    var league := get_league(league_id)
    if league.is_empty():
        result["errors"].append("Liga desconocida: %s" % league_id)
        return result

    var rules: Dictionary = league.get("rules", {})
    result["rules"] = rules
    var sub21_limit := int(rules.get("sub21_age_limit", 21))
    var foreigners := 0
    var sub21 := 0
    var players := {}
    for c in deck_array:
        if _type_key(c) == "penalty":
            continue
        if _is_foreigner(c):
            foreigners += 1
        var age := int(_field(c, "age", 0))
        if age > 0 and age < sub21_limit:
            sub21 += 1
        var pid := String(_field(c, "player_id", ""))
        if pid != "":
            players[pid] = true
    result["foreigners"] = foreigners
    result["sub21"] = sub21
    result["squad_size"] = players.size()

    var errors: Array = result["errors"]
    var max_foreign := int(rules.get("max_foreigners_in_deck", 99))
    if foreigners > max_foreign:
        errors.append("Demasiados extranjeros en el mazo: %d (máximo %d)." % [foreigners, max_foreign])
    var min_sub21 := int(rules.get("mandatory_sub21_cards", 0))
    if sub21 < min_sub21:
        errors.append("Faltan cartas Sub-21: tienes %d y se exigen %d." % [sub21, min_sub21])
    var max_squad := int(rules.get("max_squad_size", 99))
    if players.size() > max_squad:
        errors.append("Plantel demasiado grande: %d jugadores (máximo %d)." % [players.size(), max_squad])

    if team_id != "":
        var team := get_team(team_id)
        if team.is_empty():
            errors.append("Equipo desconocido: %s" % team_id)
        else:
            var payroll := payroll_for_deck(deck_array, league_id, team_id)
            var cap := float(team["initial_budget"]) * float(league.get("salary", {}).get("max_payroll_pct_of_budget", 1.0))
            result["payroll"] = payroll
            if payroll > cap:
                errors.append("La masa salarial (%.0f) supera el tope del club (%.0f)." % [payroll, cap])

    result["valid"] = errors.is_empty()
    return result


# Costo salarial anual del mazo (millones de CLP), según tipo de carta y modificadores de la liga.
func payroll_for_deck(deck_array: Array, league_id: String, team_id: String = "") -> float:
    var league := get_league(league_id)
    var salary: Dictionary = league.get("salary", {})
    var base: Dictionary = salary.get("base_by_card_type", {})
    var sub21_limit := int(league.get("rules", {}).get("sub21_age_limit", 21))
    var total := 0.0
    for c in deck_array:
        var key := _type_key(c)
        if key == "penalty":
            continue
        var s := float(base.get(key, 0.0))
        if _is_foreigner(c):
            s *= float(salary.get("foreigner_multiplier", 1.0))
        var age := int(_field(c, "age", 0))
        if age > 0 and age < sub21_limit:
            s *= float(salary.get("sub21_multiplier", 1.0))
        total += s
    var division := String(get_team(team_id).get("division", "Primera A"))
    return total * float(salary.get("division_salary_scale", {}).get(division, 1.0))


# ------------------------------------------------------------------ Helpers (Card o Dictionary)

func _field(c: Variant, key: String, default: Variant) -> Variant:
    if c is Dictionary:
        return c.get(key, default)
    if c is Object:
        var v = c.get(key)
        return default if v == null else v
    return default


func _is_foreigner(c: Variant) -> bool:
    return bool(_field(c, "is_foreigner", _field(c, "foreign", false)))


func _type_key(c: Variant) -> String:
    var t = _field(c, "type", "basic")
    if t is int:
        return TYPE_KEYS[clampi(t, 0, TYPE_KEYS.size() - 1)]
    return String(t)
