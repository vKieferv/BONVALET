class_name MatchEngine
extends RefCounted

# Motor de un equipo en el partido. Dos recursos separados:
# - Puntos de Acción (PA): presupuesto de cada turno. Cada Momento Clave arranca con PA según la
#   postura (LOW 2, NORMAL 3, HIGH 4) y cada fase defensiva con DEFENSE_AP. No se acumulan.
# - Estamina Global (`player.energy`): desgaste del partido. La gasta cada carta jugada
#   (stamina_cost_of), se recupera entre Momentos según la postura y define el robo de cartas
#   (PlayerStats.draw_count), el riesgo de lesión y las cartas de penalización. Nunca bloquea jugadas.

## Se emite al jugar una carta cuyo dueño es el ejecutor (la UI lo usa para el resplandor).
signal natural_executor_played(card: Card)

enum Posture { LOW, NORMAL, HIGH }

# --- Constantes de balance (ajustar con core/sim.gd o godot-check -Balance) ---
const MAX_FAILS := 2                  # 2 fallos y el Momento Clave se pierde
const MIN_CHANCE := 0.05              # ninguna jugada baja de 5% ni pasa de 95%
const MAX_CHANCE := 0.95
const FLOW_BREAK_LOSS_PCT := 0.15     # estamina perdida al romperse el Flow
# Puntos de Acción por turno de ataque según la postura, y desgaste de estamina de esa postura.
# LOW conserva la base de 3 PA (así puede jugar élites de 3); su identidad es el menor desgaste,
# el castigo a los remates y el tope de momentos.
const AP_BY_POSTURE := {Posture.LOW: 3, Posture.NORMAL: 3, Posture.HIGH: 4}
const STAMINA_MULT := {Posture.LOW: 0.75, Posture.NORMAL: 1.0, Posture.HIGH: 1.5}
# Escala global del desgaste de las cartas (los JSON guardan las proporciones; esto calibra el ritmo
# de cansancio del partido con DuelRunner: CANSADO durante el segundo tiempo).
const STAMINA_SCALE := 2.0
const DEFENSE_AP := 2                 # PA de cada fase defensiva (cualquier postura)
# Lesión: solo se tira al jugar en zona de agotamiento, de MIN (al entrar) a MAX (barra en 0)
# por jugada. Calibrado para que un partido normal termine en lesión un 2-5% de las veces.
const INJURY_CHANCE_MIN := 0.004
const INJURY_CHANCE_MAX := 0.012
const EXHAUSTION_PCT := 0.30      # la zona de agotamiento empieza por debajo de este % de estamina
const EXTRA_MOMENT_CHANCE_HIGH := 0.35
const MAX_MOMENTS := 5
# Regla de emparejamiento anti-pasividad (perfil que castiga + rival en postura LOW):
# los REMATES ganan +exploit_shot_bonus puntos (por defecto 10), cuestan 1 PA menos (mínimo 1)
# y el Momento pide una jugada menos (transición rápida, mínimo 2).
const PASSIVITY_SHOT_BONUS := 0.10
const PASSIVITY_AP_REDUCTION := 1
const LOW_MAX_MOMENTS := 3        # tope de momentos propios en postura LOW
const LOW_SHOT_PENALTY := 0.15    # -15 puntos de acierto en remates en postura LOW
# Recuperación de estamina entre momentos = regen_normal_pct (22% por defecto) x este factor.
# Con NORMAL = 22%: LOW = 35% y HIGH = 8%.
const RECOVERY_RATIO := {
	Posture.LOW: 35.0 / 22.0,
	Posture.NORMAL: 1.0,
	Posture.HIGH: 8.0 / 22.0,
}
# Ejecutor Natural: la carta la juega su dueño (card.owner_id == player.player_id).
const NATURAL_EXECUTOR_BONUS := 0.15  # +15 puntos de acierto
const NATURAL_FLOW_CHARGE := 2        # la jugada cuenta doble para la racha de Flow
# Estilos de cartas firma (por tag):
const POWER_BLOCK_FACTOR := 0.5       # "potencia": el bloqueo rival cuenta la mitad en esta carta
const COLD_BLOOD_BONUS := 0.10        # "sangre_fria": +10 pts con el Momento a un fallo de perderse
# Pausa (carta de ataque): gasta PA para recuperar estamina sin sumar progreso; una por Momento.
const PAUSE_STAMINA_PCT := 0.10
const MAX_PAUSES := 1
# Defensa (posesión rival): antes de cada ataque rival se roba una mano defensiva.
const DEFENSE_HAND_SIZE := 3          # una menos si estás AGOTADO
const PRESS_EFFECT := 0.06            # Presión: +6 pts de dificultad a todas las jugadas de ese ataque
const BLOCK_EFFECT := 0.12            # Bloqueo: +12 pts de dificultad a sus remates
const EMERGENCY_STAMINA_PCT := 0.15   # Despeje de Emergencia: todos tus PA de defensa + 15% de estamina...
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
var late_stamina_mult := 1.0
var late_injury_mult := 1.0
# Semana previa (modo carrera): forma del entrenamiento y jugadores funados.
var form_bonus := 0.0            # puntos de acierto en todas las jugadas (ataque y defensa)
var owner_stamina_mult := {}     # owner_id -> multiplicador de desgaste en sus cartas (funado: 1.5)
# Defensa rival aplicada al Momento en curso (la fija quien defiende; se limpia en advance()).
var opponent_pressure := 0.0
var opponent_block := 0.0

