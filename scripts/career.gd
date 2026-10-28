class_name Career
extends RefCounted

# Estado del modo carrera y reglas de la semana: Bloque 1 (sponsor y evento social), Bloque 2
# (UNA entre entrenamiento táctico, sesión de video o kinesiología, D-21) y Bloque 3 (validar el
# mazo e ir al partido). Tu mazo (`deck`) es tuyo: arranca con el de inicio de tu club y crece o
# mejora en el Bloque 2.
# Career.current sobrevive a los cambios de escena entre el calendario y el partido.
# Los números salen de data/career_2006.json; aquí solo se aplican.
# La carrera se guarda sola en Career.save_path (to_dict/save) y se recupera con load_saved().

static var current: Career
static var save_path := "user://carrera.json"   # las pruebas la cambian para no pisar la partida real
static var last_load_errors: Array = []         # motivo del último load_saved() que devolvió null

const DATA_PATH := "res://data/career_2006.json"
const LEAGUE_ID := "chile_2006"
const SAVE_VERSION := 2
# Campos del guardado y su tipo tras pasar por JSON (los números vuelven como float). El rng va
# como texto porque seed y state son enteros de 64 bits que un float de JSON no conserva.
const SAVE_FIELDS := {
    "team_id": TYPE_STRING, "week": TYPE_FLOAT, "budget": TYPE_FLOAT, "popularity": TYPE_FLOAT,
    "discipline": TYPE_FLOAT, "fatigue": TYPE_FLOAT, "sponsor_id": TYPE_STRING, "history": TYPE_ARRAY,
    "event_result": TYPE_DICTIONARY, "training": TYPE_STRING, "match_mods": TYPE_DICTIONARY,
    "sponsor_week_lost": TYPE_BOOL, "rival_id": TYPE_STRING, "pending_match": TYPE_BOOL,
    "rng_seed": TYPE_STRING, "rng_state": TYPE_STRING, "deck": TYPE_ARRAY, "training_offer": TYPE_ARRAY,
}
const V1_MISSING := ["deck", "training_offer"]   # los guardados v1 (antes de T-05) no los traen: se migran
const HISTORY_INTS := ["week", "gf", "ga", "income", "fatigue_gained"]
const MATCH_MODS_INTS := ["opening_moments"]
const TRAINING_KINDS := ["tactical", "video", "physio"]   # opciones del Bloque 2, en el orden del calendario
const OFFER_SIZE := 3    # cartas que ofrece el entrenamiento táctico (D-20)
const OFFER_STYLE := 2   # de ellas, de la lista de tu arquetipo; el resto, de la general

var league: LeagueManager
var squads: SquadManager
var data := {}
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
# Tu mazo: tus cartas del DT, una entrada por copia {id, mejora: "" | "acierto" | "pa"}. Las firmas
# de los titulares no van aquí: las suma SquadManager al armar el mazo del partido (build_deck).
var deck: Array = []

# Semana en curso
var event_result := {}     # vacío = evento sin resolver
var training := ""         # Bloque 2 resuelto: "" | "tactical" | "video" | "physio"
var training_offer: Array = []   # ids de las cartas que ofrece el táctico esta semana (new_offer)
var match_mods := {}       # opening_bonus, opening_moments, funado_id, funado_stamina_mult
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
    deck = starter_deck()
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
    training_offer = new_offer()   # se guarda: recargar no cambia las opciones de la semana


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


# ------------------------------------------------------------------ Tu mazo

# Mazo de inicio de tu club (D-23) como entradas de `deck`: sus cartas del DT, sin mejoras.
func starter_deck() -> Array:
    var out: Array = []
    for t in squads.starter_templates(team_id):
        out.append({"id": String(t["id"]), "mejora": ""})
    return out


# Tus cartas del DT con sus mejoras (CardDB.upgraded), en el orden de `deck`, listas para SquadManager.
func deck_templates() -> Array:
    return _templates_for(deck)


