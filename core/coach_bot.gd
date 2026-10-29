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
        elif c.kind == Card.Kind.INTERCEPT or c.kind == Card.Kind.CLEARANCE or c.counter:
            score *= DEFENSE_CUT_WEIGHT
        if c.effect > 0.0 and (c.kind == Card.Kind.PRESS or c.kind == Card.Kind.BLOCK):
            # Presión o Bloqueo reforzados (cartas de rasgo): valen más que los de su tipo.
            var base := MatchEngine.PRESS_EFFECT if c.kind == Card.Kind.PRESS else MatchEngine.BLOCK_EFFECT
            score *= clampf(c.effect / base, 1.0, 2.0)
        if score > best_score:
            best_score = score
            best = i
    return best


# ---------- Ataque: planificador del turno ----------

const HOLD := -2                    # choose(): aguantar el balón en vez de jugar una carta
const HOLD_MIN_CHANCE := 0.5        # bajo esta retención no se arriesga a regalar un contragolpe
const DIG_MIN_CHANCE := 0.5         # sin plan, juega una carta que roba si sale al menos así de seguido


# Un paso del turno de ataque: juega la carta elegida, aguanta el balón o cede. Es el único lugar que
# ejecuta las decisiones del bot (lo usan match_view, SimRunner y DuelRunner). Devuelve el evento
# del motor, o {} si cedió. Si el evento trae "stolen", quien arma el partido le da contragolpe al rival.
static func act(e: MatchEngine, profile: BotProfile) -> Dictionary:
    var idx := choose(e, profile)
    if idx == HOLD:
        return e.hold_ball()
    if idx < 0:
        e.abort_moment()
        return {}
    return e.play_card(idx)


# Devuelve el índice de la carta a jugar, HOLD para aguantar el balón (mano sin plan de gol), o -1
# para ceder la jugada.
static func choose(e: MatchEngine, profile: BotProfile) -> int:
    var plan := best_plan(e, profile)
    var pause := _playable_pause(e)
    if plan.is_empty():
        # Sin plan de gol: si está cansado, primero recupera aire con la Pausa; después aguanta el
        # balón para robar una mano nueva, o cede si no puede.
        if pause >= 0 and e.player.zone() != PlayerStats.Zone.SAFE:
            return pause
        var dig := _playable_draw(e)   # una carta que roba (Toque-toque) busca el remate que falta
        if dig >= 0:
            return dig
        if e.zone_mode and e.zone != MatchEngine.Zone.AREA:
            # Partido por zonas: fallar no corta, así que avanza con la carta más segura y, al llegar
            # al Área sin remate, aguanta para robar una mano nueva.
            var step := _zone_advance_card(e)
            if step >= 0:
                return step
        return HOLD if _should_hold(e, profile) else -1
    var last_chance := e.fails >= MatchEngine.MAX_FAILS - 1 and not e.zone_mode
    # Enfriar: si el remate final del mejor plan no convence, el perfil temporiza (aguanta) o cede.
    if not last_chance and profile.shot_min_chance >= 0.0 and plan["shot_p"] < profile.shot_min_chance:
        if pause >= 0 and e.player.zone() != PlayerStats.Zone.SAFE:
            return pause
        return HOLD if _should_hold(e, profile) else -1
    # PA de sobra para el plan: con cansancio, la Pausa primero recupera estamina gratis.
    if pause >= 0 and e.player.zone() != PlayerStats.Zone.SAFE \
            and e.ap - e.ap_cost_of(e.deck.hand[pause]) >= plan["ap"]:
        return pause
    return plan["cards"][0]


# Mejor plan de gol para el turno: combinaciones de cartas de la mano que caben en los PA que quedan,
# con los avances que faltan para completar el Momento (casi siempre una jugada = un avance; un
# Pelotazo vale 2) y terminadas en un remate.
# Puntaje = probabilidad de que salgan todas, ajustada por el perfil (élite, desgaste, riesgo).
# Devuelve {cards: [índices en orden de juego], score, p, shot_p, ap, wear} o {} si no hay plan.
static func best_plan(e: MatchEngine, profile: BotProfile) -> Dictionary:
    var playable := e.playable_indices()
    if playable.is_empty():
        return {}
    var need := maxi(1, int(e.current_moment()["steps_required"]) - e.progress)
    var last_chance := e.fails >= MatchEngine.MAX_FAILS - 1 and not e.zone_mode
    var max_e := e.player.max_energy()
    var reserve := profile.elite_reserve_pct()
    var floor_p := lerpf(0.75, 0.30, profile.risk_tolerance) if profile.risk_tolerance >= 0.0 else 0.0

    var steps: Array = []     # cartas que pueden ser pasos previos (todo menos la Pausa)
    for i in playable:
        if e.deck.hand[i].kind != Card.Kind.PAUSE:
            steps.append(i)
    var best := {}
    if e.zone_mode:
        return _zone_plan(e, profile, playable, steps, need, max_e, reserve, floor_p)
    for s in playable:
        var shot: Card = e.deck.hand[s]
        if shot.kind != Card.Kind.SHOT:
            continue
        var others: Array = steps.filter(func(i): return i != s)
        for combo in _step_combos(e, others, need - 1):
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


