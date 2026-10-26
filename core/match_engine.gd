class_name MatchEngine
extends RefCounted

## Se emite al jugar una carta cuyo dueño es el ejecutor (la UI lo usa para el resplandor).
signal natural_executor_played(card: Card)

enum Posture { LOW, NORMAL, HIGH }

# --- Constantes de balance (ajustar con core/sim.gd o godot-check -Balance) ---
const MAX_FAILS := 2                  # 2 fallos y el Momento Clave se pierde
const FLOW_BREAK_LOSS_PCT := 0.15     # energía perdida al romperse el Flow
const TIRED_COST_MULT := 1.25
const TIRED_PENALTY := 0.04
const EXHAUSTED_PENALTY := 0.10
# Lesión: solo se tira al jugar en zona de agotamiento, de MIN (al entrar) a MAX (barra en 0)
# por jugada. Calibrado para que un partido normal termine en lesión un 2-5% de las veces.
const INJURY_CHANCE_MIN := 0.004
const INJURY_CHANCE_MAX := 0.012
const EXHAUSTION_PCT := 0.30      # la zona de agotamiento empieza por debajo de este % de energía
const EXTRA_MOMENT_CHANCE_HIGH := 0.35
const MAX_MOMENTS := 5
# Regla de emparejamiento anti-pasividad (perfil que castiga + rival en postura LOW):
# los REMATES ganan +exploit_shot_bonus puntos (por defecto 10), cuestan 1 de energía menos
# y el Momento pide una jugada menos (transición rápida, mínimo 2).
const PASSIVITY_SHOT_BONUS := 0.10
const PASSIVITY_COST_REDUCTION := 1
const LOW_MAX_MOMENTS := 3        # tope de momentos propios en postura LOW
const LOW_SHOT_PENALTY := 0.15    # -15 puntos de acierto en remates en postura LOW
# Regeneración entre momentos = regen_normal_pct (22% por defecto) x este factor.
# Con NORMAL = 22%: LOW = 35% y HIGH = 8%. HIGH no tiene consumo extra:
# su único trade-off es la mayor frecuencia de momentos extra.
const RECOVERY_RATIO := {
	Posture.LOW: 35.0 / 22.0,
	Posture.NORMAL: 1.0,
	Posture.HIGH: 8.0 / 22.0,
}
# Ejecutor Natural: la carta la juega su dueño (card.owner_id == player.player_id).
const NATURAL_EXECUTOR_BONUS := 0.15  # +15 puntos de acierto
const NATURAL_FLOW_CHARGE := 2        # la jugada cuenta doble para la racha de Flow
# Pausa (carta de ataque): recupera energía sin sumar progreso; una por Momento Clave.
const PAUSE_ENERGY_PCT := 0.10
const MAX_PAUSES := 1
# Defensa (posesión rival): antes de cada ataque rival se roba una mano defensiva.
const DEFENSE_HAND_SIZE := 3
const DEFENSE_MAX_PLAYS := 2          # cartas defensivas por ataque rival
const PRESS_EFFECT := 0.06            # Presión: +6 pts de dificultad a todas las jugadas de ese ataque
const BLOCK_EFFECT := 0.12            # Bloqueo: +12 pts de dificultad a sus remates
const EMERGENCY_COST_PCT := 0.25      # Despeje de Emergencia: 25% del tope de energía...
const EMERGENCY_SHOT_PENALTY := 0.25  # ...-25 pts a los remates de ese ataque, y el rival recupera el balón

var player: PlayerStats
var deck: DeckManager
var rng: RandomNumberGenerator
var rival_difficulty: float