func _templates_for(entries: Array) -> Array:
    var out: Array = []
    for e in entries:
        out.append(CardDB.upgraded(squads.catalog[e["id"]], String(e["mejora"])))
    return out


# Tu mazo del partido: tus cartas del DT (las Promesas pasan a Sub-21 del plantel) + las firmas de
# tus titulares, armado por SquadManager. Las primeras deck.size() cartas son las de `deck`, en orden.
func build_deck() -> Array:
    return squads.build_match_deck(team_id, deck_templates())


# Cartas del DT del rival de la semana (D-22, T-06): su mazo de inicio + las primeras week − 1 cartas
# del crecimiento de su arquetipo, en orden (SquadManager.season_templates, lo mismo que miden las
# etapas de sim.gd). Se deriva de la semana, sin guardar nada; season_templates lo topa para que su
# mazo del partido no pase de DeckManager.DECK_MAX. Solo suma cartas: mejorarlas queda para después.
func rival_templates(id: String = rival_id) -> Array:
    return squads.season_templates(id, week - 1)


# Mazo del partido del rival: rival_templates + sus Promesas asignadas y las firmas de sus titulares.
func build_rival_deck(id: String = rival_id) -> Array:
    return squads.build_match_deck(id, rival_templates(id))


# Cartas del mazo del partido: tus cartas del DT + las firmas de los titulares.
func deck_size() -> int:
    return deck.size() + squads.signature_count(team_id)


# En el tope (DeckManager.DECK_MAX), una carta nueva tiene que reemplazar a otra (D-20).
func deck_full() -> bool:
    return deck_size() >= DeckManager.DECK_MAX


# ------------------------------------------------------------------ Bloque 2: entrenamiento

func training_terms(kind: String) -> String:
    var t: Dictionary = data.get("training", {}).get(kind, {})
    var parts: Array = []
    if kind == "tactical":
        parts.append("te quedas con 1 de %d cartas nuevas" % OFFER_SIZE)
    elif kind == "video":
        parts.append("mejoras una carta: +%d de acierto o −%d PA" % [roundi(CardDB.UPGRADE_BONUS * 100.0), CardDB.UPGRADE_AP])
    var fatigue_change := int(t.get("fatigue", 0))
    parts.append("fatiga %+d" % fatigue_change if fatigue_change != 0 else "sin fatiga")
    var start := start_stamina_preview(float(fatigue_change))
    return "%s: %s → arrancas con %d%% de estamina, %s (Mano: %d)." % [
        t.get("name", kind), ", ".join(parts), start["pct"], start["zone"], start["hand"]]


# Con cuánta Estamina Global arrancaría el partido si la fatiga cambia en `extra` (lo mismo que
# hace PlayerStats.start_match_energy con la fatiga de la semana). {pct, zone, hand}.
func start_stamina_preview(extra: float = 0.0) -> Dictionary:
    var p := PlayerStats.new()
    p.fatigue = clampf(fatigue + extra, 0.0, 100.0)
    p.start_match_energy()
    var zone_name: String = {PlayerStats.Zone.SAFE: "ÓPTIMO", PlayerStats.Zone.TIRED: "CANSADO",
            PlayerStats.Zone.EXHAUSTED: "AGOTADO"}[p.zone()]
    return {"pct": roundi(p.energy_pct() * 100.0), "zone": zone_name, "hand": p.draw_count()}


# Bloque 2 abierto: ninguna opción resuelta y el partido sin empezar. Cada opción es final.
func block2_open() -> bool:
    return training == "" and not pending_match


# Kinesiología: −25 de fatiga antes del partido, sin elegir nada más.
func choose_physio() -> bool:
    if not block2_open():
        return false
    training = "physio"
    return true


