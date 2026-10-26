class_name MatchEngine
extends RefCounted

enum Posture { LOW, NORMAL, HIGH }

# --- Constantes de balance (placeholders: ajustar con sim.gd) ---
const MAX_FAILS := 2                  # 2 fallos y el Momento Clave se pierde
const FLOW_BREAK_LOSS_PCT := 0.15     # energía perdida al romperse el Flow
const TIRED_COST_MULT := 1.25
const TIRED_PENALTY := 0.04
const EXHAUSTED_PENALTY := 0.10
const INJURY_CHANCE_MIN := 0.01   # al entrar en agotamiento
const INJURY_CHANCE_MAX := 0.03   # con la barra en 0
const EXHAUSTION_PCT := 0.30      # la zona de agotamiento empieza por debajo de este % de energía
const EXTRA_MOMENT_CHANCE_HIGH := 0.35
const MAX_MOMENTS := 5
# Regla de emparejamiento anti-pasividad (perfil que castiga + rival en postura LOW):
# los REMATES ganan +10 puntos de probabilidad y cuestan 1 de energía menos (mínimo 1).
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

var player: PlayerStats
var deck: DeckManager
var rng: RandomNumberGenerator
var rival_difficulty: float

var posture: Posture = Posture.NORMAL
var moments: Array = []     # [{minute, steps_required, difficulty}]
var moment_idx := 0
var finished := false
var injured := false
var exploit_rival_space := false   # lo activa SimRunner según el emparejamiento
var opening_bonus := 0.0           # bono de acierto en los primeros momentos (lo fija SimRunner desde el perfil)
var opening_moments := 0

# Estado del Momento Clave en curso
var moment_over := true
var progress := 0
var fails := 0
var streak := 0
var flow_active := false
var flow_cards: Array = []
var moment_had_flow := false
var exhausted_flagged := false

var stats := {"goals": 0, "moments": 0, "flow_moments": 0, "flow_breaks": 0, "injuries": 0,
	"plays": 0, "elite_plays": 0, "tired_plays": 0}


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


func _make_moment(minute: int) -> Dictionary:
	return {
		"minute": minute,
		"steps_required": rng.randi_range(2, 4),
		"difficulty": rival_difficulty + rng.randf_range(-0.05, 0.05),
	}


func current_moment() -> Dictionary:
	return moments[moment_idx]


# ---------- Flujo de un Momento Clave ----------

func begin_moment() -> Dictionary:
	if moment_idx > 0:
		var max_e := player.max_energy()
		var rec: float = player.regen_normal_pct * RECOVERY_RATIO[posture] * max_e
		player.energy = minf(max_e, player.energy + rec)
	progress = 0
	fails = 0
	streak = 0
	flow_active = false
	flow_cards.clear()
	moment_had_flow = false
	moment_over = false
	deck.reset_flow_uses()
	deck.discard_hand()
	deck.draw(player.hand_size())
	# Temple/Concentración: protege contra cartas de penalización mental
	if rng.randf() < 0.30 * (1.0 - player.concentracion / 100.0):
		deck.insert_into_hand(CardDB.make_penalty("nervios"))
	_check_exhaustion({})
	if playable_indices().is_empty():
		_finish_moment(false)
	return current_moment()


func cost_of(card: Card) -> int:
	var c := float(card.energy_cost)
	if card.tags.has("fisica"):
		c *= 1.0 - player.ritmo / 400.0
	if flow_active:
		c += card.flow_uses          # sobreesfuerzo: +1, +2...
	if player.zone() != PlayerStats.Zone.SAFE:
		c *= TIRED_COST_MULT
	if exploit_rival_space and card.kind == Card.Kind.SHOT:
		c -= PASSIVITY_COST_REDUCTION
	return maxi(1, ceili(c))


func success_chance(card: Card) -> float:
	var p: float = player.base_success() + card.effective_bonus() - current_moment()["difficulty"]
	match player.zone():
		PlayerStats.Zone.TIRED:
			p -= TIRED_PENALTY
		PlayerStats.Zone.EXHAUSTED:
			p -= EXHAUSTED_PENALTY
	if moment_idx < opening_moments:
		p += opening_bonus
	if posture == Posture.LOW and card.kind == Card.Kind.SHOT:
		p -= LOW_SHOT_PENALTY
	if exploit_rival_space and card.kind == Card.Kind.SHOT:
		p += PASSIVITY_SHOT_BONUS
	return clampf(p, 0.05, 0.95)


func playable_indices() -> Array[int]:
	var out: Array[int] = []
	for i in deck.hand.size():
		var c: Card = deck.hand[i]
		if c.playable and float(cost_of(c)) <= player.energy:
			out.append(i)
	return out


# Devuelve un evento con todo lo que la UI/animación necesita.
func play_card(hand_index: int) -> Dictionary:
	if moment_over or hand_index < 0 or hand_index >= deck.hand.size():
		return {"ok": false, "reason": "invalid"}
	var card: Card = deck.hand[hand_index]
	var cost := cost_of(card)
	if not card.playable or float(cost) > player.energy:
		return {"ok": false, "reason": "not_playable"}

	var p := success_chance(card)
	player.energy -= cost
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
		"cost": cost, "chance": p, "success": false,
		"flow_started": false, "flow_broken": false, "goal": false, "injury": false,
	}
	_check_exhaustion(ev)
	_roll_injury(ev)
	var success := rng.randf() < p
	ev["success"] = success

	if success:
		progress += 1
		streak += 1
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

	ev["moment_over"] = moment_over
	ev["energy"] = player.energy
	ev["zone"] = player.zone()
	ev["progress"] = progress
	return ev


func abort_moment() -> void:
	if not moment_over:
		_finish_moment(false)


# Elegir postura para el siguiente momento y avanzar.
func advance(new_posture: Posture) -> void:
	posture = new_posture
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
func _roll_injury(ev: Dictionary) -> void:
	if player.zone() != PlayerStats.Zone.EXHAUSTED:
		return
	var depth := clampf(1.0 - player.energy_pct() / EXHAUSTION_PCT, 0.0, 1.0)   # 0 en el borde, 1 con la barra vacía
	if rng.randf() < lerpf(INJURY_CHANCE_MIN, INJURY_CHANCE_MAX, depth):
		injured = true
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
	if injured:
		stats["injuries"] += 1
		finished = true