var posture: Posture = Posture.NORMAL
var moments: Array = []     # [{minute, steps_required, difficulty}]
var moment_idx := 0
var finished := false
var injured := false
var exploit_rival_space := false   # lo activa quien arma el partido según el emparejamiento
var exploit_shot_bonus := PASSIVITY_SHOT_BONUS
# Los siguientes los fija BotProfile.configure_engine() desde el perfil.
var opening_bonus := 0.0           # bono de acierto en los primeros `opening_moments` momentos
var opening_moments := 0
var late_from_moment := MAX_MOMENTS   # desde este Momento (0 = primero) se aplica el desgaste tardío
var late_cost_mult := 1.0
var late_injury_mult := 1.0
# Semana previa (modo carrera): forma del entrenamiento y jugadores funados.
var form_bonus := 0.0            # puntos de acierto en todas las jugadas (ataque y defensa)
var owner_cost_surcharge := {}   # owner_id -> energía extra en sus cartas (funado: +1)
# Defensa rival aplicada al Momento en curso (la fija quien defiende; se limpia en advance()).
var opponent_pressure := 0.0
var opponent_block := 0.0

# Estado del Momento Clave en curso
var moment_over := true
var progress := 0
var fails := 0
var streak := 0
var flow_active := false
var flow_cards: Array = []
var moment_had_flow := false
var exhausted_flagged := false
var pauses := 0
var counter_ready := false   # tras una intercepción, el próximo Momento propio arranca con 1 jugada

# Estado de la defensa en curso
var in_defense := false
var defense_difficulty := 0.0
var defense_plays := 0
var defense_result := {}     # {pressure, block, cancelled, emergency}

var stats := {"goals": 0, "moments": 0, "flow_moments": 0, "flow_breaks": 0, "injuries": 0,
	"plays": 0, "elite_plays": 0, "tired_plays": 0, "natural_plays": 0, "skipped": 0,
	"defense_plays": 0, "interceptions": 0, "emergencies": 0}


func _init(p_player: PlayerStats, p_deck: DeckManager, p_rng: RandomNumberGenerator, p_rival_difficulty := 0.15) -> void:
	player = p_player
	deck = p_deck
	rng = p_rng
	rival_difficulty = p_rival_difficulty
	for m in MAX_MOMENTS:
		stats["plays_m%d" % m] = 0   # jugadas hechas en el Momento Clave m (0 = primero)
		stats["tired_m%d" % m] = 0   # ...de ellas, con cansancio o agotamiento


func start() -> void:
	player.start_match_energy()
	deck.start_match()
	moments.clear()
	var n := 3 + (1 if rng.randf() < 0.5 else 0)
	if posture == Posture.LOW:
		n -= 1   # 3-4 momentos pasan a 2-3
	var minutes: Array = []
	while minutes.size() < n:
		var m := rng.randi_range(5, 88)
		if not minutes.has(m):
			minutes.append(m)
	minutes.sort()
	for m in minutes:
		moments.append(_make_moment(m))
	moment_idx = 0
	finished = false
	injured = false
	exhausted_flagged = false
	counter_ready = false
	in_defense = false


func _make_moment(minute: int) -> Dictionary:
	return {
		"minute": minute,
		"steps_required": rng.randi_range(2, 4),
		"difficulty": rival_difficulty + rng.randf_range(-0.05, 0.05),
	}


func current_moment() -> Dictionary:
	return moments[moment_idx]


func is_natural_executor(card: Card) -> bool:
	return card.owner_id != "" and (card.owner_id == player.player_id or player.lineup.has(card.owner_id))


func _late() -> bool:
	return moment_idx >= late_from_moment


# ---------- Flujo de un Momento Clave (posesión propia) ----------

func begin_moment() -> Dictionary:
	if moment_idx > 0:
		var max_e := player.max_energy()
		var rec: float = player.regen_normal_pct * RECOVERY_RATIO[posture] * max_e
		player.energy = minf(max_e, player.energy + rec)
	progress = 0
	fails = 0
	streak = 0
	pauses = 0
	flow_active = false
	flow_cards.clear()
	moment_had_flow = false
	moment_over = false
	if exploit_rival_space:
		var m: Dictionary = current_moment()
		m["steps_required"] = maxi(2, int(m["steps_required"]) - 1)
	if counter_ready:
		progress = 1
		counter_ready = false
	deck.reset_flow_uses()
	deck.set_possession(DeckManager.Possession.POSSESSION_ATTACK)
	deck.draw(player.hand_size())
	# Temple/Concentración: protege contra cartas de penalización mental
	if rng.randf() < 0.30 * (1.0 - player.concentracion / 100.0):
		deck.insert_into_hand(CardDB.make_penalty("nervios"))
	_check_exhaustion({})
	if playable_indices().is_empty():
		_finish_moment(false)
	return current_moment()