# Puntos de Acción del turno en curso (Momento o fase defensiva)
var ap := 0
var ap_max := 0

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
	"defense_plays": 0, "interceptions": 0, "emergencies": 0, "out_of_ap": 0}


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
	# 4-5 Momentos propios por partido (calibrado con DuelRunner: con PA por turno, cada Momento es una
	# oportunidad completa); LOW juega uno menos y además queda topado en LOW_MAX_MOMENTS.
	var n := 4 + (1 if rng.randf() < 0.5 else 0)
	if posture == Posture.LOW:
		n -= 1
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
	ap = 0
	ap_max = 0


# Un Momento pide 2-3 jugadas exitosas (la última, un remate): con 2-4 PA por turno, uno de 4
# no sería alcanzable.
func _make_moment(minute: int) -> Dictionary:
	return {
		"minute": minute,
		"steps_required": rng.randi_range(2, 3),
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
	ap_max = int(AP_BY_POSTURE[posture])
	ap = ap_max
	if exploit_rival_space:
		var m: Dictionary = current_moment()
		m["steps_required"] = maxi(2, int(m["steps_required"]) - 1)
	if counter_ready:
		progress = 1
		counter_ready = false
	deck.reset_flow_uses()
	deck.set_possession(DeckManager.Possession.POSSESSION_ATTACK)
	deck.draw(player.draw_count())   # robo según la zona de estamina; no se repone por jugada
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


# PA que cuesta jugar la carta ahora: base + reusos en Flow (+1 cada uno); los remates cuestan
# 1 PA menos (mínimo 1) aprovechando los espacios de un rival replegado.
func ap_cost_of(card: Card) -> int:
	var c := card.ap_cost
	if flow_active:
		c += card.flow_uses
	if exploit_rival_space and card.kind == Card.Kind.SHOT:
		c = maxi(1, c - PASSIVITY_AP_REDUCTION)
	return c


# Estamina que gasta jugar la carta ahora: desgaste base x STAMINA_SCALE, menos si es física y hay
# buen ritmo, por la postura (LOW x0.75, HIGH x1.5), el desgaste tardío del perfil y el funado.
func stamina_cost_of(card: Card) -> float:
	var s := card.stamina_cost * STAMINA_SCALE
	if card.tags.has("fisica"):
		s *= 1.0 - player.ritmo / 400.0
	s *= float(STAMINA_MULT[posture])
	if _late():
		s *= late_stamina_mult
	s *= float(owner_stamina_mult.get(card.owner_id, 1.0))
	return s


# Desglose de la probabilidad de éxito de una carta: [{label, value}], value en puntos
# (0.10 = 10). Es la única fuente del cálculo: success_chance() lo suma y la carta lo muestra.
# La estamina no toca la probabilidad: sus zonas solo cambian el robo, la lesión y las penalizaciones.
func chance_breakdown(card: Card) -> Array:
	var items: Array = [{"label": "Base (técnica)", "value": player.base_success()}]
	if card.effective_bonus() != 0.0:
		items.append({"label": "Carta", "value": card.effective_bonus()})
	if in_defense:
		items.append({"label": "Ataque rival", "value": -defense_difficulty})
	else:
		items.append({"label": "Defensa rival", "value": -float(current_moment()["difficulty"])})
	if is_natural_executor(card):
		items.append({"label": "Ejecutor Natural", "value": NATURAL_EXECUTOR_BONUS})
	if form_bonus != 0.0:
		items.append({"label": "Entrenamiento", "value": form_bonus})
	if not in_defense:
		if moment_idx < opening_moments and opening_bonus != 0.0:
			items.append({"label": "Apertura", "value": opening_bonus})
		if opponent_pressure != 0.0:
			items.append({"label": "Presión rival", "value": -opponent_pressure})
		if card.tags.has("sangre_fria") and fails == MAX_FAILS - 1:
			items.append({"label": "Sangre fría", "value": COLD_BLOOD_BONUS})
		if card.kind == Card.Kind.SHOT:
			if opponent_block != 0.0:
				items.append({"label": "Bloqueo rival", "value": -opponent_block})
				if card.tags.has("potencia"):
					items.append({"label": "Potencia", "value": opponent_block * (1.0 - POWER_BLOCK_FACTOR)})
			if posture == Posture.LOW:
				items.append({"label": "Postura LOW", "value": -LOW_SHOT_PENALTY})
			if exploit_rival_space:
				items.append({"label": "Espacios del rival", "value": exploit_shot_bonus})
	return items


# Probabilidad de éxito (0-1) redondeada a puntos enteros: el 88% que muestra la carta es
# exactamente el 0.88 contra el que se tira (rng.randf() < 0.88, o sea, tirada 0-99 menor que 88).
func success_chance(card: Card) -> float:
	var p := 0.0
	for item in chance_breakdown(card):
		p += float(item["value"])
	return roundi(clampf(p, MIN_CHANCE, MAX_CHANCE) * 100.0) / 100.0


# Se puede jugar si alcanzan los PA del turno. La estamina nunca bloquea (agotado se juega igual,
# con riesgo de lesión).
func can_play(card: Card) -> bool:
	if not card.playable or ap_cost_of(card) > ap:
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

	var ap_cost := ap_cost_of(card)
	var stamina := stamina_cost_of(card)
	var p := success_chance(card)
	var natural := is_natural_executor(card)
	ap -= ap_cost
	player.energy = maxf(0.0, player.energy - stamina)
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
		"ap": ap_cost, "stamina": stamina, "chance": p, "success": false, "natural": natural,
		"defense": in_defense, "flow_started": false, "flow_broken": false, "goal": false,
		"injury": false, "cancelled": false, "out_of_ap": false,
	}
	if natural:
		stats["natural_plays"] += 1
		natural_executor_played.emit(card)
	_check_exhaustion(ev)
	_roll_injury(ev)
	var roll := rng.randf()
	var success := roll < p   # p es la misma que mostraba la carta antes de jugarla
	ev["roll"] = roll
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
	ev["ap_left"] = ap
	return ev


