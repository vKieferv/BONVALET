class_name Career
extends RefCounted

# Estado del modo carrera y reglas de la semana: Bloque 1 (sponsor y evento social), Bloque 2
# (entrenamiento o kinesiología) y Bloque 3 (validar el mazo e ir al partido).
# Career.current sobrevive a los cambios de escena entre el calendario y el partido.
# Los números salen de data/career_2006.json; aquí solo se aplican.

static var current: Career

const DATA_PATH := "res://data/career_2006.json"
const DECK_PATH := "res://data/cards.json"
const LEAGUE_ID := "chile_2006"

var league: LeagueManager
var squads: SquadManager
var data := {}
var templates: Array = []
var rng := RandomNumberGenerator.new()
var load_errors: Array = []

var team_id := ""
var week := 1
var budget := 0.0
var popularity := 50
var discipline := 50
var fatigue := 0.0
var sponsor_id := ""
var history: Array = []    # {week, rival_id, gf, ga, income}

# Semana en curso
var event_result := {}     # vacío = evento sin resolver
var training := ""         # "" | "tactical" | "physio"
var match_mods := {}       # opening_bonus, opening_moments, form_bonus, funado_id, funado_stamina_mult
var sponsor_week_lost := false
var rival_id := ""
var pending_match := false


# seed = 0 -> aleatorio. Las pruebas pasan una semilla fija.
func setup(p_league: LeagueManager, p_squads: SquadManager, p_team_id: String, seed: int = 0) -> bool:
    league = p_league
    squads = p_squads
    load_errors.clear()
    var parsed = null
    if FileAccess.file_exists(DATA_PATH):
        parsed = JSON.parse_string(FileAccess.open(DATA_PATH, FileAccess.READ).get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Datos de carrera inválidos: %s" % DATA_PATH)
        return false
    data = parsed
    var team := league.get_team(p_team_id)
    if team.is_empty():
        load_errors.append("Club desconocido: %s" % p_team_id)
        return false
    templates = CardDB.load_templates(DECK_PATH)
    team_id = p_team_id
    if seed != 0:
        rng.seed = seed
    else:
        rng.randomize()
    var start: Dictionary = data.get("start", {})
    budget = float(team["initial_budget"])
    popularity = int(start.get("popularity", 50))
    discipline = int(start.get("discipline", 50))
    fatigue = float(start.get("fatigue", 0))
    week = 1
    history.clear()
    sponsor_id = ""
    _new_week()
    return true


func team() -> Dictionary:
    return league.get_team(team_id)


func _new_week() -> void:
    event_result = {}
    training = ""
    match_mods = {}
    sponsor_week_lost = false
    pending_match = false
    rival_id = next_rival()


# Rivales de la misma división en orden fijo, uno por semana (sin el propio club ni suspendidos).
func next_rival() -> String:
    var pool: Array = []
    for t in league.get_teams(String(team()["division"])):
        if t["id"] != team_id and not t.get("suspended", false):
            pool.append(t["id"])
    return "" if pool.is_empty() else String(pool[(week - 1) % pool.size()])


# ------------------------------------------------------------------ Bloque 1: sponsor

func sponsors() -> Array:
    return data.get("sponsors", [])


func get_sponsor(id: String) -> Dictionary:
    for s in sponsors():
        if s["id"] == id:
            return s
    return {}


# Lo que paga el sponsor a este club: escala por división e instalaciones.
func sponsor_offer(sponsor: Dictionary) -> Dictionary:
    var scale_data: Dictionary = data.get("sponsor_scale", {})
    var t := team()
    var scale := float(scale_data.get("division", {}).get(t["division"], 1.0)) \
            * (1.0 + float(scale_data.get("per_facility_level", 0.0)) * int(t.get("facilities_level", 0)))
    return {"weekly": roundi(float(sponsor.get("weekly", 0)) * scale),
        "win_bonus": roundi(float(sponsor.get("win_bonus", 0)) * scale)}


func sponsor_terms(sponsor: Dictionary) -> String:
    var offer := sponsor_offer(sponsor)
    var clause := "Cláusula de conducta: una funa cancela el pago de esa semana." if sponsor.get("conduct_clause", false) \
            else "Sin cláusula de conducta."
    return "%s\nPaga $%d M por semana + $%d M por victoria. %s" % [sponsor.get("pitch", ""), offer["weekly"], offer["win_bonus"], clause]


func choose_sponsor(id: String) -> bool:
    if pending_match or get_sponsor(id).is_empty():
        return false
    sponsor_id = id
    return true


# ------------------------------------------------------------------ Bloque 1: evento social

func week_event() -> Dictionary:
    var events: Array = data.get("events", [])
    return {} if events.is_empty() else events[(week - 1) % events.size()]


# Riesgo y recompensa explícitos, antes de decidir.
func event_terms(ev: Dictionary) -> String:
    var r: Dictionary = ev.get("reward", {})
    var k: Dictionary = ev.get("risk", {})
    var d: Dictionary = ev.get("decline", {})
    var lines := [
        "Si aceptas: +%d%% de acierto en los Momentos 1-%d del próximo partido y popularidad %+d." % [
            roundi(float(r.get("opening_bonus", 0.0)) * 100.0), int(r.get("opening_moments", 2)), int(r.get("popularity", 0))],
        "Riesgo: %d%% de funa → disciplina %+d y un titular con +%d%% de desgaste de estamina en sus cartas ese partido%s." % [
            roundi(float(k.get("chance", 0.0)) * 100.0), int(k.get("discipline", 0)),
            roundi(float(k.get("funado_stamina_extra", 0.5)) * 100.0),
            "; con un sponsor con cláusula de conducta, se pierde el pago de la semana" if k.get("lose_sponsor_week_if_clause", false) else ""],
        "Si te niegas: disciplina %+d y popularidad %+d." % [int(d.get("discipline", 0)), int(d.get("popularity", 0))],
    ]
    return "\n".join(lines)


func resolve_event(accept: bool) -> Dictionary:
    if not event_result.is_empty() or pending_match:
        return event_result
    var ev := week_event()
    var result := {"accepted": accept, "funa": false, "funado_id": "", "lines": []}
    if accept:
        var reward: Dictionary = ev.get("reward", {})
        match_mods["opening_bonus"] = float(reward.get("opening_bonus", 0.0))
        match_mods["opening_moments"] = int(reward.get("opening_moments", 2))
        popularity += int(reward.get("popularity", 0))
        result["lines"].append("La fiesta prende: +%d%% de acierto en los Momentos 1-%d y popularidad %+d." % [
            roundi(match_mods["opening_bonus"] * 100.0), match_mods["opening_moments"], int(reward.get("popularity", 0))])
        var risk: Dictionary = ev.get("risk", {})
        if rng.randf() < float(risk.get("chance", 0.0)):
            var funado := _pick_funado()
            result["funa"] = true
            result["funado_id"] = funado.get("id", "")
            discipline += int(risk.get("discipline", 0))
            match_mods["funado_id"] = funado.get("id", "")
            match_mods["funado_stamina_mult"] = 1.0 + float(risk.get("funado_stamina_extra", 0.5))
            result["lines"].append("¡FUNA! Diario El Chisme publica las fotos de %s: sus cartas gastan +%d%% de estamina. Disciplina %+d." % [
                funado.get("name", "?"), roundi((match_mods["funado_stamina_mult"] - 1.0) * 100.0), int(risk.get("discipline", 0))])
            if risk.get("lose_sponsor_week_if_clause", false) and get_sponsor(sponsor_id).get("conduct_clause", false):
                sponsor_week_lost = true
                result["lines"].append("%s aplica la cláusula de conducta: no paga esta semana." % get_sponsor(sponsor_id)["name"])
        else:
            result["lines"].append("Nadie sacó fotos: la fiesta pasó piola.")
    else:
        var dec: Dictionary = ev.get("decline", {})
        discipline += int(dec.get("discipline", 0))
        popularity += int(dec.get("popularity", 0))
        result["lines"].append("Concentración en el hotel: disciplina %+d, popularidad %+d." % [
            int(dec.get("discipline", 0)), int(dec.get("popularity", 0))])
    popularity = clampi(popularity, 0, 100)
    discipline = clampi(discipline, 0, 100)
    event_result = result
    return result


# El funado es un titular con carta propia en el mazo (así el desgaste extra importa); si no hay, cualquier titular.
func _pick_funado() -> Dictionary:
    var starters := squads.pick_starters(team_id)
    var owners := {}
    for c in build_deck():
        owners[c.owner_id] = true
    var candidates: Array = starters.filter(func(p): return owners.has(p["id"]))
    if candidates.is_empty():
        candidates = starters
    return {} if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]