# El rival recuperó el balón antes de que este Momento empezara (intercepción o despeje).
func skip_moment() -> void:
	moment_over = true
	stats["moments"] += 1
	stats["skipped"] += 1


# El balón vuelve a este equipo (el rival despejó de emergencia): un ataque extra más adelante.
func grant_extra_moment(after_minute: int) -> bool:
	if injured or moments.size() >= MAX_MOMENTS or after_minute > 85:
		return false
	moments.append(_make_moment(rng.randi_range(after_minute + 3, mini(after_minute + 15, 89))))
	moments.sort_custom(func(a, b): return a["minute"] < b["minute"])
	finished = moment_idx >= moments.size()
	return true


func cost_of(card: Card) -> int:
	var c := float(card.energy_cost)
	if card.tags.has("fisica"):
		c *= 1.0 - player.ritmo / 400.0
	if flow_active:
		c += card.flow_uses          # sobreesfuerzo: +1, +2...
	if player.zone() != PlayerStats.Zone.SAFE:
		c *= TIRED_COST_MULT
	if _late():
		c *= late_cost_mult
	if exploit_rival_space and card.kind == Card.Kind.SHOT:
		c -= PASSIVITY_COST_REDUCTION
	c += float(owner_cost_surcharge.get(card.owner_id, 0))
	return maxi(1, ceili(c))


func success_chance(card: Card) -> float:
	var difficulty: float = defense_difficulty if in_defense else float(current_moment()["difficulty"])
	var p: float = player.base_success() + card.effective_bonus() - difficulty
	match player.zone():
		PlayerStats.Zone.TIRED:
			p -= TIRED_PENALTY
		PlayerStats.Zone.EXHAUSTED:
			p -= EXHAUSTED_PENALTY
	if is_natural_executor(card):
		p += NATURAL_EXECUTOR_BONUS
	p += form_bonus
	if not in_defense:
		if moment_idx < opening_moments:
			p += opening_bonus
		p -= opponent_pressure
		if card.kind == Card.Kind.SHOT:
			p -= opponent_block
			if posture == Posture.LOW:
				p -= LOW_SHOT_PENALTY
			if exploit_rival_space:
				p += exploit_shot_bonus
	return clampf(p, 0.05, 0.95)


func can_play(card: Card) -> bool:
	if not card.playable or float(cost_of(card)) > player.energy:
		return false
	if not DeckManager.fits_possession(card, deck.possession):
		return false
	return not (card.kind == Card.Kind.PAUSE and pauses >= MAX_PAUSES)


func playable_indices() -> Array[int]:
	var out: Array[int] = []
	for i in deck.hand.size():
		if can_play(deck.hand[i]):
			out.append(i)
	return out