# Las cartas del entrenamiento táctico (D-20): OFFER_STYLE distintas de la lista de tu arquetipo y el
# resto de la general (decks.json "ofertas"), sin repetir entre ellas y nunca una carta de rasgo.
# Puede ofrecer una carta que ya tienes (segunda copia). Sale del rng de la carrera: misma semilla,
# mismas ofertas.
func new_offer() -> Array:
    var lists: Dictionary = squads.deck_lists.get("ofertas", {})
    var traits: Array = squads.deck_lists.get("rasgos", {}).values()
    var offer: Array = []
    _draw_offer(offer, lists.get(String(team()["archetype"]), []), OFFER_STYLE, traits)
    _draw_offer(offer, lists.get("general", []), OFFER_SIZE - offer.size(), traits)
    return offer


func _draw_offer(offer: Array, pool: Array, n: int, excluded: Array) -> void:
    var candidates: Array = []
    for id in pool:
        if not excluded.has(id) and not offer.has(id) and not candidates.has(id) and squads.catalog.has(id):
            candidates.append(String(id))
    for i in mini(n, candidates.size()):
        offer.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))


# Te quedas con la carta `offer_index` de la oferta: se agrega a tu mazo. Con el mazo en su tope hay
# que elegir cuál de tus cartas del DT sale (`replace_index`, ver replace_error); con espacio no se
# reemplaza nada.
func take_offer(offer_index: int, replace_index: int = -1) -> bool:
    if not block2_open() or offer_index < 0 or offer_index >= training_offer.size():
        return false
    var entry := {"id": String(training_offer[offer_index]), "mejora": ""}
    if deck_full():
        if replace_error(offer_index, replace_index) != "":
            return false
        deck[replace_index] = entry
    elif replace_index != -1:
        return false
    else:
        deck.append(entry)
    training = "tactical"
    return true


# "" si la carta `offer_index` puede entrar en lugar de tu carta `replace_index`; si no, el motivo.
# No vale un reemplazo que deja el mazo fuera de las reglas de liga (validate_deck: sacar una
# Promesa puede dejarte con menos de 2 Sub-21), porque esas cartas no se pueden recuperar.
func replace_error(offer_index: int, replace_index: int) -> String:
    if offer_index < 0 or offer_index >= training_offer.size():
        return "Esa carta no está en la oferta."
    if replace_index < 0 or replace_index >= deck.size():
        return "Elige cuál de tus cartas sale."
    var trial := deck.duplicate(true)
    trial[replace_index] = {"id": String(training_offer[offer_index]), "mejora": ""}
    var check := league.validate_deck(squads.build_match_deck(team_id, _templates_for(trial)), LEAGUE_ID)
    return "" if check["valid"] else " ".join(check["errors"])


# No te quedas con ninguna: igual cuenta como el Bloque 2 de la semana.
func decline_offer() -> bool:
    if not block2_open():
        return false
    training = "tactical"
    return true


# ------------------------------------------------------------------ Bloque 2: sesión de video

# ¿Se le puede dar `mejora` ("acierto" o "pa", CardDB.UPGRADES) a tu carta `index`? Una por carta.
func can_upgrade(index: int, mejora: String) -> bool:
    return index >= 0 and index < deck.size() and String(deck[index]["mejora"]) == "" \
            and CardDB.can_upgrade(squads.catalog[deck[index]["id"]], mejora)


func upgrade_card(index: int, mejora: String) -> bool:
    if not block2_open() or not can_upgrade(index, mejora):
        return false
    deck[index]["mejora"] = mejora
    training = "video"
    return true


# ------------------------------------------------------------------ Bloque 3: partido

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
        errors.append("Bloque 2: elige entrenamiento táctico, sesión de video o kinesiología.")
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
        fatigue = clampf(fatigue + float(t.get("fatigue", 0)), 0.0, 100.0)
        pending_match = true
    return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "check": check, "deck_size": deck.size()}


# Aplica la semana al partido. Llamar antes de engine.start(): la fatiga define con cuánta Estamina
# Global se arranca, y el funado gasta más estamina en sus cartas (owner_stamina_mult). El
# entrenamiento ya no da forma (D-21): lo que deja es la carta nueva o la mejora, que van en el mazo.
func configure_match(engine: MatchEngine, player: PlayerStats) -> void:
    player.fatigue = fatigue
    player.lineup = squads.lineup_ids(team_id)
    if match_mods.has("opening_bonus"):
        engine.opening_bonus = match_mods["opening_bonus"]
        engine.opening_moments = match_mods.get("opening_moments", 2)
    if match_mods.get("funado_id", "") != "":
        engine.owner_stamina_mult = {match_mods["funado_id"]: match_mods.get("funado_stamina_mult", 1.5)}


