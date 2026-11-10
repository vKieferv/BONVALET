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
    return execute(e, intent(e, profile))


# D-44: la jugada que el bot decide antes de tirarla (la anuncia para que el rival defienda):
# {index, card, receiver}, {hold: true} para aguantar o {} para ceder.
static func intent(e: MatchEngine, profile: BotProfile) -> Dictionary:
    if e.corner_pending:   # D-48: pelota parada, sin carta: centra al que más conviene
        return {"corner": e.best_corner_receiver()}
    if e.duel_on() and e.moment_plays == 0 and not e.carrier_chosen:
        e.set_carrier(choose_carrier(e))   # modo de duelos: quién arranca con la pelota
    var idx := choose(e, profile)
    if idx == HOLD:
        return {"hold": true}
    if idx < 0:
        return {}
    var card: Card = e.deck.hand[idx]
    var receiver := choose_receiver(e, card) if e.duel_on() and MatchEngine.is_pass(card) else ""
    return {"index": idx, "card": card, "receiver": receiver}


# Tira la jugada anunciada (intent). Devuelve el evento del motor, o {} si cedió.
static func execute(e: MatchEngine, it: Dictionary) -> Dictionary:
    if it.is_empty():
        e.abort_moment()
        return {}
    if it.has("corner"):
        return e.take_corner(String(it["corner"]))
    if it.get("hold", false):
        return e.hold_ball()
    return e.play_card(int(it["index"]), String(it["receiver"]))


# D-44: el que defiende ve la jugada anunciada (MatchEngine.set_defense_intent).
static func announce(def: MatchEngine, it: Dictionary) -> void:
    def.set_defense_intent(it.get("card"), String(it.get("receiver", "")), bool(it.get("hold", false)))


# D-44: el bot que defiende responde a la jugada anunciada con una carta como mucho (la misma elección
# de choose_defense: las que no sirven contra esa jugada no son jugables). Devuelve su evento o {}.
static func defend_play(def: MatchEngine, profile: BotProfile) -> Dictionary:
    if not def.duel_defense_on():
        return {}
    var idx := choose_defense(def, profile)
    return def.play_card(idx) if idx >= 0 else {}


# D-44: un paso del ataque de un bot contra la defensa por duelos de otro bot: anuncia, el otro
# responde y, si el Momento sigue, tira. Devuelve {ev: el evento del ataque ({} si cedió o lo
# cortaron), defense: [eventos de la defensa]}. Lo usan DuelRunner y las mediciones.
static func defended_step(att: MatchEngine, att_profile: BotProfile, def: MatchEngine,
        def_profile: BotProfile) -> Dictionary:
    var it := intent(att, att_profile)
    var plays: Array = []
    if def.duel_defense_on() and not it.is_empty():
        announce(def, it)
        var d := defend_play(def, def_profile)
        if not d.is_empty():
            plays.append(d)
    if att.moment_over:
        return {"ev": {}, "defense": plays}
    return {"ev": execute(att, it), "defense": plays}


# Devuelve el índice de la carta a jugar, HOLD para aguantar el balón (mano sin plan de gol), o -1
# para ceder la jugada.
static func choose(e: MatchEngine, profile: BotProfile) -> int:
    var plan := best_plan(e, profile)
    var pause := _playable_pause(e)
    var back := _duel_back_card(e, plan)
    if back >= 0:
        return back
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

    var steps: Array = []     # cartas que pueden ser pasos previos (todo menos la Pausa y, por duelos, la vuelta atrás)
    for i in playable:
        var c: Card = e.deck.hand[i]
        if c.kind != Card.Kind.PAUSE and not (c.back and e.duel_on()):
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
        if c.kind == Card.Kind.SHOT or c.kind == Card.Kind.PAUSE or (c.back and e.duel_on()):
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


# ---------- Modo de duelos (D-40, T-13) ----------

