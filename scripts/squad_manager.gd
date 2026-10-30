class_name SquadManager
extends RefCounted

# Planteles (18 jugadores por club) y su vínculo con el mazo unificado del partido.
# - Planteles reales: data/squads_2006.json. El resto: SquadGenerator (determinista).
# - Titulares: los 11 mejores por rol según FORMATION.
# - Mazo: cartas colectivas del DT + carta firma de cada titular que la tenga. Las cartas del DT de
#   un club salen de data/decks.json (starter_templates: mazo estándar + carta de rasgo de su
#   arquetipo; season_templates: + su crecimiento) resueltas contra el catálogo de cards.json. Viven
#   aquí y no en CardDB porque necesitan el arquetipo del club y cuántas firmas trae (el tope del mazo).
#   Las cartas "canterano" pasan a ser de un Sub-21 del plantel. owner_id = id del jugador, así el
#   motor aplica el Ejecutor Natural cuando el dueño está en la cancha (PlayerStats.lineup).

const SQUADS_PATH := "res://data/squads_2006.json"
const SIGNATURES_PATH := "res://data/signature_cards.json"
const LEAGUE_ID := "chile_2006"
const FORMATION := ["POR", "DFC", "DFC", "LAT", "LAT", "MCD", "MCD", "MCO", "EXT", "DEL", "DEL"]
const ROLES := ["POR", "DFC", "LAT", "MCD", "MCO", "EXT", "DEL"]
# Partido por zonas: formación de cada estilo (D-30) y línea de cada rol (zone_data).
const FORMATIONS := {
    "Catenaccio": [5, 3, 2, 3], "Directo": [4, 4, 2], "Tiki-Taka": [4, 4, 2],
    "Contragolpe": [4, 3, 3], "Kamikaze": [3, 5, 2],
}
const ZONE_LINE_OF_ROLE := {"DFC": 0, "LAT": 0, "MCD": 1, "MCO": 1, "EXT": 1, "DEL": 2}
const ACCENTS :={"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}

var league: LeagueManager
var load_errors: Array = []
var _real := {}            # team_id -> Array de jugadores
var _cache := {}           # team_id -> Array de jugadores (reales o generados, ya normalizados)
var _signature_cards := {} # card_id -> diccionario de carta
var _signature_template := {}
var catalog := {}          # cartas del DT por id (CardDB.load_catalog)
var deck_lists := {}       # data/decks.json: estandar, rasgos, crecimiento, ofertas


func load_all(p_league: LeagueManager) -> bool:
    league = p_league
    load_errors.clear()
    _real.clear()
    _cache.clear()
    var squads = _read_json(SQUADS_PATH)
    if squads is Dictionary and squads.has("squads"):
        for team_id in squads["squads"]:
            _real[team_id] = squads["squads"][team_id]["players"]
    else:
        load_errors.append("Planteles inválidos: %s" % SQUADS_PATH)
    var sig = _read_json(SIGNATURES_PATH)
    if sig is Dictionary and sig.has("cards"):
        _signature_cards = sig["cards"]
        _signature_template = sig.get("template", {})
    else:
        load_errors.append("Cartas firma inválidas: %s" % SIGNATURES_PATH)
    catalog = CardDB.load_catalog()
    if catalog.is_empty():
        load_errors.append("Catálogo de cartas inválido: %s" % CardDB.CARDS_PATH)
    deck_lists = CardDB.load_deck_lists()
    if not (deck_lists.get("estandar") is Array and deck_lists.get("rasgos") is Dictionary \
            and deck_lists.get("crecimiento") is Dictionary and deck_lists.get("ofertas") is Dictionary):
        load_errors.append("Mazos inválidos: %s (faltan estandar, rasgos, crecimiento u ofertas)" % CardDB.DECKS_PATH)
    else:
        for id in deck_lists_ids():
            if not catalog.has(id):
                load_errors.append("%s nombra una carta que no está en el catálogo: %s" % [CardDB.DECKS_PATH, id])
    return load_errors.is_empty()


# Todos los ids que nombra decks.json (estándar, rasgos, crecimiento y ofertas), sin el lugar del rasgo.
func deck_lists_ids() -> Array:
    var ids: Array = []
    for id in deck_lists.get("estandar", []):
        if id != CardDB.TRAIT_SLOT:
            ids.append(id)
    ids.append_array(deck_lists.get("rasgos", {}).values())
    for key in ["crecimiento", "ofertas"]:
        for list_name in deck_lists.get(key, {}):
            ids.append_array(deck_lists[key][list_name])
    return ids


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        load_errors.append("No existe el archivo: %s" % path)
        return null
    var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
    if parsed == null:
        load_errors.append("JSON con errores: %s" % path)
    return parsed


# ------------------------------------------------------------------ Plantel

func is_generated(team_id: String) -> bool:
    return not _real.has(team_id)


# 18 jugadores del club. La figura del club (teams_chile_2006.json) siempre trae carta firma:
# la propia si existe, si no una genérica (firma_<id>).
func get_squad(team_id: String) -> Array:
    if _cache.has(team_id):
        return _cache[team_id]
    var team := league.get_team(team_id)
    if team.is_empty():
        return []
    var players: Array = []
    if _real.has(team_id):
        players = _real[team_id].duplicate(true)
    else:
        players = SquadGenerator.generate(team, league.get_rules(LEAGUE_ID))
    var figure = team.get("signature_card")
    for p in players:
        if p["signature_card_id"] == null and figure != null and p["name"] == figure:
            p["signature_card_id"] = "firma_" + String(p["id"])
    _cache[team_id] = players
    return players


func find_player(team_id: String, player_id: String) -> Dictionary:
    for p in get_squad(team_id):
        if p["id"] == player_id:
            return p
    return {}


# Errores de plantel según las reglas de la liga (tamaño, Sub-21, extranjeros, roles).
func squad_errors(team_id: String) -> Array:
    var rules := league.get_rules(LEAGUE_ID)
    var country := String(league.get_league(LEAGUE_ID).get("country", "CHI"))
    var squad := get_squad(team_id)
    var errors: Array = []
    if squad.size() != int(rules.get("max_squad_size", 18)):
        errors.append("%s: el plantel tiene %d jugadores (deben ser %d)" % [team_id, squad.size(), rules.get("max_squad_size", 18)])
    var sub21 := 0
    var foreign := 0
    var ids := {}
    for p in squad:
        if p["age"] != null and int(p["age"]) < int(rules.get("sub21_age_limit", 21)):
            sub21 += 1
        if p["nationality"] != country:
            foreign += 1
        if ids.has(p["id"]):
            errors.append("%s: id repetido %s" % [team_id, p["id"]])
        ids[p["id"]] = true
        if not ROLES.has(p["role"]):
            errors.append("%s: rol desconocido %s (%s)" % [team_id, p["role"], p["name"]])
    if sub21 < int(rules.get("mandatory_sub21_cards", 2)):
        errors.append("%s: solo %d jugadores Sub-21" % [team_id, sub21])
    if foreign > int(rules.get("max_foreigners_in_deck", 6)):
        errors.append("%s: %d extranjeros" % [team_id, foreign])
    return errors


# Los 11 titulares: por cada puesto de FORMATION, el de mejor skill_rating con ese rol; si no
# queda nadie con el rol, el mejor de la misma línea y, si tampoco, el mejor disponible.
func pick_starters(team_id: String) -> Array:
    var pool: Array = get_squad(team_id).duplicate()
    pool.sort_custom(func(a, b): return int(a["skill_rating"]) > int(b["skill_rating"]))
    var starters: Array = []
    for role in FORMATION:
        var pick := _take(pool, func(p): return p["role"] == role)
        if pick.is_empty():
            var line: String = SquadGenerator.LINES[role]
            pick = _take(pool, func(p): return SquadGenerator.LINES.get(p["role"], "") == line)
        if pick.is_empty():
            pick = _take(pool, func(_p): return true)
        if not pick.is_empty():
            starters.append(pick)
    return starters


func _take(pool: Array, pred: Callable) -> Dictionary:
    for i in pool.size():
        if pred.call(pool[i]):
            return pool.pop_at(i)
    return {}


func lineup_ids(team_id: String) -> Array[String]:
    var out: Array[String] = []
    for p in pick_starters(team_id):
        out.append(String(p["id"]))
    return out


# Partido por zonas (D-36): formación del estilo del club (D-30, [atrás, medio, arriba] y, en el
# 5-3-2, el tope de 3 arriba) y fuerza de cada línea = promedio de skill_rating de sus titulares
# (atrás DFC y LAT, medio MCD, MCO y EXT, arriba DEL). Es lo que quien arma el partido le pasa al
# motor (MatchEngine.formation / line_strength). Una línea sin titulares toma el promedio del campo.
func zone_data(team_id: String) -> Dictionary:
    var archetype := String(league.get_team(team_id).get("archetype", "Directo"))
    var sums := [0.0, 0.0, 0.0]
    var counts := [0, 0, 0]
    var total := 0.0
    var n := 0
    for p in pick_starters(team_id):
        if not ZONE_LINE_OF_ROLE.has(p["role"]):
            continue
        var line: int = ZONE_LINE_OF_ROLE[p["role"]]
        sums[line] += float(p["skill_rating"])
        counts[line] += 1
        total += float(p["skill_rating"])
        n += 1
    var strength: Array = []
    for i in 3:
        strength.append(sums[i] / counts[i] if counts[i] > 0 else total / maxf(1.0, float(n)))
    return {"formation": FORMATIONS.get(archetype, FORMATIONS["Directo"]), "line_strength": strength}


# ------------------------------------------------------------------ Mazo

# Carta firma del jugador (diccionario listo para Card.from_dict) o {} si no tiene.
func signature_card_for(player: Dictionary) -> Dictionary:
    var card_id = player.get("signature_card_id")
    if card_id == null:
        return {}
    var d: Dictionary
    if _signature_cards.has(card_id):
        d = _signature_cards[card_id].duplicate()
    elif String(card_id).begins_with("firma_") and not _signature_template.is_empty():
        d = _signature_template.duplicate()
        d["id"] = card_id
        d["name"] = String(d["name"]) % short_name(player)
    else:
        return {}
    _stamp_owner(d, player)
    return d


# Cartas del DT con que arranca la temporada un club: el mazo estándar con la carta de rasgo de su
# arquetipo (11). Pasadas por build_match_templates suman la firma de su figura titular (12).
func starter_templates(team_id: String) -> Array:
    return season_templates(team_id, 0)


# Cartas del DT del club en una etapa de la temporada: el mazo de inicio + las primeras `extra`
# cartas del crecimiento de su arquetipo, sin que el mazo del partido (con las firmas de los
# titulares) pase de DeckManager.DECK_MAX.
func season_templates(team_id: String, extra: int) -> Array:
    var arch := String(league.get_team(team_id).get("archetype", ""))
    var base := CardDB.deck_ids(deck_lists, arch, 0).size()
    var room := DeckManager.DECK_MAX - base - signature_count(team_id)
    return CardDB.archetype_templates(catalog, deck_lists, arch, clampi(extra, 0, maxi(0, room)))


# Cuántas cartas firma suma build_match_templates (una por titular que la tenga).
func signature_count(team_id: String) -> int:
    var n := 0
    for p in pick_starters(team_id):
        if not signature_card_for(p).is_empty():
            n += 1
    return n


# Mazo unificado del club como cartas listas para el partido.
func build_match_deck(team_id: String, templates: Array) -> Array:
    var deck: Array = []
    for d in build_match_templates(team_id, templates):
        deck.append(Card.from_dict(d))
    return deck


# Mazo unificado del club como diccionarios (lo que usa SimRunner para construir un mazo nuevo
# por partido): cartas del DT + cartas de canteranos asignadas + firmas de los titulares.
func build_match_templates(team_id: String, templates: Array) -> Array:
    var starters := pick_starters(team_id)
    var starter_ids := {}
    for p in starters:
        starter_ids[p["id"]] = true
    # Sub-21 para las cartas de canterano: primero los titulares (pueden activar el Ejecutor Natural),
    # luego por edad.
    var limit := int(league.get_rules(LEAGUE_ID).get("sub21_age_limit", 21))
    var youth: Array = []
    for p in get_squad(team_id):
        if p["age"] != null and int(p["age"]) < limit:
            youth.append(p)
    var youth_order := func(a: Dictionary, b: Dictionary) -> bool:
        if starter_ids.has(a["id"]) != starter_ids.has(b["id"]):
            return starter_ids.has(a["id"])
        return int(a["age"]) < int(b["age"])
    youth.sort_custom(youth_order)

    var out: Array = []
    var y := 0
    for t in templates:
        var d: Dictionary = t.duplicate()
        if d.get("tags", []).has("canterano") and y < youth.size():
            var p: Dictionary = youth[y]
            y += 1
            # Una Promesa mejorada en la sesión de video (CardDB.upgraded) conserva su "+".
            d["name"] = "Promesa: %s%s" % [short_name(p), CardDB.UPGRADE_SUFFIX if d.has("mejora") else ""]
            _stamp_owner(d, p)
        out.append(d)
    for p in starters:
        var sig := signature_card_for(p)
        if not sig.is_empty():
            out.append(sig)
    return out


func _stamp_owner(d: Dictionary, player: Dictionary) -> void:
    d["owner_id"] = player["id"]
    d["nationality"] = player["nationality"]
    d["age"] = player["age"] if player["age"] != null else 0


# ------------------------------------------------------------------ Utilidades

static func short_name(player: Dictionary) -> String:
    var parts := String(player["name"]).split(" ")
    return parts[parts.size() - 1]


# "Matías Fernández" -> "matias_fernandez"
static func slug(text: String) -> String:
    var s := text.to_lower()
    for k in ACCENTS:
        s = s.replace(k, ACCENTS[k])
    var out := ""
    for ch in s:
        if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
            out += ch
        elif not out.ends_with("_"):
            out += "_"
    return out.trim_suffix("_")