# Nombre del funado de esta semana ("" si no hay funa).
func funado_name() -> String:
    var id: String = match_mods.get("funado_id", "")
    return "" if id == "" else String(squads.find_player(team_id, id).get("name", id))


# Cierra la semana con el resultado: paga al sponsor, suma fatiga según la estamina que quedó
# (end_stamina_pct, 0-1) y avanza a la siguiente.
func record_match(gf: int, ga: int, end_stamina_pct: float = 0.5) -> Dictionary:
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
    var wear := 1.0 - clampf(end_stamina_pct, 0.0, 1.0)
    var gained := float(m.get("fatigue_base", 0)) + float(m.get("fatigue_from_wear", 0)) * wear
    fatigue = clampf(fatigue + gained, 0.0, 100.0)
    var entry := {"week": week, "rival_id": rival_id, "gf": gf, "ga": ga, "income": income,
        "fatigue_gained": roundi(gained)}
    history.append(entry)
    week += 1
    _new_week()
    return entry


# ------------------------------------------------------------------ Guardado

func to_dict() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "team_id": team_id,
        "week": week,
        "budget": budget,
        "popularity": popularity,
        "discipline": discipline,
        "fatigue": fatigue,
        "sponsor_id": sponsor_id,
        "history": history.duplicate(true),
        "event_result": event_result.duplicate(true),
        "training": training,
        "match_mods": match_mods.duplicate(true),
        "sponsor_week_lost": sponsor_week_lost,
        "rival_id": rival_id,
        "pending_match": pending_match,
        "rng_seed": str(rng.seed),
        "rng_state": str(rng.state),
        "deck": deck.duplicate(true),
        "training_offer": training_offer.duplicate(),
    }


# Escribe la carrera en `path` (por defecto Career.save_path). Devuelve false si no se pudo escribir.
func save(path: String = "") -> bool:
    var f := FileAccess.open(path if path != "" else save_path, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(to_dict(), "\t"))
    f.close()
    return true


