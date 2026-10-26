class_name CoachBot
extends RefCounted

# Cerebro del bot: elige qué carta jugar según el BotProfile, en ataque (choose) y en la fase
# defensiva cuando el rival ataca (choose_defense / run_defense).

const DEFENSE_FOCUS_WEIGHT := 1.6   # la carta del estilo defensivo del perfil
const DEFENSE_CUT_WEIGHT := 1.2     # intercepción y despeje cortan el ataque entero
const DEFENSE_MIN_SCORE := 0.25     # si ninguna carta llega a esto, deja pasar
const DEFENSE_RESERVE_SHARE := 0.5  # al defender guarda la mitad de su reserva de élite para atacar


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


# Ataque: devuelve el índice de la carta en la mano, o -1 si no hay jugadas posibles.
static func choose(e: MatchEngine, profile: BotProfile) -> int:
    var idxs := e.playable_indices()
    if idxs.is_empty():
        return -1

    var max_e := e.player.max_energy()
    var required: int = e.current_moment()["steps_required"]
    var closing: bool = e.progress + 1 >= required                  # toca cerrar con un remate
    var last_chance: bool = e.fails >= MatchEngine.MAX_FAILS - 1    # otro fallo y se pierde
    var reserve := profile.elite_reserve_pct()

    # La Pausa solo se usa para recuperar aire: con cansancio y sin urgencia de cerrar.
    var pause_ok := e.player.zone() != PlayerStats.Zone.SAFE and not closing and not last_chance

    # Filtro de reserva: las cartas de élite solo pasan si la estamina que dejan alcanza la reserva.
    var candidates: Array[int] = []
    for i in idxs:
        var c: Card = e.deck.hand[i]
        if c.kind == Card.Kind.PAUSE and not pause_ok:
            continue
        var after_pct := (e.player.energy - e.stamina_cost_of(c)) / max_e
        if c.type != Card.Type.ELITE or last_chance or after_pct >= reserve:
            candidates.append(i)
    if candidates.is_empty():
        candidates = idxs

    # PA del turno: antes de cerrar, no gasta los PA que necesita el remate más barato de la mano.
    # (Regla mínima del modelo de PA; el planificador del turno completo llega en la fase 2.)
    if not closing:
        var shot_ap := _cheapest_shot_ap(e)
        if shot_ap >= 0:
            var keep: Array[int] = []
            for i in candidates:
                var c: Card = e.deck.hand[i]
                if c.kind == Card.Kind.SHOT or e.ap - e.ap_cost_of(c) >= shot_ap:
                    keep.append(i)
            if not keep.is_empty():
                candidates = keep

    # Enfriar el partido: si el mejor remate no convence, pases seguros o ceder la jugada
    if closing and not last_chance and profile.shot_min_chance >= 0.0:
        var best_shot := 0.0
        var safe := -1
        var safe_p := -1.0
        for i in candidates:
            var c: Card = e.deck.hand[i]
            var cp := e.success_chance(c)
            if c.kind == Card.Kind.SHOT:
                best_shot = maxf(best_shot, cp)
            elif c.type != Card.Type.ELITE and cp > safe_p:
                safe_p = cp
                safe = i
        if best_shot < profile.shot_min_chance:
            if e.progress - (required - 1) >= profile.stall_plays or safe < 0:
                return -1
            return safe

    var cost_exp := lerpf(0.3, 1.0, profile.energy_conservation)
    var best := -1
    var best_score := -INF
    for i in candidates:
        var c: Card = e.deck.hand[i]
        var p := e.success_chance(c)
        var cost := 1.0 + float(e.ap_cost_of(c))      # PA del turno (+1 para que 0 PA no divida por cero)
        var is_elite := c.type == Card.Type.ELITE
        var score: float
        if last_chance:
            score = p                                   # todo o nada
        elif closing:
            score = p if c.kind == Card.Kind.SHOT else p * 0.01
            if is_elite:
                score *= 1.0 + 0.3 * profile.elite_preference
        elif e.flow_active:
            score = p + profile.flow_aggression * c.effective_bonus() \
                    - (1.0 - profile.flow_aggression) * 0.05 * cost
        else:
            score = p / pow(cost, cost_exp)             # eficiencia: probabilidad por PA
            if profile.risk_tolerance >= 0.0:           # cuanto menos riesgo tolera, más castiga lo poco fiable
                var floor_p := lerpf(0.75, 0.30, profile.risk_tolerance)
                score *= pow(clampf(p / floor_p, 0.0, 1.0), 2.0)
            if is_elite:
                score *= 1.0 + 1.5 * profile.elite_preference
        if score > best_score:
            best_score = score
            best = i
    return best


# PA del remate más barato en la mano (jugable o no), o -1 si no hay remates.
static func _cheapest_shot_ap(e: MatchEngine) -> int:
    var best := -1
    for c in e.deck.hand:
        if c.kind == Card.Kind.SHOT and c.playable:
            var cost := e.ap_cost_of(c)
            if best < 0 or cost < best:
                best = cost
    return best
