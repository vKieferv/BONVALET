class_name Career
extends RefCounted

# Estado del modo carrera y reglas de la semana: Bloque 1 (sponsor y evento de la semana, T-14), Bloque 2
# (UNA entre entrenamiento táctico, sesión de video o kinesiología, D-21) y Bloque 3 (validar el
# mazo e ir al partido). Tu mazo (`deck`) es tuyo: arranca con el de inicio de tu club y crece o
# mejora en el Bloque 2.
# Career.current sobrevive a los cambios de escena entre el calendario y el partido.
# Los números salen de data/career_2006.json y data/eventos_2006.json; aquí solo se aplican.
# La carrera se guarda sola en Career.save_path (to_dict/save) y se recupera con load_saved().

static var current: Career
static var save_path := "user://carrera.json"   # las pruebas la cambian para no pisar la partida real
static var last_load_errors: Array = []         # motivo del último load_saved() que devolvió null

const DATA_PATH := "res://data/career_2006.json"
const EVENTS_PATH := "res://data/eventos_2006.json"
const LEAGUE_ID := "chile_2006"
const SAVE_VERSION := 3
# Campos del guardado y su tipo tras pasar por JSON (los números vuelven como float). El rng va
# como texto porque seed y state son enteros de 64 bits que un float de JSON no conserva.
const SAVE_FIELDS := {
    "team_id": TYPE_STRING, "week": TYPE_FLOAT, "budget": TYPE_FLOAT, "popularity": TYPE_FLOAT,
    "discipline": TYPE_FLOAT, "fatigue": TYPE_FLOAT, "sponsor_id": TYPE_STRING, "history": TYPE_ARRAY,
    "event_result": TYPE_DICTIONARY, "training": TYPE_STRING, "match_mods": TYPE_DICTIONARY,
    "sponsor_week_lost": TYPE_BOOL, "rival_id": TYPE_STRING, "pending_match": TYPE_BOOL,
    "rng_seed": TYPE_STRING, "rng_state": TYPE_STRING, "deck": TYPE_ARRAY, "training_offer": TYPE_ARRAY,
    "event_id": TYPE_STRING, "event_names": TYPE_DICTIONARY, "event_deck": TYPE_ARRAY, "event_marks": TYPE_ARRAY,
    "promises": TYPE_ARRAY, "temp_cards": TYPE_ARRAY, "sold": TYPE_ARRAY,
}
const V1_MISSING := ["deck", "training_offer"]   # los guardados v1 (antes de T-05) no los traen: se migran
# Los guardados v1 y v2 (antes de T-14) no traen los eventos: se migran con el Bautizazo, el único de entonces.
const V2_MISSING := ["event_id", "event_names", "event_deck", "event_marks", "promises", "temp_cards", "sold"]
const HISTORY_INTS := ["week", "gf", "ga", "income", "fatigue_gained"]
const MATCH_MODS_INTS := ["opening_moments", "rival_moments"]
# Efectos de una opción de evento (data/eventos_2006.json, tabla 1 de docs/eventos.md).
const EFFECTS := ["popularidad", "disciplina", "presupuesto", "fatiga", "arranque", "rival_motivado", "funa",
    "desgaste", "carta_temporal", "carta_nueva", "promesa", "rama", "azar", "sin_pago_sponsor", "vender"]
# Nombres entre corchetes del texto de un evento → a quién se refieren (_target). [el rival] es aparte.
const PLACEHOLDERS := {"[tu 9]": "nueve", "[el capitán]": "capitan", "[el arquero]": "arquero",
    "[el juvenil]": "juvenil", "[un titular]": "titular", "[el nuevo]": "nuevo"}
const CONDITIONS := ["", "tras_derrota", "antes_de_clasico"]
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
var events := {}           # data/eventos_2006.json: medios, clasicos y eventos
# Mazo de eventos (T-14): ids por salir, barajados con el rng al empezar la temporada; se vuelve a
# barajar cuando se acaba. Las ramas pendientes vuelven en su semana con el evento que abren.
var event_deck: Array = []
var event_marks: Array = []   # [{evento, semana, nombres, origen}]
var promises: Array = []      # promesas por cobrar en el próximo partido: [{evento, si_ganas, si_no}]
var sold: Array = []          # jugadores vendidos (efecto vender): su carta firma ya no entra al mazo