# Cómo reparte sus marcas cada estilo (valores de prueba): cuántas figuras tuyas reciben marca doble
# antes de cubrir al resto. Zonal (Tiki-Taka, Directo): primero uno sobre cada uno y los que sobran,
# sobre tus figuras. A la figura (Contragolpe, Kamikaze): doble a tu mejor jugador y después uno sobre
# cada uno. Cerrojo (Catenaccio): doble a tus dos mejores.
const MARK_DOUBLES := {"Tiki-Taka": 0, "Directo": 0, "Contragolpe": 1, "Kamikaze": 1, "Catenaccio": 2}
const MARK_JITTER := 4.0            # azar al ordenar tus figuras: dos parecidas pueden cambiar de orden
const BACK_MAX_STEP_P := 0.40       # vuelve atrás si su mejor carta para avanzar no llega a esto...
const BACK_MIN_P := 0.60            # ...y la vuelta atrás sale al menos así de seguido
const RECEIVER_THREAT_WEIGHT := 0.1 # al elegir receptor, cuánto pesa lo peligroso que es (por punto / 100)
const LOOKAHEAD_FLOOR := 0.25       # con lookahead (D-43): lo mínimo que vale recibir aunque después no haya jugada
const SAME_ZONE_WEIGHT := 0.5       # D-46: cuánto vale un pase a la misma zona frente a uno que avanza


# Marcas del rival en una zona: sus defensores (los de su línea que la defiende) sobre tus atacantes.
# Tus atacantes se ordenan por peligro (MatchEngine.threat, con un poco de azar del rng del motor) y
# sus defensores por calidad (su mejor Quite o Lectura); los mejores marcan a los más peligrosos. Si
# son menos, alguien queda libre; si son más, alguien queda con marca doble.
# Devuelve {id de tu jugador: [sus marcadores, del mejor al peor]} (vacío = libre).
static func assign_marks(attackers: Array, defenders: Array, style: String, rng: RandomNumberGenerator) -> Dictionary:
    var out := {}
    for a in attackers:
        out[a["id"]] = []
    if attackers.is_empty() or defenders.is_empty():
        return out
    var ranked: Array = []
    for i in attackers.size():
        ranked.append([MatchEngine.threat(attackers[i]) + rng.randf_range(-MARK_JITTER, MARK_JITTER), i, attackers[i]])
    ranked.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
    var queue: Array = defenders.duplicate()
    queue.sort_custom(func(a, b): return _mark_quality(a) > _mark_quality(b))
    var doubles := mini(int(MARK_DOUBLES.get(style, 0)), ranked.size())
    for i in doubles:   # marca doble a las figuras
        if queue.size() >= 2:
            out[ranked[i][2]["id"]].append_array([queue.pop_front(), queue.pop_front()])
    for r in ranked:    # uno sobre cada uno de los que siguen libres, del más peligroso al menos
        if queue.is_empty():
            break
        if (out[r[2]["id"]] as Array).is_empty():
            out[r[2]["id"]].append(queue.pop_front())
    var k := 0
    while not queue.is_empty():   # los que sobran, sobre las figuras
        out[ranked[k % ranked.size()][2]["id"]].append(queue.pop_front())
        k += 1
    for id in out:
        (out[id] as Array).sort_custom(func(a, b): return _mark_quality(a) > _mark_quality(b))
    return out


static func _mark_quality(pl: Dictionary) -> int:
    return maxi(int(pl.get("quite", 0)), int(pl.get("lectura", 0)))


# Portador de la primera zona: el compañero con quien la mejor carta de la mano sale más seguido. Con
# duel_bot_lookahead (D-43), cada carta vale lo de _play_value: un pase, mirando también lo que podrá
# hacer el receptor después.
static func choose_carrier(e: MatchEngine) -> String:
    var best := String(e.carrier.get("id", ""))
    var best_p := -INF
    var current := best
    for pl in e.zone_players(e.zone):
        e.carrier = pl
        var p := -INF
        for i in e.playable_indices():
            var c: Card = e.deck.hand[i]
            if c.kind != Card.Kind.PAUSE:
                p = maxf(p, _play_value(e, c) if e.duel_bot_lookahead else e.success_chance(c))
        if p > best_p + 0.001:
            best_p = p
            best = pl["id"]
    e.carrier = e._player_by_id(current)
    return best


# Receptor del pase: el de mejor puntaje (_receiver_score). D-46: uno de la misma zona no avanza, así que su
# puntaje vale SAME_ZONE_WEIGHT (lo elige solo si pasar hacia adelante es mucho peor).
static func choose_receiver(e: MatchEngine, card: Card) -> String:
    var best := ""
    var best_score := -INF
    for r in e.receivers(card):
        var score := _receiver_score(e, card, r)
        if e.pass_zone(card, r["id"]) == e.zone and e.target_zone(card) != e.zone:
            score *= SAME_ZONE_WEIGHT if score > 0.0 else 1.0 / SAME_ZONE_WEIGHT
        if score > best_score:
            best_score = score
            best = r["id"]
    return best