func _resolve_attack(card: Card, success: bool, natural: bool, ev: Dictionary) -> void:
	if card.kind == Card.Kind.PAUSE:
		pauses += 1
	if success and card.kind == Card.Kind.PAUSE:
		player.energy = minf(player.max_energy(), player.energy + player.max_energy() * PAUSE_STAMINA_PCT)
		deck.discard_from_hand(card)
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
			deck.discard_from_hand(card)
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
		deck.discard_from_hand(card)
		if fails >= MAX_FAILS:
			_finish_moment(false)

	if not moment_over and injured:
		_finish_moment(false)
	if not moment_over and playable_indices().is_empty():
		# Sin PA (o sin cartas) para seguir: la jugada se pierde.
		ev["out_of_ap"] = true
		stats["out_of_ap"] += 1
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
	ap_max = DEFENSE_AP
	ap = ap_max
	deck.set_possession(DeckManager.Possession.POSSESSION_DEFENSE)
	deck.draw(defense_draw_count())
	if playable_indices().is_empty() and not can_emergency_clear():
		end_defense()


func defense_draw_count() -> int:
	return DEFENSE_HAND_SIZE - (1 if player.zone() == PlayerStats.Zone.EXHAUSTED else 0)


# Termina la defensa (también sirve para "dejar pasar") y devuelve lo que se aplica al ataque rival.
func end_defense() -> Dictionary:
	if in_defense:
		in_defense = false
		deck.discard_hand()
	return defense_result


func emergency_stamina_cost() -> float:
	return player.max_energy() * EMERGENCY_STAMINA_PCT


# Pide al menos 1 PA de defensa; gasta todos los que queden.
func can_emergency_clear() -> bool:
	return in_defense and not injured and ap >= 1


# Despeje de Emergencia: opción fija fuera del mazo. Gasta todos tus PA de defensa y 15% de
# estamina y castiga los remates de este ataque, pero entrega el balón: quien arma el partido le
# da al rival un ataque extra (grant_extra_moment).
func emergency_clear() -> Dictionary:
	if not can_emergency_clear():
		return {"ok": false, "reason": "not_playable"}
	var stamina := emergency_stamina_cost()
	var ap_spent := ap
	ap = 0
	player.energy = maxf(0.0, player.energy - stamina)
	stats["emergencies"] += 1
	defense_result["block"] += EMERGENCY_SHOT_PENALTY
	defense_result["emergency"] = true
	var ev := {"ok": true, "emergency": true, "ap": ap_spent, "stamina": stamina, "injury": false}
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
	if defense_result["cancelled"] or injured \
			or (playable_indices().is_empty() and not can_emergency_clear()):
		end_defense()


# ---------- Internos ----------

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