# ------------------------------------------------------------------ Bloque 2: entrenamiento

func training_terms(kind: String) -> String:
    var t: Dictionary = data.get("training", {}).get(kind, {})
    var parts: Array = []
    if float(t.get("form_bonus", 0.0)) > 0.0:
        parts.append("+%d%% de acierto en todo el partido" % roundi(float(t["form_bonus"]) * 100.0))
    parts.append("fatiga %+d" % int(t.get("fatigue", 0)))
    return "%s: %s." % [t.get("name", kind), ", ".join(parts)]


func choose_training(kind: String) -> bool:
    if pending_match or not data.get("training", {}).has(kind):
        return false
    training = kind
    return true


# ------------------------------------------------------------------ Bloque 3: partido

func build_deck() -> Array:
    return squads.build_match_deck(team_id, templates)


func blocks_done() -> Dictionary:
    return {"block1": sponsor_id != "" and not event_result.is_empty(), "block2": training != ""}


# Valida todo antes de ir al partido. Bloquean: bloques sin completar, reglas de liga del mazo
# (validate_deck), tamaño del mazo y reglas del plantel. La masa salarial solo avisa.
func prepare_match() -> Dictionary:
    var errors: Array = []
    if sponsor_id == "":
        errors.append("Bloque 1: elige un sponsor.")
    if event_result.is_empty():
        errors.append("Bloque 1: resuelve el evento de la semana.")
    if training == "":
        errors.append("Bloque 2: elige entrenamiento o kinesiología.")
    if rival_id == "":
        errors.append("No hay rival disponible en la división.")
    var deck := build_deck()
    var check := league.validate_deck(deck, LEAGUE_ID)
    errors.append_array(check["errors"])
    var size_error := DeckManager.new(deck, [], rng).size_error()
    if size_error != "":
        errors.append(size_error)
    errors.append_array(squads.squad_errors(team_id))

    var warnings: Array = []
    var payroll := league.payroll_for_deck(deck, LEAGUE_ID, team_id)
    var cap := budget * float(league.get_league(LEAGUE_ID).get("salary", {}).get("max_payroll_pct_of_budget", 1.0))
    if payroll > cap:
        warnings.append("Masa salarial $%.0f M sobre el tope de $%.0f M (sin sanción por ahora)." % [payroll, cap])

    if errors.is_empty() and not pending_match:
        var t: Dictionary = data.get("training", {}).get(training, {})
        match_mods["form_bonus"] = float(t.get("form_bonus", 0.0))
        fatigue = clampf(fatigue + float(t.get("fatigue", 0)), 0.0, 100.0)
        pending_match = true
    return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "check": check, "deck_size": deck.size()}