# Juega una carta de la mano (ataque o defensa, según la fase). Devuelve un evento con todo
# lo que la UI/animación necesita.
func play_card(hand_index: int) -> Dictionary:
	if not (in_defense or not moment_over) or hand_index < 0 or hand_index >= deck.hand.size():
		return {"ok": false, "reason": "invalid"}
	var card: Card = deck.hand[hand_index]
	if not can_play(card):
		return {"ok": false, "reason": "not_playable"}

	var cost := cost_of(card)
	var p := success_chance(card)
	var natural := is_natural_executor(card)
	player.energy -= cost
	if in_defense:
		stats["defense_plays"] += 1
	else:
		stats["plays"] += 1
		if card.type == Card.Type.ELITE:
			stats["elite_plays"] += 1
		var mk := mini(moment_idx, MAX_MOMENTS - 1)
		stats["plays_m%d" % mk] += 1
		if player.zone() != PlayerStats.Zone.SAFE:
			stats["tired_plays"] += 1
			stats["tired_m%d" % mk] += 1
	var ev := {
		"ok": true, "card_id": card.id, "card_name": card.display_name, "kind": card.kind,
		"cost": cost, "chance": p, "success": false, "natural": natural, "defense": in_defense,
		"flow_started": false, "flow_broken": false, "goal": false, "injury": false, "cancelled": false,
	}
	if natural:
		stats["natural_plays"] += 1
		natural_executor_played.emit(card)
	_check_exhaustion(ev)
	_roll_injury(ev)
	var success := rng.randf() < p
	ev["success"] = success

	if in_defense:
		_resolve_defense(card, success, ev)
	else:
		_resolve_attack(card, success, natural, ev)

	ev["moment_over"] = moment_over
	ev["defense_over"] = not in_defense
	ev["energy"] = player.energy
	ev["zone"] = player.zone()
	ev["progress"] = progress
	return ev


func _resolve_attack(card: Card, success: bool, natural: bool, ev: Dictionary) -> void:
	if card.kind == Card.Kind.PAUSE:
		pauses += 1
	if success and card.kind == Card.Kind.PAUSE:
		player.energy = minf(player.max_energy(), player.energy + player.max_energy() * PAUSE_ENERGY_PCT)
		_send_to_discard(card)
	elif success:
		progress += 1
		streak += NATURAL_FLOW_CHARGE if natural else 1
		if not flow_active and streak >= player.flow_threshold():
			flow_active = true
			moment_had_flow = true
			ev["flow_started"] = true
		if flow_active:
			card.flow_uses += 1                 # la carta vuelve (se queda) en la mano
			if not flow_cards.has(card):
				flow_cards.append(card)
		else:
			_send_to_discard(card)
		if card.kind == Card.Kind.SHOT and progress >= current_moment()["steps_required"]:
			ev["goal"] = true
			_finish_moment(true)
	else:
		fails += 1
		streak = 0
		if flow_active:
			ev["flow_broken"] = true
			stats["flow_breaks"] += 1
			for c in flow_cards:
				deck.discard_from_hand(c)
			flow_cards.clear()
			flow_active = false
			player.energy = maxf(0.0, player.energy - player.max_energy() * FLOW_BREAK_LOSS_PCT)
		_send_to_discard(card)
		if fails >= MAX_FAILS:
			_finish_moment(false)

	if not moment_over and injured:
		_finish_moment(false)
	if not moment_over and playable_indices().is_empty():
		_finish_moment(false)


func abort_moment() -> void:
	if not moment_over:
		_finish_moment(false)


# Elegir postura para el siguiente momento y avanzar.
func advance(new_posture: Posture) -> void:
	posture = new_posture
	opponent_pressure = 0.0
	opponent_block = 0.0
	if posture == Posture.LOW:
		while moments.size() > LOW_MAX_MOMENTS and moments.size() > moment_idx + 1:
			moments.pop_back()
	var minute: int = moments[moment_idx]["minute"]
	if posture == Posture.HIGH and moments.size() < MAX_MOMENTS and minute < 88 \
			and rng.randf() < EXTRA_MOMENT_CHANCE_HIGH:
		moments.append(_make_moment(rng.randi_range(minute + 1, 89)))
		moments.sort_custom(func(a, b): return a["minute"] < b["minute"])
	moment_idx += 1
	if moment_idx >= moments.size():
		finished = true


# ---------- Defensa (posesión rival) ----------

# attack_difficulty: dificultad de las jugadas defensivas (calidad del ataque rival).
func begin_defense(attack_difficulty: float) -> void:
	in_defense = true
	defense_difficulty = attack_difficulty
	defense_plays = 0
	defense_result = {"pressure": 0.0, "block": 0.0, "cancelled": false, "emergency": false}
	deck.set_possession(DeckManager.Possession.POSSESSION_DEFENSE)
	deck.draw(DEFENSE_HAND_SIZE)
	if playable_indices().is_empty() and not can_emergency_clear():
		end_defense()