# Carga la carrera guardada en `path` (por defecto Career.save_path): setup() con el club guardado
# (recarga los JSON del juego) y después el estado. Si el archivo no existe, no es JSON, trae otra
# versión, un club desconocido o un campo inválido (también una carta del mazo o de la oferta que no
# está en el catálogo), devuelve null y deja el motivo en Career.last_load_errors, sin errores de
# script. Un guardado v1 (antes de T-05) se migra: mazo de inicio del club y oferta nueva.
static func load_saved(p_league: LeagueManager, p_squads: SquadManager, path: String = "") -> Career:
    last_load_errors = []
    if path == "":
        path = save_path
    if not FileAccess.file_exists(path):
        last_load_errors.append("No hay carrera guardada.")
        return null
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        last_load_errors.append("No se pudo abrir %s." % path)
        return null
    var json := JSON.new()
    if json.parse(f.get_as_text()) != OK:
        last_load_errors.append("El guardado no es JSON válido (línea %d: %s)." % [json.get_error_line(), json.get_error_message()])
        return null
    if not (json.data is Dictionary):
        last_load_errors.append("El guardado no tiene el formato esperado.")
        return null
    var d: Dictionary = json.data
    var version := int(d["version"]) if typeof(d.get("version")) == TYPE_FLOAT else -1
    if version != SAVE_VERSION and version != 1:
        last_load_errors.append("Versión de guardado %s no compatible (se espera %d)." % [d.get("version"), SAVE_VERSION])
        return null
    var migrate := version == 1
    for key in SAVE_FIELDS:
        if migrate and key in V1_MISSING:
            continue
        if typeof(d.get(key)) != SAVE_FIELDS[key]:
            last_load_errors.append("Campo inválido en el guardado: %s." % key)
            return null
    if not (String(d["rng_seed"]).is_valid_int() and String(d["rng_state"]).is_valid_int()):
        last_load_errors.append("Estado del azar inválido en el guardado.")
        return null
    for h in d["history"]:
        if not (h is Dictionary):
            last_load_errors.append("Campo inválido en el guardado: history.")
            return null

    var c := Career.new()
    if not c.setup(p_league, p_squads, String(d["team_id"]), 1):
        last_load_errors.append_array(c.load_errors)
        return null
    var sponsor := String(d["sponsor_id"])
    var kind := String(d["training"])
    if (sponsor != "" and c.get_sponsor(sponsor).is_empty()) or (kind != "" and not c.data.get("training", {}).has(kind)):
        last_load_errors.append("El guardado trae un sponsor o un entrenamiento desconocido.")
        return null
    if not migrate:
        var entries := _read_deck(d["deck"], c.squads.catalog)
        if entries.is_empty() and not d["deck"].is_empty():
            last_load_errors.append("El mazo guardado trae una carta o una mejora desconocida.")
            return null
        c.deck = entries
        if c.deck_size() < DeckManager.DECK_MIN or c.deck_size() > DeckManager.DECK_MAX:
            last_load_errors.append("El mazo guardado tiene %d cartas (deben ser %d-%d)." % [
                c.deck_size(), DeckManager.DECK_MIN, DeckManager.DECK_MAX])
            return null
        c.training_offer = []
        for id in d["training_offer"]:
            if typeof(id) != TYPE_STRING or not c.squads.catalog.has(id):
                last_load_errors.append("La oferta del entrenamiento guardada trae una carta desconocida.")
                return null
            c.training_offer.append(String(id))
    c.week = int(d["week"])
    c.budget = float(d["budget"])
    c.popularity = int(d["popularity"])
    c.discipline = int(d["discipline"])
    c.fatigue = float(d["fatigue"])
    c.sponsor_id = sponsor
    c.history = []
    for h in d["history"]:
        c.history.append(_with_ints(h, HISTORY_INTS))
    c.event_result = d["event_result"]
    c.training = kind
    c.match_mods = _with_ints(d["match_mods"], MATCH_MODS_INTS)
    c.sponsor_week_lost = d["sponsor_week_lost"]
    c.rival_id = String(d["rival_id"])
    c.pending_match = d["pending_match"]
    c.rng.seed = String(d["rng_seed"]).to_int()
    c.rng.state = String(d["rng_state"]).to_int()   # después de seed: asignar seed reinicia el state
    if migrate:
        # v1: el mazo era el de inicio (ya lo puso setup) y el táctico daba forma. Un táctico elegido
        # sin partido pendiente vuelve a elegirse con las reglas nuevas; la oferta sale del azar guardado.
        c.match_mods.erase("form_bonus")
        if c.training == "tactical" and not c.pending_match:
            c.training = ""
        c.training_offer = c.new_offer()
    return c


# Entradas del mazo guardado, copiadas como {id, mejora}; [] si alguna no es válida (carta fuera del
# catálogo o mejora que la carta no admite).
static func _read_deck(saved: Array, catalog: Dictionary) -> Array:
    var out: Array = []
    for e in saved:
        if not (e is Dictionary and typeof(e.get("id")) == TYPE_STRING and catalog.has(e["id"]) \
                and typeof(e.get("mejora")) == TYPE_STRING):
            return []
        var mejora := String(e["mejora"])
        if mejora != "" and not CardDB.can_upgrade(catalog[e["id"]], mejora):
            return []
        out.append({"id": String(e["id"]), "mejora": mejora})
    return out


# JSON devuelve todos los números como float: vuelve a entero los campos que lo son.
static func _with_ints(src: Dictionary, keys: Array) -> Dictionary:
    var out := src.duplicate(true)
    for k in keys:
        if typeof(out.get(k)) == TYPE_FLOAT:
            out[k] = int(out[k])
    return out
