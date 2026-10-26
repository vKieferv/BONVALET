class_name CoachBot
extends RefCounted

# Cerebro del bot: elige qué carta jugar según el BotProfile, en ataque (choose: planificador del
# turno) y en la fase defensiva cuando el rival ataca (choose_defense / run_defense).

const DEFENSE_FOCUS_WEIGHT := 1.6   # la carta del estilo defensivo del perfil
const DEFENSE_CUT_WEIGHT := 1.2     # intercepción y despeje cortan el ataque entero
const DEFENSE_MIN_SCORE := 0.25     # si ninguna carta llega a esto, deja pasar
const DEFENSE_RESERVE_SHARE := 0.5  # al defender guarda la mitad de su reserva de élite para atacar

const PLAN_ELITE_WEIGHT := 0.3      # x elite_preference: gusto por planes con cartas de élite
const PLAN_WEAR_WEIGHT := 0.6       # x energy_conservation: castigo al desgaste del plan (fracción del tope)
const PLAN_RESERVE_PENALTY := 0.5   # plan con élite que deja la estamina bajo la reserva del perfil


# Fase defensiva completa contra un ataque. attack_quality = dificultad de sus jugadas defensivas
# (calidad del ataque rival). Devuelve lo mismo que MatchEngine.end_defense() más "plays".
static func run_defense(e: MatchEngine, profile: BotProfile, attack_quality: float) -> Dictionary:
    if e.injured:
        return {"pressure": 0.0, "block": 0.0, "cancelled": false, "emergency": false, "plays": []}
    e.begin_defense(attack_quality)
    var plays: Array = []
    while e.in_defense:
        var idx := choose_defense(e, profile)
        if idx < 0:
            break
        plays.append(e.play_card(idx))
    var result: Dictionary = e.end_defense().duplicate()
    result["plays"] = plays
    return result


# Carta defensiva a jugar (índice en la mano) o -1 para dejar pasar. Prioriza el estilo del perfil
# y no se queda sin aire para su próximo ataque.
static func choose_defense(e: MatchEngine, profile: BotProfile) -> int:
    var max_e := e.player.max_energy()
    var floor_pct := profile.elite_reserve_pct() * DEFENSE_RESERVE_SHARE
    var focus := profile.defense_focus_kind()
    var best := -1
    var best_score := DEFENSE_MIN_SCORE
    for i in e.playable_indices():
        var c: Card = e.deck.hand[i]
        if (e.player.energy - e.stamina_cost_of(c)) / max_e < floor_pct:
            continue
        var score := e.success_chance(c)
        if c.kind == focus:
            score *= DEFENSE_FOCUS_WEIGHT
        elif c.kind == Card.Kind.INTERCEPT or c.kind == Card.Kind.CLEARANCE:
            score *= DEFENSE_CUT_WEIGHT
        if score > best_score:
            best_score = score
            best = i
    return best


# ---------- Ataque: planificador del turno ----------

# Devuelve el índice de la carta a jugar, o -1 para ceder la jugada (no hay plan que pueda
# terminar en gol, o el perfil no se arriesga con lo que hay).
static func choose(e: MatchEngine, profile: BotProfile) -> int:
    var plan := best_plan(e, profile)
    var pause := _playable_pause(e)
    if plan.is_empty():
        # Sin plan de gol: si está cansado, al menos recupera aire con la Pausa antes de ceder.
        return pause if pause >= 0 and e.player.zone() != PlayerStats.Zone.SAFE else -1
    var last_chance := e.fails >= MatchEngine.MAX_FAILS - 1
    # Enfriar: si el remate final del mejor plan no convence, el perfil cede y guarda la estamina.
    if not last_chance and profile.shot_min_chance >= 0.0 and plan["shot_p"] < profile.shot_min_chance:
        return pause if pause >= 0 and e.player.zone() != PlayerStats.Zone.SAFE else -1
    # PA de sobra para el plan: con cansancio, la Pausa primero recupera estamina gratis.
    if pause >= 0 and e.player.zone() != PlayerStats.Zone.SAFE \
            and e.ap - e.ap_cost_of(e.deck.hand[pause]) >= plan["ap"]:
        return pause
    return plan["cards"][0]


# Mejor plan de gol para el turno: combinaciones de cartas de la mano que caben en los PA que quedan,
# con tantas jugadas como faltan para completar el Momento y terminadas en un remate.
# Puntaje = probabilidad de que salgan todas, ajustada por el perfil (élite, desgaste, riesgo).
# Devuelve {cards: [índices en orden de juego], score, p, shot_p, ap, wear} o {} si no hay plan.
static func best_plan(e: MatchEngine, profile: BotProfile) -> Dictionary:
    var playable := e.playable_indices()
    if playable.is_empty():
        return {}
    var need := maxi(1, int(e.current_moment()["steps_required"]) - e.progress)
    var last_chance := e.fails >= MatchEngine.MAX_FAILS - 1
    var max_e := e.player.max_energy()
    var reserve := profile.elite_reserve_pct()
    var floor_p := lerpf(0.75, 0.30, profile.risk_tolerance) if profile.risk_tolerance >= 0.0 else 0.0

    var steps: Array = []     # cartas que pueden ser pasos previos (todo menos la Pausa)
    for i in playable:
        if e.deck.hand[i].kind != Card.Kind.PAUSE:
            steps.append(i)
    var best := {}
    for s in playable:
        var shot: Card = e.deck.hand[s]
        if shot.kind != Card.Kind.SHOT:
            continue
        var others: Array = steps.filter(func(i): return i != s)
        for combo in _subsets(others, need - 1):
            var cards: Array = combo.duplicate()
            var ap := e.ap_cost_of(shot)
            for i in cards:
                ap += e.ap_cost_of(e.deck.hand[i])
            if ap > e.ap:
                continue
            var p := 1.0
            var wear := 0.0
            var has_elite := false
            var risk := 1.0
            for i in cards + [s]:
                var c: Card = e.deck.hand[i]
                var cp := e.success_chance(c)
                p *= cp
                wear += e.stamina_cost_of(c)
                has_elite = has_elite or c.type == Card.Type.ELITE
                if floor_p > 0.0:
                    risk *= pow(clampf(cp / floor_p, 0.0, 1.0), 2.0)
            var score := p * risk
            if not last_chance:
                score *= 1.0 - profile.energy_conservation * PLAN_WEAR_WEIGHT * clampf(wear / max_e, 0.0, 1.0)
                if has_elite:
                    score *= 1.0 + PLAN_ELITE_WEIGHT * profile.elite_preference
                    if (e.player.energy - wear) / max_e < reserve:
                        score *= PLAN_RESERVE_PENALTY
            if best.is_empty() or score > best["score"]:
                # Pasos previos primero, del más seguro al menos seguro; el remate al final.
                cards.sort_custom(func(a, b): return e.success_chance(e.deck.hand[a]) > e.success_chance(e.deck.hand[b]))
                cards.append(s)
                best = {"cards": cards, "score": score, "p": p, "shot_p": e.success_chance(shot), "ap": ap, "wear": wear}
    return best


# Subconjuntos de k elementos de `items` (k chico: a lo más los pasos que faltan del Momento).
static func _subsets(items: Array, k: int) -> Array:
    if k <= 0:
        return [[]]
    if items.size() < k:
        return []
    var out: Array = []
    for i in items.size():
        for rest in _subsets(items.slice(i + 1), k - 1):
            out.append([items[i]] + rest)
    return out


static func _playable_pause(e: MatchEngine) -> int:
    for i in e.playable_indices():
        if e.deck.hand[i].kind == Card.Kind.PAUSE:
            return i
    return -1