# best_plan en el partido por zonas (D-36): cada carta se evalúa en la zona donde se jugaría, el remate
# tiene que caer en el Área (un tiro lejano, también en el Medio, con menos pasos previos) y el puntaje
# castiga el riesgo de robo de cada paso (prefiere la carta más segura en la Salida). Los remates
# entran aunque hoy no se puedan jugar: se juegan al final, cuando el plan llegue al Área.
static func _zone_plan(e: MatchEngine, profile: BotProfile, playable: Array, steps: Array, need: int,
        max_e: float, reserve: float, floor_p: float) -> Dictionary:
    var best := {}
    var required := int(e.current_moment()["steps_required"])
    var shots: Array = []
    for i in e.deck.hand.size():
        var c: Card = e.deck.hand[i]
        if c.kind == Card.Kind.SHOT and c.playable and e.ap_cost_of(c) <= e.ap:
            shots.append(i)
    for s in shots:
        var shot: Card = e.deck.hand[s]
        var others: Array = steps.filter(func(i): return i != s and playable.has(i))
        var ks: Array = [need - 1]
        if shot.long_range:
            if e.zone == MatchEngine.Zone.MEDIO:
                ks.append(0)
            elif e.zone == MatchEngine.Zone.SALIDA and required - e.progress >= 3:
                ks.append(1)
        for k in ks:
            for combo in _step_combos(e, others, k):
                var cards: Array = combo.duplicate()
                var ap := e.ap_cost_of(shot)
                for i in cards:
                    ap += e.ap_cost_of(e.deck.hand[i])
                if ap > e.ap:
                    continue
                cards.sort_custom(func(a, b): return e.success_chance(e.deck.hand[a]) > e.success_chance(e.deck.hand[b]))
                cards.append(s)
                var z: int = e.zone
                var prog := e.progress
                var p := 1.0
                var keep := 1.0   # probabilidad de no regalar un robo en los pasos
                var wear := 0.0
                var has_elite := false
                var risk := 1.0
                var shot_p := 0.0
                var legal := true
                for i in cards:
                    var c: Card = e.deck.hand[i]
                    if c.kind == Card.Kind.SHOT and z != MatchEngine.Zone.AREA \
                            and not (c.long_range and z == MatchEngine.Zone.MEDIO):
                        legal = false
                        break
                    var cp := e.success_chance(c, z)
                    p *= cp
                    keep *= 1.0 - e.steal_chance(c, z)
                    wear += e.stamina_cost_of(c)
                    has_elite = has_elite or c.type == Card.Type.ELITE
                    if floor_p > 0.0:
                        risk *= pow(clampf(cp / floor_p, 0.0, 1.0), 2.0)
                    if c.kind == Card.Kind.SHOT:
                        shot_p = cp
                    else:
                        prog += c.steps
                        z = MatchEngine.Zone.AREA if required - prog <= 1 else mini(MatchEngine.Zone.AREA, z + c.steps)
                if not legal:
                    continue
                var score := p * risk * keep
                score *= 1.0 - profile.energy_conservation * PLAN_WEAR_WEIGHT * clampf(wear / max_e, 0.0, 1.0)
                if has_elite:
                    score *= 1.0 + PLAN_ELITE_WEIGHT * profile.elite_preference
                    if (e.player.energy - wear) / max_e < reserve:
                        score *= PLAN_RESERVE_PENALTY
                if best.is_empty() or score > best["score"]:
                    best = {"cards": cards, "score": score, "p": p, "shot_p": shot_p, "ap": ap, "wear": wear}
    return best


# Partido por zonas, sin plan de gol: la carta de avance más segura (acierto menos riesgo de robo,
# mejor si es barata) para llegar al Área y aguantar ahí. -1 si no conviene avanzar: sin remate en la
# mano y sin Aguantar, avanzar solo arriesga un robo.
static func _zone_advance_card(e: MatchEngine) -> int:
    var has_shot := e.deck.hand.any(func(c): return (c as Card).kind == Card.Kind.SHOT)
    if not has_shot and not e.can_hold():
        return -1
    var best := -1
    var best_score := -INF
    for i in e.playable_indices():
        var c: Card = e.deck.hand[i]
        if c.kind == Card.Kind.SHOT or c.kind == Card.Kind.PAUSE:
            continue
        var score := e.success_chance(c) - e.steal_chance(c) - 0.05 * e.ap_cost_of(c)
        if score > best_score:
            best_score = score
            best = i
    return best


# Pasos previos que suman al menos k avances sin que sobre ninguno (quitar cualquiera dejaría la
# suma bajo k). Con cartas de 1 avance son exactamente los subconjuntos de k cartas, como siempre.
static func _step_combos(e: MatchEngine, items: Array, k: int) -> Array:
    if k <= 0:
        return [[]]
    var out: Array = []
    for size in range(1, k + 1):
        for combo in _subsets(items, size):
            var total := 0
            var smallest := 99
            for i in combo:
                var st: int = (e.deck.hand[i] as Card).steps
                total += st
                smallest = mini(smallest, st)
            if total >= k and total - smallest < k:
                out.append(combo)
    return out


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


# Aguanta si puede y la retención es razonable. Un perfil muy conservador no lo hace cansado
# (prefiere ceder y guardar la estamina).
static func _should_hold(e: MatchEngine, profile: BotProfile) -> bool:
    if not e.can_hold() or e.hold_chance() < HOLD_MIN_CHANCE:
        return false
    return not (profile.energy_conservation >= 0.8 and e.player.zone() != PlayerStats.Zone.SAFE)


# Carta de ataque que roba al salir bien (y no es un remate), con buena probabilidad; -1 si no hay.
static func _playable_draw(e: MatchEngine) -> int:
    for i in e.playable_indices():
        var c: Card = e.deck.hand[i]
        if c.draw > 0 and c.kind != Card.Kind.SHOT and c.kind != Card.Kind.PAUSE \
                and e.success_chance(c) >= DIG_MIN_CHANCE:
            return i
    return -1


static func _playable_pause(e: MatchEngine) -> int:
    for i in e.playable_indices():
        if e.deck.hand[i].kind == Card.Kind.PAUSE:
            return i
    return -1