# Aplica la semana al partido. Llamar antes de engine.start() (la fatiga define la energía inicial).
func configure_match(engine: MatchEngine, player: PlayerStats) -> void:
    player.fatigue = fatigue
    player.lineup = squads.lineup_ids(team_id)
    if match_mods.has("opening_bonus"):
        engine.opening_bonus = match_mods["opening_bonus"]
        engine.opening_moments = match_mods.get("opening_moments", 2)
    engine.form_bonus = match_mods.get("form_bonus", 0.0)
    if match_mods.get("funado_id", "") != "":
        engine.owner_stamina_mult = {match_mods["funado_id"]: match_mods.get("funado_stamina_mult", 1.5)}


# Cierra la semana con el resultado: paga al sponsor, suma fatiga y avanza a la siguiente.
func record_match(gf: int, ga: int) -> Dictionary:
    if not pending_match:
        return {}
    var m: Dictionary = data.get("match", {})
    var offer := sponsor_offer(get_sponsor(sponsor_id))
    var income := 0 if sponsor_week_lost else int(offer["weekly"])
    if gf > ga:
        income += int(offer["win_bonus"])
        popularity += int(m.get("popularity_win", 0))
    elif gf < ga:
        popularity += int(m.get("popularity_loss", 0))
    popularity = clampi(popularity, 0, 100)
    budget += income
    fatigue = clampf(fatigue + float(m.get("fatigue", 0)), 0.0, 100.0)
    var entry := {"week": week, "rival_id": rival_id, "gf": gf, "ga": ga, "income": income}
    history.append(entry)
    week += 1
    _new_week()
    return entry