# Termina la defensa (también sirve para "dejar pasar") y devuelve lo que se aplica al ataque rival.
func end_defense() -> Dictionary:
	if in_defense:
		in_defense = false
		deck.discard_hand()
	return defense_result


func emergency_cost() -> int:
	return ceili(player.max_energy() * EMERGENCY_COST_PCT)


func can_emergency_clear() -> bool:
	return in_defense and not injured and float(emergency_cost()) <= player.energy


# Despeje de Emergencia: opción fija fuera del mazo. Gasta mucha energía y castiga los remates
# de este ataque, pero entrega el balón: quien arma el partido le da al rival un ataque extra
# (grant_extra_moment).
func emergency_clear() -> Dictionary:
	if not can_emergency_clear():
		return {"ok": false, "reason": "not_playable"}
	var cost := emergency_cost()
	player.energy -= cost
	stats["emergencies"] += 1
	defense_result["block"] += EMERGENCY_SHOT_PENALTY
	defense_result["emergency"] = true
	var ev := {"ok": true, "emergency": true, "cost": cost, "injury": false}
	_check_exhaustion(ev)
	_roll_injury(ev)
	end_defense()
	ev["defense_over"] = true
	ev["energy"] = player.energy
	ev["zone"] = player.zone()
	return ev


func _resolve_defense(card: Card, success: bool, ev: Dictionary) -> void:
	defense_plays += 1
	deck.discard_from_hand(card)
	if success:
		match card.kind:
			Card.Kind.PRESS:
				defense_result["pressure"] += PRESS_EFFECT
			Card.Kind.BLOCK:
				defense_result["block"] += BLOCK_EFFECT
			Card.Kind.INTERCEPT:
				defense_result["cancelled"] = true
				counter_ready = true
				stats["interceptions"] += 1
			Card.Kind.CLEARANCE:
				defense_result["cancelled"] = true
	ev["cancelled"] = defense_result["cancelled"]
	if defense_result["cancelled"] or injured or defense_plays >= DEFENSE_MAX_PLAYS \
			or playable_indices().is_empty():
		end_defense()


# ---------- Internos ----------

func _send_to_discard(card: Card) -> void:
	deck.discard_from_hand(card)
	deck.draw(1)


# Cartas de penalización al entrar en agotamiento (aquí NO se tira lesión).
func _check_exhaustion(ev: Dictionary) -> void:
	if player.zone() == PlayerStats.Zone.EXHAUSTED:
		if not exhausted_flagged:
			exhausted_flagged = true
			deck.insert_into_draw(CardDB.make_penalty("calambre"))
			deck.insert_into_draw(CardDB.make_penalty("falta_aire"))
			ev["penalties_added"] = 2
	else:
		exhausted_flagged = false


# La lesión solo se tira al jugar una carta estando en zona de agotamiento.
# Una lesión termina el partido de este equipo.
func _roll_injury(ev: Dictionary) -> void:
	if player.zone() != PlayerStats.Zone.EXHAUSTED:
		return
	var depth := clampf(1.0 - player.energy_pct() / EXHAUSTION_PCT, 0.0, 1.0)   # 0 en el borde, 1 con la barra vacía
	var chance := lerpf(INJURY_CHANCE_MIN, INJURY_CHANCE_MAX, depth)
	if _late():
		chance *= late_injury_mult
	if rng.randf() < chance:
		injured = true
		finished = true
		stats["injuries"] += 1
		ev["injury"] = true


func _finish_moment(success: bool) -> void:
	moment_over = true
	stats["moments"] += 1
	if success:
		stats["goals"] += 1
	if moment_had_flow:
		stats["flow_moments"] += 1
	flow_active = false
	flow_cards.clear()