# Semana en curso
var event_id := ""         # evento de la semana
var event_names := {}      # quien -> id del jugador ("nueve", "capitan"...), resuelto al sacar el evento
var temp_cards: Array = [] # cartas de esta semana: [{carta, quien}] (nervios o una carta del catálogo)
var event_result := {}     # vacío = evento sin resolver
var training := ""         # Bloque 2 resuelto: "" | "tactical" | "video" | "physio"
var training_offer: Array = []   # ids de las cartas que ofrece el táctico esta semana (new_offer)
# opening_bonus/opening_moments (arranque, también negativo), rival_bonus/rival_moments (rival
# motivado), funado_id/funado_stamina_mult (funa) y owner_mults {id: multiplicador} (desgaste)
var match_mods := {}
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
    parsed = null
    if FileAccess.file_exists(EVENTS_PATH):
        parsed = JSON.parse_string(FileAccess.open(EVENTS_PATH, FileAccess.READ).get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Eventos inválidos: %s" % EVENTS_PATH)
        return false
    events = parsed
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
    event_deck = []   # se baraja al sacar el primer evento de la temporada
    event_marks = []
    promises = []
    sold = []
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
    temp_cards = []
    rival_id = next_rival()
    training_offer = new_offer()   # se guarda: recargar no cambia las opciones de la semana
    _draw_event()


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


# ------------------------------------------------------------------ Bloque 1: evento de la semana

# Catálogo de eventos (data/eventos_2006.json, T-14). Cada semana trae uno: primero una rama que vence
# esta semana; si no, uno del mazo de la temporada (_draw_event). Cada opción es una lista de efectos
# (EFFECTS) que se ven antes de elegir (effect_badges, effects_text) y se aplican en resolve_event.

func get_event(id: String) -> Dictionary:
    for ev in events.get("eventos", []):
        if ev["id"] == id:
            return ev
    return {}


func get_medio(id: String) -> Dictionary:
    for m in events.get("medios", []):
        if m["id"] == id:
            return m
    return {}


func week_event() -> Dictionary:
    return get_event(event_id)


# Medio que cuenta o pregunta el evento de la semana.
func week_medio() -> Dictionary:
    return get_medio(String(week_event().get("medio", "")))


func is_clasico(a: String, b: String) -> bool:
    for pair in events.get("clasicos", []):
        if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
            return true
    return false


func condition_met(ev: Dictionary) -> bool:
    match String(ev.get("condicion", "")):
        "tras_derrota":
            return not history.is_empty() and int(history[-1]["gf"]) < int(history[-1]["ga"])
        "antes_de_clasico":
            return is_clasico(team_id, rival_id)
    return true


# Evento de la semana: la rama vencida más antigua (hereda los nombres del evento que la abrió); si no
# hay, del mazo de la temporada un evento con condición que se cumpla (después de una derrota, antes
# de un clásico) y si no, el primero sin condición. Con el mazo vacío se vuelve a barajar entero.
func _draw_event() -> void:
    event_id = ""
    event_names = {}
    var due := -1
    for i in event_marks.size():
        if int(event_marks[i]["semana"]) <= week and (due == -1 or int(event_marks[i]["semana"]) < int(event_marks[due]["semana"])):
            due = i
    if due != -1:
        var mark: Dictionary = event_marks.pop_at(due)
        event_id = String(mark["evento"])
        event_names = mark.get("nombres", {}).duplicate()
    else:
        event_id = _take_from_deck()
        if event_id == "":
            event_deck = _shuffled_events()
            event_id = _take_from_deck()
    _resolve_names(week_event())


# Pone `id` como evento de la semana sin resolver (pruebas y capturas). false si no existe o ya se resolvió.
func set_week_event(id: String) -> bool:
    if get_event(id).is_empty() or not event_result.is_empty() or pending_match:
        return false
    event_id = id
    event_names = {}
    _resolve_names(week_event())
    return true


func _take_from_deck() -> String:
    for pass_conditional in [true, false]:
        for i in event_deck.size():
            var ev := get_event(String(event_deck[i]))
            if (String(ev.get("condicion", "")) != "") == pass_conditional and condition_met(ev):
                return String(event_deck.pop_at(i))
    return ""


# Los eventos que entran al mazo (sin los que solo llegan por una rama), barajados con el rng de la carrera.
func _shuffled_events() -> Array:
    var ids: Array = []
    for ev in events.get("eventos", []):
        if not ev.get("solo_rama", false):
            ids.append(String(ev["id"]))
    for i in range(ids.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = ids[i]
        ids[i] = ids[j]
        ids[j] = tmp
    return ids


# Resuelve al sacar el evento a quién nombra su texto y sus efectos, así lo que se lee es lo que pasa.
func _resolve_names(ev: Dictionary) -> void:
    var text := String(ev.get("titulo", "")) + String(ev.get("texto", ""))
    for token in PLACEHOLDERS:
        if text.contains(token):
            _target(PLACEHOLDERS[token])
    for op in ev.get("opciones", []):
        _resolve_effect_names(op.get("efectos", []))


func _resolve_effect_names(list: Array) -> void:
    for e in list:
        if e.has("quien"):
            _target(String(e["quien"]))
        for key in ["efectos", "si_no", "si_ganas"]:
            if e.has(key):
                _resolve_effect_names(e[key])


# El jugador al que se refiere `quien` esta semana (se elige una vez y se guarda en event_names).
func _target(quien: String) -> Dictionary:
    if event_names.has(quien):
        return squads.find_player(team_id, String(event_names[quien]))
    var p := _pick_target(quien)
    event_names[quien] = String(p.get("id", ""))
    return p


# nueve: un DEL titular, mejor si tiene carta firma (y no lo vendiste); capitan: el titular de más
# edad; arquero: el POR titular; juvenil: el Sub-21 más joven; titular: uno con carta en el mazo (como
# el funado de siempre); nuevo: otro titular al azar que no es el capitán.
func _pick_target(quien: String) -> Dictionary:
    var starters := squads.pick_starters(team_id)
    if starters.is_empty():
        return {}
    match quien:
        "nueve":
            var dels: Array = starters.filter(func(p): return p["role"] == "DEL" and not sold.has(p["id"]))
            for p in dels:
                if not squads.signature_card_for(p).is_empty():
                    return p
            return dels[0] if not dels.is_empty() else starters[-1]
        "capitan":
            var by_age := starters.duplicate()
            by_age.sort_custom(func(a, b): return _age(a) > _age(b))
            return by_age[0]
        "arquero":
            for p in starters:
                if p["role"] == "POR":
                    return p
            return starters[0]
        "juvenil":
            var squad := squads.get_squad(team_id).duplicate()
            squad.sort_custom(func(a, b): return _age(a) < _age(b))
            return squad[0] if not squad.is_empty() else starters[0]
        "titular":
            return _pick_funado()
        "nuevo":
            var cap := String(event_names.get("capitan", ""))
            var others: Array = starters.filter(func(p): return p["id"] != cap)
            return others[rng.randi_range(0, others.size() - 1)]
    return {}


static func _age(p: Dictionary) -> int:
    return int(p["age"]) if p.get("age") != null else 0


# Nombre de un `quien` de esta semana ("" si no hay).
func target_name(quien: String) -> String:
    var id := String(event_names.get(quien, ""))
    return "" if id == "" else String(squads.find_player(team_id, id).get("name", id))


# Texto con los nombres entre corchetes ya llenados con el plantel y el rival de la semana.
func fill_names(text: String) -> String:
    for token in PLACEHOLDERS:
        if text.contains(token):
            text = text.replace(token, target_name(PLACEHOLDERS[token]))
    if text.contains("[el rival]"):
        text = text.replace("[el rival]", String(league.get_team(rival_id).get("short_name", "el rival")))
    return text


func event_title(ev: Dictionary = week_event()) -> String:
    return fill_names(String(ev.get("titulo", "Sin novedades")))


func event_text(ev: Dictionary = week_event()) -> String:
    return fill_names(String(ev.get("texto", "")))


func event_options(ev: Dictionary = week_event()) -> Array:
    return ev.get("opciones", [])


# Sello de la opción elegida (lo que se timbra sobre la foto del diario).
func option_stamp(op: Dictionary) -> String:
    if op.has("sello"):
        return String(op["sello"])
    return fill_names(String(op.get("texto", ""))).to_upper()


# Lo que hace cada efecto, como timbres de la mesa: [{texto, icono, tono}] (tono 1 suma, −1 resta o
# es riesgo, 0 neutro). Así se ven los efectos antes de elegir (pilar 2).
func effect_badges(list: Array) -> Array:
    var out: Array = []
    for e in list:
        out.append(_badge(e))
    return out


func _badge(e: Dictionary) -> Dictionary:
    var v := float(e.get("valor", 0))
    var sign := 1 if v > 0 else (-1 if v < 0 else 0)
    match String(e["tipo"]):
        "popularidad":
            return {"texto": "%+d" % int(v), "icono": "megafono", "tono": sign}
        "disciplina":
            return {"texto": "%+d" % int(v), "icono": "tarjeta", "tono": sign}
        "presupuesto":
            return {"texto": "%s$%d M" % ["+" if v >= 0 else "−", absi(int(v))], "icono": "billete", "tono": sign}
        "fatiga":
            return {"texto": "%+d" % int(v), "icono": "bateria", "tono": -sign}
        "arranque":
            return {"texto": "%+d%% · M1-%d" % [roundi(v * 100.0), int(e.get("momentos", 2))], "icono": "mira", "tono": sign}
        "rival_motivado":
            return {"texto": "RIVAL %+d%%" % roundi(v * 100.0), "icono": "mira", "tono": -1}
        "funa":
            return {"texto": "%d%% FUNA" % roundi(float(e.get("chance", 1.0)) * 100.0), "icono": "dado", "tono": -1}
        "desgaste":
            return {"texto": "+%d%% · %s" % [roundi(float(e.get("extra", 0.5)) * 100.0), _short(String(e["quien"]))], "icono": "gota", "tono": -1}
        "carta_temporal":
            var bad := String(e["carta"]) == "nervios"
            # Nombre corto de la carta (lo de antes de los dos puntos: "Promesa: Control" → PROMESA).
            var card_name := "NERVIOS" if bad else String(squads.catalog.get(String(e["carta"]), {}).get("name", e["carta"])).get_slice(":", 0).to_upper()
            return {"texto": "%s · %s" % [card_name, _short(String(e["quien"]))], "icono": "carta", "tono": -1 if bad else 1}
        "carta_nueva":
            return {"texto": "CARTA NUEVA", "icono": "carta", "tono": 1}
        "promesa":
            var win: Array = effect_badges(e.get("si_ganas", [])).map(func(b): return b["texto"])
            var lose: Array = effect_badges(e.get("si_no", [])).map(func(b): return b["texto"])
            return {"texto": "GANAS %s · SI NO %s" % [" ".join(win), " ".join(lose)], "icono": "estrella", "tono": 0}
        "rama":
            var chance := float(e.get("chance", 1.0))
            var weeks := int(e.get("semanas", 1))
            var when := "VUELVE EN %d SEM." % weeks
            return {"texto": when if chance >= 1.0 else "%d%%: %s" % [roundi(chance * 100.0), when], "icono": "reloj", "tono": 0}
        "azar":
            var inner: Array = effect_badges(e.get("efectos", []))
            var tone := 0
            for b in inner:
                tone += int(b["tono"])
            return {"texto": "%d%%: %s" % [roundi(float(e.get("chance", 0.5)) * 100.0), " ".join(inner.map(func(b): return b["texto"]))],
                "icono": "dado", "tono": signi(tone)}
        "sin_pago_sponsor":
            return {"texto": "CLÁUSULA: NO PAGA", "icono": "billete", "tono": -1}
        "vender":
            return {"texto": "VENDES A %s" % _short(String(e["quien"])), "icono": "billete", "tono": -1}
    return {"texto": String(e["tipo"]).to_upper(), "icono": "", "tono": 0}


func _short(quien: String) -> String:
    var n := target_name(quien)
    return quien.to_upper() if n == "" else SquadManager.short_name({"name": n}).to_upper()


# Lo mismo en palabras, una línea por efecto (tooltip del post-it).
func effects_text(list: Array) -> String:
    if list.is_empty():
        return "Sin efectos."
    var lines: Array = []
    for e in list:
        lines.append(_effect_line(e))
    return "\n".join(lines)


func _effect_line(e: Dictionary) -> String:
    var v := float(e.get("valor", 0))
    match String(e["tipo"]):
        "popularidad":
            return "Popularidad %+d." % int(v)
        "disciplina":
            return "Disciplina %+d." % int(v)
        "presupuesto":
            return "Caja del club %s$%d M." % ["+" if v >= 0 else "−", absi(int(v))]
        "fatiga":
            return "Fatiga del plantel %+d." % int(v)
        "arranque":
            return "%+d%% de acierto en los Momentos 1-%d del próximo partido." % [roundi(v * 100.0), int(e.get("momentos", 2))]
        "rival_motivado":
            return "El rival sale motivado: %+d%% de acierto en sus Momentos 1-%d." % [roundi(v * 100.0), int(e.get("momentos", 2))]
        "funa":
            return "Riesgo: %d%% de funa → disciplina %+d y %s con +%d%% de desgaste de estamina en sus cartas ese partido%s." % [
                roundi(float(e.get("chance", 1.0)) * 100.0), int(e.get("disciplina", 0)),
                "un titular" if String(e.get("quien", "titular")) == "titular" else _who(String(e["quien"])),
                roundi(float(e.get("extra", 0.5)) * 100.0),
                "; con un sponsor con cláusula de conducta, se pierde el pago de la semana" if e.get("clausula", false) else ""]
        "desgaste":
            return "%s gasta +%d%% de estamina en sus cartas el próximo partido." % [_who(String(e["quien"])), roundi(float(e.get("extra", 0.5)) * 100.0)]
        "carta_temporal":
            if String(e["carta"]) == "nervios":
                return "Una carta de Nervios de %s entra a tu mano en el próximo partido (no se juega, ocupa lugar)." % _who(String(e["quien"]))
            return "La carta %s entra a tu mazo esta semana." % String(squads.catalog.get(String(e["carta"]), {}).get("name", e["carta"]))
        "carta_nueva":
            return "Carta nueva para tu mazo: %s (si cabe)." % String(squads.catalog.get(String(e["carta"]), {}).get("name", e["carta"]))
        "promesa":
            return "Promesa: si ganas el próximo partido, %s Si no, %s" % [effects_text(e.get("si_ganas", [])).to_lower(),
                effects_text(e.get("si_no", [])).to_lower()]
        "rama":
            var chance := float(e.get("chance", 1.0))
            var weeks := int(e.get("semanas", 1))
            if chance >= 1.0:
                return "Esta historia vuelve en %d semana(s)." % weeks
            return "%d%%: esta historia vuelve en %d semana(s)." % [roundi(chance * 100.0), weeks]
        "azar":
            var line := "%d%%: %s" % [roundi(float(e.get("chance", 0.5)) * 100.0), effects_text(e.get("efectos", [])).replace("\n", " ")]
            if e.has("si_no"):
                line += " Si no: %s" % effects_text(e["si_no"]).replace("\n", " ")
            return line
        "sin_pago_sponsor":
            return "Si tu sponsor tiene cláusula de conducta, no paga esta semana."
        "vender":
            return "Vendes a %s: su carta firma sale de tu mazo." % _who(String(e["quien"]))
    return String(e["tipo"])


func _who(quien: String) -> String:
    var n := target_name(quien)
    return n if n != "" else {"titular": "un titular", "nueve": "tu 9", "capitan": "el capitán", "arquero": "el arquero",
        "juvenil": "el juvenil", "nuevo": "el nuevo"}.get(quien, quien)


# Elige la opción `option` del evento de la semana y aplica sus efectos. Devuelve
# {option, sello, funa, funado_id, lines}; una vez resuelto (o con el partido pendiente) no cambia.
func resolve_event(option: int) -> Dictionary:
    if not event_result.is_empty() or pending_match:
        return event_result
    var ops := event_options()
    if option < 0 or option >= ops.size():
        return {}
    var op: Dictionary = ops[option]
    var result := {"option": option, "sello": option_stamp(op), "funa": false, "funado_id": "", "lines": []}
    result["lines"].append("«%s»." % fill_names(String(op.get("texto", ""))))
    _apply_effects(op.get("efectos", []), result)
    popularity = clampi(popularity, 0, 100)
    discipline = clampi(discipline, 0, 100)
    event_result = result
    return result


func _apply_effects(list: Array, out: Dictionary) -> void:
    for e in list:
        _apply_effect(e, out)


func _apply_effect(e: Dictionary, out: Dictionary) -> void:
    var v := float(e.get("valor", 0))
    var lines: Array = out["lines"]
    match String(e["tipo"]):
        "popularidad":
            popularity += int(v)
            lines.append(_effect_line(e))
        "disciplina":
            discipline += int(v)
            lines.append(_effect_line(e))
        "presupuesto":
            budget += v
            lines.append(_effect_line(e))
        "fatiga":
            fatigue = clampf(fatigue + v, 0.0, 100.0)
            lines.append(_effect_line(e))
        "arranque":
            match_mods["opening_bonus"] = float(match_mods.get("opening_bonus", 0.0)) + v
            match_mods["opening_moments"] = maxi(int(match_mods.get("opening_moments", 0)), int(e.get("momentos", 2)))
            lines.append(_effect_line(e))
        "rival_motivado":
            match_mods["rival_bonus"] = float(match_mods.get("rival_bonus", 0.0)) + v
            match_mods["rival_moments"] = maxi(int(match_mods.get("rival_moments", 0)), int(e.get("momentos", 2)))
            lines.append(_effect_line(e))
        "funa":
            if rng.randf() < float(e.get("chance", 1.0)):
                var funado := _target(String(e.get("quien", "titular")))
                out["funa"] = true
                out["funado_id"] = funado.get("id", "")
                discipline += int(e.get("disciplina", 0))
                match_mods["funado_id"] = funado.get("id", "")
                match_mods["funado_stamina_mult"] = 1.0 + float(e.get("extra", 0.5))
                lines.append("¡FUNA! Diario El Chisme publica las fotos de %s: sus cartas gastan +%d%% de estamina. Disciplina %+d." % [
                    funado.get("name", "?"), roundi(float(e.get("extra", 0.5)) * 100.0), int(e.get("disciplina", 0))])
                if e.get("clausula", false) and get_sponsor(sponsor_id).get("conduct_clause", false):
                    sponsor_week_lost = true
                    lines.append("%s aplica la cláusula de conducta: no paga esta semana." % get_sponsor(sponsor_id)["name"])
            else:
                lines.append("Nadie sacó fotos: pasó piola.")
        "desgaste":
            var p := _target(String(e["quien"]))
            var mults: Dictionary = match_mods.get("owner_mults", {})
            mults[String(p.get("id", ""))] = 1.0 + float(e.get("extra", 0.5))
            match_mods["owner_mults"] = mults
            lines.append(_effect_line(e))
        "carta_temporal":
            var p := _target(String(e["quien"]))
            temp_cards.append({"carta": String(e["carta"]), "quien": String(p.get("id", ""))})
            lines.append(_effect_line(e))
        "carta_nueva":
            var id := String(e["carta"])
            if deck_full() or not squads.catalog.has(id):
                lines.append("No hay lugar en el mazo para %s." % String(squads.catalog.get(id, {}).get("name", id)))
            else:
                deck.append({"id": id, "mejora": ""})
                lines.append("Carta nueva en tu mazo: %s." % String(squads.catalog[id]["name"]))
        "promesa":
            promises.append({"evento": event_id, "si_ganas": e.get("si_ganas", []), "si_no": e.get("si_no", [])})
            lines.append(_effect_line(e))
        "rama":
            if rng.randf() < float(e.get("chance", 1.0)):
                event_marks.append({"evento": String(e["evento"]), "semana": week + int(e.get("semanas", 1)),
                    "nombres": event_names.duplicate(), "origen": event_id})
            lines.append("Esta historia puede volver.")
        "azar":
            _apply_effects(e.get("efectos", []) if rng.randf() < float(e.get("chance", 0.5)) else e.get("si_no", []), out)
        "sin_pago_sponsor":
            if get_sponsor(sponsor_id).get("conduct_clause", false):
                sponsor_week_lost = true
                lines.append("%s se enoja y aplica la cláusula: no paga esta semana." % get_sponsor(sponsor_id)["name"])
            else:
                lines.append("Tu sponsor no tiene cláusula de conducta: no pasa nada.")
        "vender":
            var p := _target(String(e["quien"]))
            if not sold.has(p.get("id", "")):
                sold.append(String(p.get("id", "")))
            lines.append(_effect_line(e))


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
# tus titulares, armado por SquadManager. Las primeras deck.size() cartas son las de `deck`, en orden;
# después, las cartas temporales buenas de la semana (si caben) y las firmas, sin las de los vendidos.
# Los Nervios de la semana no van aquí: entran en configure_match, después de validar el mazo.
func build_deck() -> Array:
    var templates := deck_templates()
    var room := DeckManager.DECK_MAX - deck_size()
    for t in temp_cards:
        if t["carta"] != "nervios" and squads.catalog.has(t["carta"]) and room > 0:
            templates.append(squads.catalog[t["carta"]].duplicate())
            room -= 1
    var out: Array = []
    var all := squads.build_match_templates(team_id, templates)
    for i in all.size():
        if i >= templates.size() and sold.has(String(all[i].get("owner_id", ""))):
            continue
        out.append(Card.from_dict(all[i]))
    return out


# Cartas del DT del rival de la semana (D-22, T-06): su mazo de inicio + las primeras week − 1 cartas
# del crecimiento de su arquetipo, en orden (SquadManager.season_templates, lo mismo que miden las
# etapas de sim.gd). Se deriva de la semana, sin guardar nada; season_templates lo topa para que su
# mazo del partido no pase de DeckManager.DECK_MAX. Solo suma cartas: mejorarlas queda para después.
func rival_templates(id: String = rival_id) -> Array:
    return squads.season_templates(id, week - 1)


# Mazo del partido del rival: rival_templates + sus Promesas asignadas y las firmas de sus titulares.
func build_rival_deck(id: String = rival_id) -> Array:
    return squads.build_match_deck(id, rival_templates(id))


# Cartas del mazo del partido: tus cartas del DT + las firmas de los titulares (sin los vendidos ni
# las cartas temporales de la semana).
func deck_size() -> int:
    var n := deck.size() + squads.signature_count(team_id)
    for p in squads.pick_starters(team_id):
        if sold.has(p["id"]) and not squads.signature_card_for(p).is_empty():
            n -= 1
    return n


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
    var mults: Dictionary = match_mods.get("owner_mults", {}).duplicate()
    if match_mods.get("funado_id", "") != "":
        mults[match_mods["funado_id"]] = match_mods.get("funado_stamina_mult", 1.5)
    if not mults.is_empty():
        engine.owner_stamina_mult = mults
    # Nervios de la semana: cartas de penalización en el mazo activo, después de validar su tamaño.
    for t in temp_cards:
        if t["carta"] == "nervios":
            var n := CardDB.make_penalty("nervios")
            var owner := String(squads.find_player(team_id, String(t["quien"])).get("name", ""))
            if owner != "":
                n.display_name = "Nervios: %s" % SquadManager.short_name({"name": owner})
            engine.deck.active.append(n)


# El rival motivado de la semana (rival_motivado): bono de acierto en sus primeros Momentos. Llamar
# después de que su perfil configure el motor (BotProfile.configure_engine) y antes de engine.start().
func configure_rival_match(engine: MatchEngine) -> void:
    var bonus := float(match_mods.get("rival_bonus", 0.0))
    if bonus != 0.0:
        engine.opening_bonus += bonus
        engine.opening_moments = maxi(engine.opening_moments, int(match_mods.get("rival_moments", 2)))


# Cuántas cartas de Nervios trae la semana.
func nervios_count() -> int:
    return temp_cards.filter(func(t): return t["carta"] == "nervios").size()


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
    # Promesas de la semana (efecto promesa): se cobran con este resultado.
    var promise_out := {"lines": []}
    for p in promises:
        promise_out["lines"].append("Promesa %s." % ("cumplida" if gf > ga else "rota"))
        _apply_effects(p["si_ganas"] if gf > ga else p["si_no"], promise_out)
    promises = []
    popularity = clampi(popularity, 0, 100)
    discipline = clampi(discipline, 0, 100)
    budget += income
    var wear := 1.0 - clampf(end_stamina_pct, 0.0, 1.0)
    var gained := float(m.get("fatigue_base", 0)) + float(m.get("fatigue_from_wear", 0)) * wear
    fatigue = clampf(fatigue + gained, 0.0, 100.0)
    var entry := {"week": week, "rival_id": rival_id, "gf": gf, "ga": ga, "income": income,
        "fatigue_gained": roundi(gained)}
    if not promise_out["lines"].is_empty():
        entry["promesas"] = promise_out["lines"]
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
        "event_id": event_id,
        "event_names": event_names.duplicate(),
        "event_deck": event_deck.duplicate(),
        "event_marks": event_marks.duplicate(true),
        "promises": promises.duplicate(true),
        "temp_cards": temp_cards.duplicate(true),
        "sold": sold.duplicate(),
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
# script. Un guardado v1 (antes de T-05) se migra: mazo de inicio del club y oferta nueva. Uno v1 o
# v2 (antes de T-14) se migra con el Bautizazo como evento de la semana y sin ramas ni promesas.
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
    if version < 1 or version > SAVE_VERSION:
        last_load_errors.append("Versión de guardado %s no compatible (se espera %d)." % [d.get("version"), SAVE_VERSION])
        return null
    var migrate := version == 1
    var migrate_events := version < 3
    for key in SAVE_FIELDS:
        if (migrate and key in V1_MISSING) or (migrate_events and key in V2_MISSING):
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
    if not migrate_events:
        var event_error := c._read_events(d)
        if event_error != "":
            last_load_errors.append(event_error)
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
    if migrate_events:
        # v1 y v2: el único evento era el Bautizazo (aceptar = opción 0); el mazo de eventos se baraja
        # al sacar el de la semana siguiente, sin tocar el azar guardado.
        c.event_id = "bautizazo"
        c.event_names = {}
        c.event_deck = []
        c.event_marks = []
        c.promises = []
        c.temp_cards = []
        c.sold = []
        if not c.event_result.is_empty():
            var accepted: bool = c.event_result.get("accepted", false)
            c.event_result["option"] = 0 if accepted else 1
            c.event_result["sello"] = c.option_stamp(c.event_options()[c.event_result["option"]])
            c.event_result.erase("accepted")
    elif c.event_result.has("option"):
        c.event_result["option"] = int(c.event_result["option"])
    return c


# Lee los eventos de un guardado v3 en esta carrera (ya armada con setup). "" si todo es válido; si
# no, el motivo: un evento o una carta que no existen, o una marca, promesa o carta mal formada.
func _read_events(d: Dictionary) -> String:
    var id := String(d["event_id"])
    if id != "" and get_event(id).is_empty():
        return "El guardado trae un evento desconocido: %s." % id
    for e in d["event_deck"]:
        if typeof(e) != TYPE_STRING or get_event(e).is_empty():
            return "El mazo de eventos guardado trae un evento desconocido."
    var marks: Array = []
    for m in d["event_marks"]:
        if not (m is Dictionary and typeof(m.get("evento")) == TYPE_STRING and not get_event(m["evento"]).is_empty() \
                and typeof(m.get("semana")) == TYPE_FLOAT and m.get("nombres", {}) is Dictionary):
            return "El guardado trae una rama pendiente inválida."
        var mark: Dictionary = m.duplicate(true)
        mark["semana"] = int(m["semana"])
        marks.append(mark)
    for p in d["promises"]:
        if not (p is Dictionary and p.get("si_ganas") is Array and p.get("si_no") is Array):
            return "El guardado trae una promesa inválida."
    for t in d["temp_cards"]:
        if not (t is Dictionary and typeof(t.get("carta")) == TYPE_STRING and typeof(t.get("quien")) == TYPE_STRING \
                and (t["carta"] == "nervios" or squads.catalog.has(t["carta"]))):
            return "El guardado trae una carta temporal desconocida."
    for s in d["sold"]:
        if typeof(s) != TYPE_STRING:
            return "El guardado trae un jugador vendido inválido."
    event_id = id
    event_names = d["event_names"].duplicate()
    event_deck = d["event_deck"].duplicate()
    event_marks = marks
    promises = d["promises"].duplicate(true)
    temp_cards = d["temp_cards"].duplicate(true)
    sold = d["sold"].duplicate()
    return ""


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