# Sin lookahead: % de recibir menos riesgo de robo, con un poco de preferencia por el más peligroso. Con
# lookahead (D-43, un solo paso): el % de recibir por lo que vale su mejor jugada siguiente (al menos
# LOOKAHEAD_FLOOR, para no despreciar un pase seguro cuando la mano se acaba), menos el robo.
static func _receiver_score(e: MatchEngine, card: Card, r: Dictionary) -> float:
    var p := e.success_chance(card, -1, r["id"])
    var s := e.steal_chance(card, -1, r["id"])
    if not e.duel_bot_lookahead:
        return p - s + RECEIVER_THREAT_WEIGHT * MatchEngine.threat(r) / 100.0
    return p * (LOOKAHEAD_FLOOR + (1.0 - LOOKAHEAD_FLOOR) * _next_value(e, card, r)) - s


# Lo que vale jugar la carta ahora: un pase, el puntaje de su mejor receptor; el resto, su % menos el robo.
static func _play_value(e: MatchEngine, c: Card) -> float:
    if MatchEngine.is_pass(c):
        var r := choose_receiver(e, c)
        return -INF if r == "" else _receiver_score(e, c, e._player_by_id(r))
    return e.success_chance(c) - e.steal_chance(c)


# El mejor % que tendría `r` en la jugada siguiente si recibe `card`: con sus habilidades y sus marcas en
# la zona a la que llega y con las cartas que quedan en la mano (sin la Pausa ni la vuelta atrás; los
# remates, solo si llega al Área o, de lejos, al Medio) y los PA que sobran. Simula el estado del motor y
# lo deja como estaba.
static func _next_value(e: MatchEngine, card: Card, r: Dictionary) -> float:
    var saved := [e.carrier, e.zone, e.progress, e.carrier_extra]
    var tz := e.pass_zone(card, String(r.get("id", "")))
    var same := tz == e.zone and e.target_zone(card) != e.zone   # D-46: no avanza
    if not same:
        e.progress = maxi(0, e.progress - 1) if card.back else e.progress + card.steps
    e.zone = tz as MatchEngine.Zone
    e.carrier = r
    e.carrier_extra = false
    var ap_left := e.ap - e.ap_cost_of(card)
    var best := 0.0
    for c in e.deck.hand:
        if c == card or not c.playable or c.kind == Card.Kind.PAUSE or c.back or c.is_defensive():
            continue
        if c.kind == Card.Kind.SHOT and tz != MatchEngine.Zone.AREA \
                and not (c.long_range and tz == MatchEngine.Zone.MEDIO):
            continue
        if e.ap_cost_of(c) > ap_left:
            continue
        best = maxf(best, e.success_chance(c))
    e.carrier = saved[0]
    e.zone = saved[1]
    e.progress = saved[2]
    e.carrier_extra = saved[3]
    return best


# Vuelta atrás (cartas con "atras"): si el portador está tan marcado que su mejor carta para avanzar no
# llega a BACK_MAX_STEP_P y la vuelta atrás sale seguido, devuelve la pelota para que el rival reparta
# de nuevo. -1 si no conviene.
static func _duel_back_card(e: MatchEngine, plan: Dictionary) -> int:
    if not e.duel_on() or e.zone == MatchEngine.Zone.SALIDA:
        return -1
    var back := -1
    var back_p := 0.0
    var step_p := 0.0
    for i in e.playable_indices():
        var c: Card = e.deck.hand[i]
        if c.back:
            var p := e.success_chance(c)
            if p > back_p:
                back_p = p
                back = i
        elif c.kind != Card.Kind.PAUSE and (c.kind != Card.Kind.SHOT or e.zone == MatchEngine.Zone.AREA):
            step_p = maxf(step_p, e.success_chance(c))
    if back < 0 or back_p < BACK_MIN_P or step_p >= BACK_MAX_STEP_P:
        return -1
    if not plan.is_empty() and e.deck.hand[plan["cards"][0]].kind == Card.Kind.SHOT:
        return -1   # ya está para rematar
    return back
