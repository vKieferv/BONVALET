class_name CoachBot
extends RefCounted

# Cerebro del bot: elige qué carta jugar según el BotProfile.
# Devuelve el índice de la carta en la mano, o -1 si no hay jugadas posibles.
static func choose(e: MatchEngine, profile: BotProfile) -> int:
    var idxs := e.playable_indices()
    if idxs.is_empty():
        return -1

    var max_e := e.player.max_energy()
    var required: int = e.current_moment()["steps_required"]
    var closing: bool = e.progress + 1 >= required                  # toca cerrar con un remate
    var last_chance: bool = e.fails >= MatchEngine.MAX_FAILS - 1    # otro fallo y se pierde
    var reserve := profile.elite_reserve_pct()

    # Filtro de reserva: las cartas de élite solo pasan si se justifican.
    var candidates: Array[int] = []
    for i in idxs:
        var c: Card = e.deck.hand[i]
        var after_pct := (e.player.energy - e.cost_of(c)) / max_e
        if c.type != Card.Type.ELITE or last_chance or after_pct >= reserve:
            candidates.append(i)
    if candidates.is_empty():
        candidates = idxs

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
        var cost := float(e.cost_of(c))
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
                    - (1.0 - profile.flow_aggression) * 0.02 * cost
        else:
            score = p / pow(cost, cost_exp)             # eficiencia: probabilidad por energía
            if profile.risk_tolerance >= 0.0:           # cuanto menos riesgo tolera, más castiga lo poco fiable
                var floor_p := lerpf(0.75, 0.30, profile.risk_tolerance)
                score *= pow(clampf(p / floor_p, 0.0, 1.0), 2.0)
            if is_elite:
                score *= 1.0 + 1.5 * profile.elite_preference
        if score > best_score:
            best_score = score
            best = i
    return best
