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
# de cansancio del partido con DuelRunner: CANSADO durante el segundo tiempo). Bajó de 2.0 a 1.6 al
# llegar Aguantar el Balón (más jugadas por Momento) para dejar las lesiones en 2-5%.
const STAMINA_SCALE := 1.6
const DEFENSE_AP := 2                 # PA de cada fase defensiva (cualquier postura)
# Lesión: solo se tira al jugar en zona de agotamiento, de MIN (al entrar) a MAX (barra en 0)
# por jugada. Calibrado para que un partido normal termine en lesión un 2-5% de las veces
# (MAX bajó de 0.012 a 0.009 porque Aguantar el Balón suma jugadas estando agotado).
const INJURY_CHANCE_MIN := 0.004
const INJURY_CHANCE_MAX := 0.009
const EXHAUSTION_PCT := 0.30      # la zona de agotamiento empieza por debajo de este % de estamina
const EXTRA_MOMENT_CHANCE_HIGH := 0.35
const MAX_MOMENTS := 5
# Jugadas exitosas que pide cada Momento (la última, un remate). Con remates a 2 PA y Aguantar el
# Balón, 3 sostienen 2.3-2.6 goles (D-12). Es el valor por defecto de `moment_steps`: Catenaccio
# pide 2 (D-16, sube a Palestino de 0.72 a 1.18 goles). El contragolpe (counter_ready) y el espacio
# rival (exploit_rival_space) acortan el Momento, pero nunca por debajo de 2 jugadas.
const MOMENT_STEPS := 3
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
# Aguantar el Balón (temporizar, fuera del mazo): una vez por Momento. Cuesta 1 PA y 3 de estamina;
# si no quedan PA cuesta 0 y, si sale bien, da +1 PA. Éxito = 80% menos la Presión rival: descarta
# la mano, corta el Flow sin penalización y roba una mano nueva según la zona de estamina.
# Fallo = el rival roba el balón (Momento perdido) y queda con contragolpe (lo aplica quien arma el partido).
const HOLD_BASE_CHANCE := 0.80
const HOLD_AP_COST := 1
const HOLD_STAMINA := 3.0
const MAX_HOLDS := 1
# Pausa (carta de ataque): gasta PA para recuperar estamina sin sumar progreso; una por Momento.
const PAUSE_STAMINA_PCT := 0.10
const MAX_PAUSES := 1
# Defensa (posesión rival): antes de cada ataque rival se roba una mano defensiva.
const DEFENSE_HAND_SIZE := 3          # una menos si estás AGOTADO
const PRESS_EFFECT := 0.06            # Presión: +6 pts de dificultad a todas las jugadas de ese ataque
const BLOCK_EFFECT := 0.12            # Bloqueo: +12 pts de dificultad a sus remates
const EMERGENCY_STAMINA_PCT := 0.15   # Despeje de Emergencia: todos tus PA de defensa + 15% de estamina...
const EMERGENCY_SHOT_PENALTY := 0.25  # ...-25 pts a los remates de ese ataque, y el rival recupera el balón

# --- Partido por zonas (D-36, T-10): modo en prueba, apagado por defecto (zone_mode) ---
# Las jugadas del Momento son zonas: Salida (tu línea de atrás contra sus delanteros), Medio (medio
# contra medio) y Área (tus delanteros contra su defensa). Remates solo en el Área (los tiros
# lejanos, también desde el Medio), fallar no corta el Momento (sin MAX_FAILS) y un fallo en la
# Salida o el Medio puede ser robo con contragolpe rival. Valores de prueba: cada motor los copia en
# variables (zone_*) para que tests/balance_lab.gd los varíe sin tocar estas constantes.
enum Zone { SALIDA, MEDIO, AREA }
const ZONE_NAMES := ["Salida", "Medio", "Área"]
const ZONE_STEAL_SALIDA := 0.25       # un fallo en la Salida es robo 1 de cada 4 veces...
const ZONE_STEAL_MEDIO := 1.0 / 6.0   # ...y en el Medio, 1 de cada 6 (el Área no tiene robo)
const ZONE_NUMBERS_PTS := 0.12        # 12 pts por jugador de diferencia entre tu línea y la suya (D-30 decía 6;
# con 6 pts por jugador la matriz del modo de zonas daba 2.83 goles; con 12, 2.52: balance-lab, T-10)
const ZONE_LINE_FACTOR := 0.5         # pts por punto de skill_rating de diferencia entre las líneas
const LONG_SHOT_PENALTY := 0.15       # tiro lejano desde el Medio: -15 pts por la distancia
const ZONE_FAIL_STAMINA := 0.5        # un fallo gasta además la mitad del desgaste de la carta
const ZONE_SAVE_CHANCE := 0.5         # remate fallado: la mitad, el arquero se queda (fin, sin contragolpe)

# --- Modo de duelos (D-40, T-13): en prueba, apagado por defecto (duel_mode, exige zone_mode) ---
# La carta la juega el portador; el pase elige un receptor de la zona siguiente; el rival reparte sus
# marcas en cada zona (CoachBot.assign_marks) y se enfrentan las habilidades: Pase contra Lectura del
# mejor marcador del receptor, Regate contra Quite del mejor marcador del portador, Remate contra
# Atajada. % = base fija + carta + factor × (tu habilidad − la suya) + marcas: reemplaza la técnica, la
# dificultad rival y los números y la fuerza de la zona. Valores de prueba, en variables duel_* para
# que tests/balance_lab.gd los varíe.
const DUEL_BASE := 0.39               # base 54 de hoy menos la defensa rival de 15 (D-32)
const DUEL_SKILL_FACTOR := 0.5        # pts por punto de habilidad de diferencia (×0,5 de prueba)
const DUEL_MARK_PTS := 0.12           # libre +12, 1 contra 1 = 0, cada marcador extra −12
const DUEL_PELOTAZO_FACTOR := 0.5     # el Pelotazo no pelea: sus marcas cuentan la mitad (usuario, 2026-11-02)
const DUEL_NATURAL_BONUS := 0.05      # Ejecutor Natural: solo si la carta es del portador (D-32)
# D-42: cada marcador extra (el que no pelea el duelo) resta su habilidad para esa jugada ÷ este valor
# (Lectura contra un pase, Quite contra un regate o un remate): un defensa resta más que un delantero que
# presiona. 0 = el −DUEL_MARK_PTS fijo por marcador de D-40.
const DUEL_MARK_DIVISOR := 6.0
# D-42, transición: en un Momento que nace de una recuperación (contragolpe), en el Medio y el Área te
# esperan solo los rivales que se quedaron atrás al atacar, según su estilo: [en su defensa, en su medio].
# Su postura mueve uno en la defensa (HIGH uno menos, LOW uno más). Valores de prueba.
const TRANSITION_STAY := {
	"Kamikaze": [2, 2], "Tiki-Taka": [3, 3], "Directo": [3, 2], "Contragolpe": [4, 3], "Catenaccio": [5, 3],
}
const TRANSITION_STAY_DEFAULT := [4, 3]
# D-43, presión al portador: quien lo marca le resta en sus pases su Quite ÷ este valor (12 = la mitad de
# la resta de un marcador extra; se midió también 6). 0 = sin presión en los pases (D-42).
const DUEL_PRESS_DIVISOR := 12.0
# Orden de los puestos de atrás hacia adelante: reparte a los titulares en las líneas de la formación.
const ROLE_DEPTH := {"DFC": 0, "LAT": 1, "MCD": 2, "MCO": 3, "EXT": 4, "DEL": 5}

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
var moment_steps := MOMENT_STEPS   # jugadas que pide cada Momento propio (Catenaccio 2: más goles para el bloque bajo)
# Semana previa (modo carrera): forma del entrenamiento y jugadores funados.
var form_bonus := 0.0            # puntos de acierto en todas las jugadas (ataque y defensa)
var owner_stamina_mult := {}     # owner_id -> multiplicador de desgaste en sus cartas (funado: 1.5)
# Defensa rival aplicada al Momento en curso (la fija quien defiende; se limpia en advance()).
var opponent_pressure := 0.0
var opponent_block := 0.0
# Partido por zonas (D-36). Las líneas van como [atrás, medio, arriba]: formation = jugadores por línea
# según el estilo (D-30; un 4.º valor opcional es el tope de arriba, el 5-3-2 nunca más de 3) y
# line_strength = promedio de skill_rating de los titulares de cada línea. Las de este equipo las
# pasa quien arma el partido (SquadManager.zone_data); las del rival, set_zone_rival() antes de cada ataque.
var zone_mode := false
var zone := Zone.SALIDA
var formation: Array = []
var line_strength: Array = []
var rival_formation: Array = []
var rival_line_strength: Array = []
var rival_posture: Posture = Posture.NORMAL
var zone_steal_salida := ZONE_STEAL_SALIDA
var zone_steal_medio := ZONE_STEAL_MEDIO
var zone_numbers_pts := ZONE_NUMBERS_PTS
var zone_line_factor := ZONE_LINE_FACTOR
var long_shot_penalty := LONG_SHOT_PENALTY
var zone_low_shot_penalty := true   # false: en el modo de zonas, LOW no castiga los remates (D-36, regla 4)
# Modo de duelos (D-40). Los titulares van como datos simples (SquadManager.duel_data):
# {id, name, role, pase, regate, remate, quite, lectura, atajada}; los del rival y su estilo de marca
# los copia set_zone_rival() antes de cada ataque.
var duel_mode := false
var duel_players: Array = []
var mark_style := ""                # estilo de este equipo al marcar (su arquetipo)
var rival_players: Array = []
var rival_mark_style := ""
var duel_base := DUEL_BASE
var duel_skill_factor := DUEL_SKILL_FACTOR
var duel_mark_pts := DUEL_MARK_PTS
var duel_pelotazo_factor := DUEL_PELOTAZO_FACTOR
var duel_natural_bonus := DUEL_NATURAL_BONUS
var duel_shot_adjust := 0.0         # puntos que se suman a los remates en este modo (propuesta: −10)
var duel_mark_divisor := DUEL_MARK_DIVISOR
var duel_transition := true         # false: en el contragolpe el rival te espera con su formación completa (D-40)
var transition := false             # el Momento en curso nació de una recuperación (D-42)
var duel_short_play := true         # D-43: en los Momentos de 2 jugadas el Área se reparte con los que se quedan atrás
var short_play := false             # el Momento en curso es una jugada corta con el Área desordenada (D-43)
var duel_press_divisor := DUEL_PRESS_DIVISOR
var duel_bot_lookahead := true      # D-43: CoachBot elige receptor y portador mirando una jugada más (no cambia reglas)
var carrier: Dictionary = {}        # el portador: juega las cartas del Momento
var carrier_extra := false          # llegó a esta zona con un regate: el rival lo cuenta al repartir
var carrier_chosen := false         # quien juega ya eligió el portador de la Salida (set_carrier)
var marks := {}                     # zona -> {id de tu jugador: [sus marcadores, del mejor al peor]}
var touches := {}                   # id -> veces que fue portador en el partido
var moment_plays := 0               # jugadas del Momento en curso (el portador se elige antes de la primera)
var _my_lines: Array = [[], [], []]
var _their_lines: Array = [[], [], []]

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
var holds := 0
var counter_ready := false   # tras una intercepción, el próximo Momento propio arranca con 1 jugada (si pide más de 2)

# Estado de la defensa en curso
var in_defense := false
var defense_difficulty := 0.0
var defense_plays := 0
var defense_result := {}     # {pressure, block, cancelled, emergency}

var stats := {"goals": 0, "moments": 0, "flow_moments": 0, "flow_breaks": 0, "injuries": 0,
	"plays": 0, "elite_plays": 0, "tired_plays": 0, "natural_plays": 0, "skipped": 0,
	"defense_plays": 0, "interceptions": 0, "emergencies": 0, "out_of_ap": 0, "holds": 0, "holds_lost": 0,
	"counters": 0, "steals": 0, "saves": 0, "rebounds": 0,
	"dribble_entries": 0, "dribble_doubled": 0, "back_plays": 0,
	"transition_moments": 0, "transition_goals": 0, "salida_steals": 0, "salida_steals_fwd": 0,
	"salida_steal_skill": 0, "short_moments": 0, "short_goals": 0}
# counters: Momentos propios que arrancaron con contragolpe. steals / saves / rebounds (modo de zonas):
# fallos que fueron robo, remates fallados que se quedó el arquero y remates fallados con rebote.
# Modo de duelos: dribble_entries = regates que entraron a otra zona; dribble_doubled = de ellos, los
# que terminaron con el portador en marca doble o más; back_plays = vueltas atrás que salieron bien.


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
	# 4 Momentos propios por partido (calibrado con DuelRunner junto con los remates a 2 PA y Aguantar
	# el Balón); LOW juega uno menos y HIGH puede sumar momentos extra en advance().
	var n := 4
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
	touches.clear()


# Un Momento pide moment_steps jugadas exitosas (la última, un remate); el contragolpe y el espacio
# rival lo acortan, con un mínimo de 2.
func _make_moment(minute: int) -> Dictionary:
	return {
		"minute": minute,
		"steps_required": moment_steps,
		"difficulty": rival_difficulty + rng.randf_range(-0.05, 0.05),
	}


func current_moment() -> Dictionary:
	return moments[moment_idx]


func is_natural_executor(card: Card) -> bool:
	if duel_on():   # modo de duelos: solo si la carta es del portador; la firma de otro la juega él, sin bono
		return card.owner_id != "" and card.owner_id == String(carrier.get("id", ""))
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
	holds = 0
	flow_active = false
	flow_cards.clear()
	moment_had_flow = false
	moment_over = false
	ap_max = int(AP_BY_POSTURE[posture])
	ap = ap_max
	# Zonas: se arranca en la Salida; el contragolpe y el espacio rival arrancan en el Medio.
	zone = Zone.SALIDA
	transition = counter_ready and duel_on()
	if exploit_rival_space:
		var m: Dictionary = current_moment()
		var before := int(m["steps_required"])
		m["steps_required"] = maxi(2, before - 1)
		if int(m["steps_required"]) < before:
			zone = Zone.MEDIO
	if counter_ready:
		if moment_steps > 2:   # con Momentos de 2 (Catenaccio) el contragolpe no lo acorta más
			progress = 1
		counter_ready = false
		stats["counters"] += 1
		zone = Zone.MEDIO
	_advance_zone(0)
	if duel_on():
		_duel_begin()
	deck.reset_flow_uses()
	deck.set_possession(DeckManager.Possession.POSSESSION_ATTACK)
	deck.draw(player.draw_count())   # robo según la zona de estamina; no se repone por jugada
	# Temple/Concentración: protege contra cartas de penalización mental
	if rng.randf() < 0.30 * (1.0 - player.concentracion / 100.0):
		deck.insert_into_hand(CardDB.make_penalty("nervios"))
	_check_exhaustion({})
	if playable_indices().is_empty() and not can_hold():
		stats["out_of_ap"] += 1
		_finish_moment(false)
	return current_moment()


# Zona tras sumar `steps` avances: a una jugada del final siempre es el Área; si no, se avanza una
# zona por avance (el Pelotazo, que vale 2, se salta una). Momentos de 2 jugadas: Salida y Área.
func _advance_zone(steps: int) -> void:
	if int(current_moment()["steps_required"]) - progress <= 1:
		zone = Zone.AREA
	else:
		zone = mini(Zone.AREA, zone + steps) as Zone


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
# at_zone (modo de zonas): calcula como si la jugada fuera en esa zona (el planificador del bot mira
# las jugadas que vienen); -1 = la zona actual.
# receiver (modo de duelos): id del compañero que recibe un pase; "" = el mejor receptor (best_receiver).
func chance_breakdown(card: Card, at_zone: int = -1, receiver: String = "") -> Array:
	var duel := duel_on()
	var items: Array = [{"label": "Base", "value": duel_base}] if duel \
			else [{"label": "Base (técnica)", "value": player.base_success()}]
	if card.effective_bonus() != 0.0:
		items.append({"label": "Carta", "value": card.effective_bonus()})
	if in_defense:
		items.append({"label": "Ataque rival", "value": -defense_difficulty})
	elif not duel:   # en el modo de duelos la defensa rival son sus marcas y sus habilidades
		items.append({"label": "Defensa rival", "value": -float(current_moment()["difficulty"])})
	if is_natural_executor(card):
		items.append({"label": "Ejecutor Natural", "value": duel_natural_bonus if duel else NATURAL_EXECUTOR_BONUS})
	if form_bonus != 0.0:
		items.append({"label": "Entrenamiento", "value": form_bonus})
	if not in_defense:
		if moment_idx < opening_moments and opening_bonus != 0.0:
			items.append({"label": "Apertura", "value": opening_bonus})
		if opponent_pressure != 0.0:
			items.append({"label": "Presión rival", "value": -opponent_pressure})
		# Sangre fría: a un fallo de perder el Momento; en el modo de zonas (sin MAX_FAILS), después de
		# cualquier fallo del Momento (opción conservadora, la decide el usuario).
		if card.tags.has("sangre_fria") and (fails >= 1 if zone_mode else fails == MAX_FAILS - 1):
			items.append({"label": "Sangre fría", "value": COLD_BLOOD_BONUS})
		if card.kind == Card.Kind.SHOT:
			if opponent_block != 0.0:
				items.append({"label": "Bloqueo rival", "value": -opponent_block})
				if card.tags.has("potencia"):
					items.append({"label": "Potencia", "value": opponent_block * (1.0 - POWER_BLOCK_FACTOR)})
			if posture == Posture.LOW and (not zone_mode or zone_low_shot_penalty):
				items.append({"label": "Postura LOW", "value": -LOW_SHOT_PENALTY})
			if exploit_rival_space:
				items.append({"label": "Espacios del rival", "value": exploit_shot_bonus})
		if duel:
			_duel_items(card, zone if at_zone < 0 else at_zone, receiver, items)
		elif zone_mode:
			_zone_items(card, zone if at_zone < 0 else at_zone, items)
	return items


# Números de la zona (D-36, regla 3): jugadores de tu línea contra los de la suya (con la postura de
# cada uno) y la fuerza de las líneas; y el castigo del tiro lejano desde el Medio.
func _zone_items(card: Card, z: int, items: Array) -> void:
	var mine := lines_for(formation, posture)
	var theirs := lines_for(rival_formation, rival_posture)
	var mine_line := z               # Salida: tu línea de atrás; Medio: el medio; Área: arriba
	var their_line := 2 - z          # ...contra sus delanteros, su medio y su defensa
	if not mine.is_empty() and not theirs.is_empty() and mine[mine_line] != theirs[their_line]:
		items.append({"label": "%s: %d contra %d" % [ZONE_NAMES[z], mine[mine_line], theirs[their_line]],
			"value": float(mine[mine_line] - theirs[their_line]) * zone_numbers_pts})
	if line_strength.size() == 3 and rival_line_strength.size() == 3 and zone_line_factor != 0.0:
		var diff := float(line_strength[mine_line]) - float(rival_line_strength[their_line])
		if diff != 0.0:
			items.append({"label": "Fuerza de línea", "value": diff * zone_line_factor / 100.0})
	if card.kind == Card.Kind.SHOT and card.long_range and z == Zone.MEDIO:
		items.append({"label": "Tiro de lejos", "value": -long_shot_penalty})


# Los números de la zona (los mismos de chance_breakdown, sin los de la carta) para mostrarlos en la UI.
func zone_breakdown(at_zone: int = -1) -> Array:
	var items: Array = []
	if zone_mode:
		_zone_items(Card.new(), zone if at_zone < 0 else at_zone, items)
	return items


# Jugadores por línea [atrás, medio, arriba] de una formación con la postura: en HIGH uno del medio
# sube y en LOW uno baja (D-30); el 4.º valor de la formación, si está, es el tope de arriba.
static func lines_for(f: Array, p: Posture) -> Array:
	if f.size() < 3:
		return []
	var out := [int(f[0]), int(f[1]), int(f[2])]
	var max_up := int(f[3]) if f.size() > 3 else 99
	if p == Posture.HIGH and out[1] > 0 and out[2] < max_up:
		out[1] -= 1
		out[2] += 1
	elif p == Posture.LOW and out[1] > 0:
		out[1] -= 1
		out[0] += 1
	return out


# Antes de cada ataque en el modo de zonas: las líneas y la postura del equipo que defiende.
func set_zone_rival(rival: MatchEngine) -> void:
	rival_formation = rival.formation
	rival_line_strength = rival.line_strength
	rival_posture = rival.posture
	rival_players = rival.duel_players   # modo de duelos: sus titulares y cómo reparte las marcas
	rival_mark_style = rival.mark_style


# Probabilidad de éxito (0-1) redondeada a puntos enteros: el 88% que muestra la carta es
# exactamente el 0.88 contra el que se tira (rng.randf() < 0.88, o sea, tirada 0-99 menor que 88).
func success_chance(card: Card, at_zone: int = -1, receiver: String = "") -> float:
	var p := 0.0
	for item in chance_breakdown(card, at_zone, receiver):
		p += float(item["value"])
	var pts := clampf(p, MIN_CHANCE, MAX_CHANCE) * 100.0
	if duel_on():
		pts += 0.0001   # los medios puntos del duelo (×0,5) suben, sin que la coma flotante los baje (28,5 → 29)
	return roundi(pts) / 100.0


# Modo de zonas: probabilidad de que jugar la carta termine en robo (fallar × robo de la zona), en
# puntos enteros. Es la única fuente del "robo %" de la carta y la tirada usa exactamente este número:
# con la misma tirada de play_card, roll < success_chance es éxito y roll ≥ 1 − steal_chance es robo.
# Los remates y la Pausa no tienen robo; el Área tampoco.
func steal_chance(card: Card, at_zone: int = -1, receiver: String = "") -> float:
	if not zone_mode or in_defense or card.kind == Card.Kind.SHOT or card.kind == Card.Kind.PAUSE:
		return 0.0
	var z := zone if at_zone < 0 else at_zone
	var s := zone_steal_salida if z == Zone.SALIDA else (zone_steal_medio if z == Zone.MEDIO else 0.0)
	return roundi((1.0 - success_chance(card, at_zone, receiver)) * s * 100.0) / 100.0


# Modo de zonas: probabilidad de que un remate termine con la pelota en manos del arquero (fallar ×
# ZONE_SAVE_CHANCE); el resto de los fallos es rebote. Misma tirada que steal_chance.
func save_chance(card: Card, at_zone: int = -1, receiver: String = "") -> float:
	if not zone_mode or in_defense or card.kind != Card.Kind.SHOT:
		return 0.0
	return roundi((1.0 - success_chance(card, at_zone, receiver)) * ZONE_SAVE_CHANCE * 100.0) / 100.0


# Modo de zonas: por qué no se puede jugar la carta en esta zona ("" = se puede). Remates solo en el
# Área; los tiros lejanos, también desde el Medio. Modo de duelos: un pase necesita un compañero en la
# zona a la que va, y volver atrás, una zona anterior.
func zone_block_reason(card: Card) -> String:
	if duel_on() and is_pass(card):
		if card.back and zone == Zone.SALIDA:
			return "NO HAY ZONA ANTERIOR"
		return "SIN COMPAÑERO" if receivers(card).is_empty() else ""
	if not zone_mode or in_defense or card.kind != Card.Kind.SHOT or zone == Zone.AREA:
		return ""
	if card.long_range:
		return "" if zone == Zone.MEDIO else "DESDE EL MEDIO"
	return "SOLO EN EL ÁREA"


# Se puede jugar si alcanzan los PA del turno. La estamina nunca bloquea (agotado se juega igual,
# con riesgo de lesión). receiver (modo de duelos): el pase solo a un compañero de la zona siguiente.
func can_play(card: Card, receiver: String = "") -> bool:
	if not card.playable or ap_cost_of(card) > ap:
		return false
	if not DeckManager.fits_possession(card, deck.possession):
		return false
	if zone_mode and zone_block_reason(card) != "":
		return false
	if receiver != "" and duel_on() and is_pass(card) \
			and not receivers(card).any(func(r): return r["id"] == receiver):
		return false
	return not (card.kind == Card.Kind.PAUSE and pauses >= MAX_PAUSES)


func playable_indices() -> Array[int]:
	var out: Array[int] = []
	for i in deck.hand.size():
		if can_play(deck.hand[i]):
			out.append(i)
	return out


# Juega una carta de la mano (ataque o defensa, según la fase). Devuelve un evento con todo
# lo que la UI/animación necesita. receiver (modo de duelos): a quién va el pase; "" = el mejor receptor.
func play_card(hand_index: int, receiver: String = "") -> Dictionary:
	if not (in_defense or not moment_over) or hand_index < 0 or hand_index >= deck.hand.size():
		return {"ok": false, "reason": "invalid"}
	var card: Card = deck.hand[hand_index]
	var duel := duel_on()
	if duel and is_pass(card) and receiver == "":
		receiver = best_receiver(card)
	if not can_play(card, receiver):
		return {"ok": false, "reason": "not_playable"}

	var ap_cost := ap_cost_of(card)
	var stamina := stamina_cost_of(card)
	var p := success_chance(card, -1, receiver)
	var steal := steal_chance(card, -1, receiver)   # modo de zonas: lo que mostraba la carta antes de jugarla
	var save := save_chance(card, -1, receiver)
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
	if zone_mode and not in_defense:
		ev["play_zone"] = zone   # zona de la cancha donde se jugó la carta
		ev["steal_chance"] = steal
		ev["save_chance"] = save
	if duel:
		ev["carrier"] = String(carrier.get("id", ""))   # quién jugó la carta
		ev["receiver"] = receiver                      # a quién iba el pase ("" si no es pase)
		moment_plays += 1
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
		if duel and ev.get("stolen", false) and int(ev.get("play_zone", -1)) == Zone.SALIDA:
			_count_salida_steal(card, receiver, ev)

	ev["moment_over"] = moment_over
	ev["defense_over"] = not in_defense
	ev["energy"] = player.energy
	ev["zone"] = player.zone()   # zona de estamina; la de la cancha: "play_zone" (antes) y "field_zone" (después)
	if zone_mode and not ev["defense"]:
		ev["field_zone"] = zone
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
		var back := duel_on() and card.back
		if back:   # modo de duelos: la pelota vuelve a la zona anterior (deshace un avance)
			progress = maxi(0, progress - 1)
		else:
			progress += card.steps   # casi siempre 1; un Pelotazo vale 2
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
		# En el modo de zonas un remate solo se juega en el Área (o de lejos desde el Medio): si entra, es gol.
		if card.kind == Card.Kind.SHOT and (zone_mode or progress >= current_moment()["steps_required"]):
			ev["goal"] = true
			_finish_moment(true)
		elif back:
			zone = maxi(Zone.SALIDA, zone - 1) as Zone
			_duel_after_success(card, String(ev.get("receiver", "")), ev)
		else:
			var zone_before := zone
			_advance_zone(card.steps)
			if duel_on():
				_duel_after_success(card, String(ev.get("receiver", "")), ev, zone_before)
		if card.draw > 0 and not moment_over:
			ev["drawn"] = deck.draw(card.draw)   # la jugada abre opciones: roba cartas de ataque
	elif zone_mode:
		_resolve_zone_fail(card, ev)
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

	_end_if_stuck(ev)


# Fallo en el modo de zonas (D-36, regla 2): no corta el Momento, el límite es la mano. Cuesta la
# mitad del desgaste de la carta; en la Salida o el Medio puede ser robo (Momento perdido y
# contragolpe rival: quien arma el partido lee ev["stolen"], como al aguantar); un remate fallado
# termina en manos del arquero (fin, sin contragolpe) o en rebote (sigues donde estabas).
# Usa la misma tirada de la jugada: roll ≥ 1 − steal_chance (o save_chance) es robo (o atajada).
func _resolve_zone_fail(card: Card, ev: Dictionary) -> void:
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
	var extra := float(ev["stamina"]) * ZONE_FAIL_STAMINA
	player.energy = maxf(0.0, player.energy - extra)
	ev["fail_stamina"] = extra
	var roll: float = ev["roll"]
	if card.kind == Card.Kind.SHOT:
		if roll >= 1.0 - float(ev["save_chance"]):
			ev["saved"] = true
			stats["saves"] += 1
			_finish_moment(false)
		else:
			ev["rebound"] = true
			stats["rebounds"] += 1
	elif roll >= 1.0 - float(ev["steal_chance"]):
		ev["stolen"] = true
		stats["steals"] += 1
		_finish_moment(false)


# Sin PA (o sin cartas) para seguir y sin Aguantar disponible: la jugada se pierde. Con Aguantar
# disponible, el Momento sigue abierto para que el jugador elija Aguantar o Ceder.
func _end_if_stuck(ev: Dictionary) -> void:
	if not moment_over and injured:
		_finish_moment(false)
	if not moment_over and playable_indices().is_empty() and not can_hold():
		ev["out_of_ap"] = true
		stats["out_of_ap"] += 1
		_finish_moment(false)


func abort_moment() -> void:
	if not moment_over:
		_finish_moment(false)


# ---------- Modo de duelos (D-40, T-13) ----------

func duel_on() -> bool:
	return duel_mode and zone_mode and not in_defense and not duel_players.is_empty()


# Las cartas que eligen receptor: pases y centros (también el Pelotazo y la vuelta atrás).
static func is_pass(card: Card) -> bool:
	return card.kind == Card.Kind.PASS or card.kind == Card.Kind.CROSS


# Regate y control: el portador sigue con la pelota.
static func is_dribble(card: Card) -> bool:
	return card.kind == Card.Kind.DRIBBLE or card.kind == Card.Kind.CONTROL


# Lo peligroso que es un jugador con la pelota: su mejor habilidad de ataque (el rival marca primero
# al más peligroso).
static func threat(pl: Dictionary) -> float:
	return maxf(float(pl.get("pase", 0)), maxf(float(pl.get("regate", 0)), float(pl.get("remate", 0))))


# Titulares de campo repartidos en las líneas [atrás, medio, arriba] de la formación con la postura
# (lines_for), de atrás hacia adelante según el puesto (ROLE_DEPTH): en el 4-3-3 los extremos juegan
# arriba y en LOW baja el volante más defensivo. Sin formación, cada uno en la línea de su puesto.
static func lines_of(players: Array, f: Array, p: Posture) -> Array:
	var order: Array = []
	for i in players.size():
		var role := String(players[i].get("role", ""))
		if ROLE_DEPTH.has(role):
			order.append([int(ROLE_DEPTH[role]) * 100 + i, players[i]])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = [[], [], []]
	var counts := lines_for(f, p)
	for item in order:
		if counts.is_empty():
			var depth: int = int(item[0]) / 100
			out[0 if depth <= 1 else (2 if depth >= 5 else 1)].append(item[1])
			continue
		var line := 0
		while line < 2 and (out[line] as Array).size() >= int(counts[line]):
			line += 1
		out[line].append(item[1])
	return out


static func keeper_of(players: Array) -> Dictionary:
	for pl in players:
		if String(pl.get("role", "")) == "POR":
			return pl
	return {}


# Tus jugadores de la línea que juega en la zona z.
func zone_players(z: int) -> Array:
	return _my_lines[z]


# Marcadores de tu jugador `id` en la zona z, del mejor al peor; [] = libre.
func markers_of(z: int, id: String) -> Array:
	return (marks.get(z, {}) as Dictionary).get(id, [])


func carrier_markers() -> Array:
	return markers_of(zone, String(carrier.get("id", "")))


# Zona a la que va la pelota si la carta sale bien jugada desde z: la vuelta atrás, a la anterior; el
# resto avanza como _advance_zone (el Pelotazo se salta una; a una jugada del final, el Área).
func target_zone(card: Card, z: int = -1) -> int:
	if z < 0:
		z = zone
	if card.back:
		return maxi(Zone.SALIDA, z - 1)
	if z == zone and int(current_moment()["steps_required"]) - (progress + card.steps) <= 1:
		return Zone.AREA
	return mini(Zone.AREA, z + card.steps)


# Compañeros que pueden recibir el pase: los de la línea de la zona a la que va, menos el portador.
func receivers(card: Card, z: int = -1) -> Array:
	if not is_pass(card):
		return []
	var cid := String(_assumed_carrier(zone if z < 0 else z).get("id", ""))
	return zone_players(target_zone(card, z)).filter(func(r): return r["id"] != cid)


# El receptor con el mejor % para la carta ("" si no hay ninguno).
func best_receiver(card: Card) -> String:
	var best := ""
	var best_p := -1.0
	for r in receivers(card):
		var p := success_chance(card, -1, r["id"])
		if p > best_p:
			best_p = p
			best = r["id"]
	return best


# Quien juega elige al portador de la primera zona antes de la primera jugada del Momento.
func set_carrier(id: String) -> bool:
	if not duel_on() or moment_plays > 0:
		return false
	for pl in zone_players(zone):
		if pl["id"] == id:
			if not carrier.is_empty():   # el toque del portador por defecto pasa al elegido
				touches[carrier["id"]] = int(touches.get(carrier["id"], 1)) - 1
			carrier = pl
			carrier_chosen = true
			_touch()
			return true
	return false


# Para planear las zonas que vienen: el compañero de esa línea al que más conviene darle la pelota (el
# menos marcado y, a igualdad, el más peligroso). En la zona actual, el portador.
func _assumed_carrier(z: int) -> Dictionary:
	if z == zone:
		return carrier
	return _least_marked(zone_players(z), z, "")


func _least_marked(players: Array, z: int, skip_id: String) -> Dictionary:
	var best := {}
	var best_key := -INF
	for pl in players:
		if pl["id"] == skip_id:
			continue
		var key := -100.0 * markers_of(z, pl["id"]).size() + threat(pl)
		if key > best_key:
			best_key = key
			best = pl
	return best


func _player_by_id(id: String) -> Dictionary:
	for pl in duel_players:
		if pl["id"] == id:
			return pl
	return {}


# Al empezar el Momento: líneas de los dos equipos con su postura, marcas de las tres zonas (las de la
# zona siguiente siempre se ven) y el portador por defecto de la primera zona (el menos marcado y más
# peligroso; quien juega lo cambia con set_carrier antes de la primera jugada).
func _duel_begin() -> void:
	_my_lines = lines_of(duel_players, formation, posture)
	_their_lines = lines_of(rival_players, rival_formation, rival_posture)
	short_play = false
	if transition:
		stats["transition_moments"] += 1
	if transition and duel_transition:   # D-42: solo te esperan los que se quedaron atrás (los más defensivos de cada línea)
		var stay := transition_stay(rival_mark_style, rival_posture)
		for line in 2:
			_their_lines[line] = (_their_lines[line] as Array).slice(0, stay[line])
	elif duel_short_play and int(current_moment()["steps_required"]) <= 2:
		# D-43, jugada corta: en los Momentos de 2 jugadas (Catenaccio) el Área del rival se reparte con los
		# que se quedan atrás al atacar, como en una transición.
		_their_lines[0] = (_their_lines[0] as Array).slice(0, transition_stay(rival_mark_style, rival_posture)[0])
		short_play = true
		stats["short_moments"] += 1
	carrier_extra = false
	carrier_chosen = false
	moment_plays = 0
	carrier = {}
	marks.clear()
	_redistribute_from(Zone.SALIDA)
	carrier = _least_marked(zone_players(zone), zone, "")
	_touch()


# El rival reparte sus marcas en las zonas desde z (su línea que defiende esa zona sobre tus jugadores).
func _redistribute_from(z: int) -> void:
	for zz in range(z, Zone.AREA + 1):
		var attackers: Array = zone_players(zz).duplicate()
		if carrier_extra and zz == zone and not attackers.has(carrier):
			attackers.append(carrier)   # llegó con un regate: el rival lo cuenta
		marks[zz] = CoachBot.assign_marks(attackers, _their_lines[2 - zz], rival_mark_style, rng)


func _touch() -> void:
	if not carrier.is_empty():
		touches[carrier["id"]] = int(touches.get(carrier["id"], 0)) + 1


# Tras una jugada que sale bien: el pase le da la pelota al receptor (la vuelta atrás hace que el rival
# reparta de nuevo); el regate que entra a otra zona sigue con el portador y el rival reparte contándolo.
func _duel_after_success(card: Card, receiver: String, ev: Dictionary, zone_before: int = -1) -> void:
	if is_pass(card):
		var r := _player_by_id(receiver)
		if not r.is_empty():
			carrier = r
			carrier_extra = false
			_touch()
		if card.back:
			stats["back_plays"] += 1
			_redistribute_from(zone)
	elif is_dribble(card) and zone != zone_before:
		carrier_extra = not zone_players(zone).has(carrier)
		_redistribute_from(zone)
		stats["dribble_entries"] += 1
		var n := carrier_markers().size()
		if n >= 2:
			stats["dribble_doubled"] += 1
		ev["carrier_markers"] = n
	ev["new_carrier"] = String(carrier.get("id", ""))


# Duelos y marcas del desglose (D-40): el pase, contra la Lectura del mejor marcador del receptor y
# sus marcas (el Pelotazo no pelea: solo sus marcas, por duel_pelotazo_factor); el regate y el control,
# contra el Quite del mejor marcador del portador y sus marcas; el remate, contra la Atajada del
# arquero y las marcas del portador. La Pausa no tiene duelo.
func _duel_items(card: Card, z: int, receiver: String, items: Array) -> void:
	if card.kind == Card.Kind.SHOT:
		if card.long_range and z == Zone.MEDIO:
			items.append({"label": "Tiro de lejos", "value": -long_shot_penalty})
		if duel_shot_adjust != 0.0:
			items.append({"label": "Remates (duelos)", "value": duel_shot_adjust})
	var c := _assumed_carrier(z)
	if c.is_empty() or card.kind == Card.Kind.PAUSE:
		return
	if is_pass(card):
		var tz := target_zone(card, z)
		var r := {}
		if receiver != "":
			r = _player_by_id(receiver)
		elif z == zone:
			r = _player_by_id(best_receiver(card))
		else:
			r = _least_marked(zone_players(tz), tz, String(c["id"]))
		if r.is_empty():
			return
		_press_item(c, markers_of(z, c["id"]), items)
		var m := markers_of(tz, r["id"])
		if card.steps >= 2 and not card.back:   # Pelotazo: sin duelo, se salta la línea
			_mark_item(r, m, duel_pelotazo_factor, items, "lectura")
			return
		if not m.is_empty():
			_duel_item("Pase", c, "Lectura", _best_by(m, "lectura"), items)
		_mark_item(r, m, 1.0, items, "lectura")
	elif card.kind == Card.Kind.SHOT:
		var keeper := keeper_of(rival_players)
		if not keeper.is_empty():
			_duel_item("Remate", c, "Atajada", keeper, items)
		_mark_item(c, markers_of(z, c["id"]), 1.0, items, "quite")
	elif is_dribble(card):
		var m := markers_of(z, c["id"])
		if not m.is_empty():
			_duel_item("Regate", c, "Quite", _best_by(m, "quite"), items)
		_mark_item(c, m, 1.0, items, "quite")


static func _best_by(players: Array, skill: String) -> Dictionary:
	var best: Dictionary = players[0]
	for pl in players:
		if int(pl.get(skill, 0)) > int(best.get(skill, 0)):
			best = pl
	return best


# "Duelo: Pase 66 contra Lectura 75 (Manuel Iturra)" · factor × (tu habilidad − la suya).
func _duel_item(mine: String, attacker: Dictionary, theirs: String, defender: Dictionary, items: Array) -> void:
	var a := int(attacker.get(mine.to_lower(), 0))
	var d := int(defender.get(theirs.to_lower(), 0))
	items.append({"label": "Duelo: %s %d contra %s %d (%s)" % [mine, a, theirs, d, defender.get("name", "")],
		"value": duel_skill_factor * float(a - d) / 100.0})


# D-43, presión al portador: cada uno que marca al que tiene la pelota le resta en sus pases su Quite ÷
# duel_press_divisor (12 = la mitad de la resta normal; 0 = sin presión), en una línea propia.
func _press_item(c: Dictionary, markers: Array, items: Array) -> void:
	if duel_press_divisor <= 0.0:
		return
	for m in markers:
		items.append({"label": "Presión de %s (Quite %d)" % [m.get("name", ""), int(m.get("quite", 0))],
			"value": -float(m.get("quite", 0)) / duel_press_divisor / 100.0})


# Robo en tu Salida (medición de D-42 y D-43): quién se la quedó. En un regate, o en un pase con el
# portador presionado, el mejor Quite de los que marcan al portador (sus delanteros que presionan); en un
# pase sin presión, la mejor Lectura de los que marcan al receptor. salida_steals_fwd cuenta los que hizo
# un delantero que presiona y salida_steal_skill suma su Quite.
func _count_salida_steal(card: Card, receiver: String, ev: Dictionary) -> void:
	stats["salida_steals"] += 1
	var stealer := {}
	var pressers := markers_of(Zone.SALIDA, String(carrier.get("id", "")))
	if is_pass(card) and (duel_press_divisor <= 0.0 or pressers.is_empty()):
		var m := markers_of(target_zone(card, Zone.SALIDA), receiver)
		if not m.is_empty():
			stealer = _best_by(m, "lectura")
	elif not pressers.is_empty():
		stealer = _best_by(pressers, "quite")
	if stealer.is_empty():
		return
	ev["stealer"] = stealer["id"]
	if (_their_lines[2] as Array).has(stealer):
		stats["salida_steals_fwd"] += 1
		stats["salida_steal_skill"] += int(stealer.get("quite", 0))


# Cuántos rivales se quedaron atrás al atacar (D-42), [en su defensa, en su medio], según su estilo y su
# postura: HIGH deja uno menos en la defensa y LOW uno más. Nunca menos de uno.
static func transition_stay(style: String, p: Posture) -> Array:
	var stay: Array = (TRANSITION_STAY.get(style, TRANSITION_STAY_DEFAULT) as Array).duplicate()
	if p == Posture.HIGH:
		stay[0] -= 1
	elif p == Posture.LOW:
		stay[0] += 1
	return [maxi(1, int(stay[0])), maxi(1, int(stay[1]))]


# "Marca de Matías Fernández: 1 contra 2 · Marcelo Díaz (Lectura 67)" · libre +duel_mark_pts, 1 contra 1
# = 0 y cada marcador extra (los que no pelean el duelo) resta su `skill` ÷ duel_mark_divisor (D-42; con
# divisor 0, −duel_mark_pts fijo como en D-40). Todo × factor (el Pelotazo, la mitad).
func _mark_item(who: Dictionary, markers: Array, factor: float, items: Array, skill: String) -> void:
	var n := markers.size()
	var label := "Marca de %s: %s" % [who.get("name", ""), "libre" if n == 0 else "1 contra %d" % n]
	var value := duel_mark_pts if n == 0 else 0.0
	if n >= 2:
		var duelist := markers.find(_best_by(markers, skill))   # el que pelea el duelo no resta acá
		var extras: Array = []
		for i in n:
			if i == duelist:
				continue
			var m: Dictionary = markers[i]
			if duel_mark_divisor > 0.0:
				value -= float(m.get(skill, 0)) / duel_mark_divisor / 100.0
				extras.append("%s (%s %d)" % [m.get("name", ""), skill.capitalize(), int(m.get(skill, 0))])
			else:
				value -= duel_mark_pts
				extras.append(String(m.get("name", "")))
		label += " · " + ", ".join(extras)
	items.append({"label": label, "value": value * factor})


# ---------- Aguantar el Balón ----------

func can_hold() -> bool:
	return not in_defense and not moment_over and not injured and holds < MAX_HOLDS


# 1 PA, o 0 si no quedan (y entonces el éxito da +1 PA).
func hold_ap_cost() -> int:
	return HOLD_AP_COST if ap >= HOLD_AP_COST else 0


# Desglose de la tirada de retención (misma transparencia que las cartas).
func hold_breakdown() -> Array:
	var items: Array = [{"label": "Base", "value": HOLD_BASE_CHANCE}]
	if opponent_pressure != 0.0:
		items.append({"label": "Presión rival", "value": -opponent_pressure})
	return items


func hold_chance() -> float:
	var p := 0.0
	for item in hold_breakdown():
		p += float(item["value"])
	return roundi(clampf(p, MIN_CHANCE, MAX_CHANCE) * 100.0) / 100.0


# Aguantar el Balón. Devuelve un evento como play_card (con "hold", "stolen" y "ap_gained").
func hold_ball() -> Dictionary:
	if not can_hold():
		return {"ok": false, "reason": "not_playable"}
	var cost := hold_ap_cost()
	var p := hold_chance()
	holds += 1
	stats["holds"] += 1
	ap -= cost
	player.energy = maxf(0.0, player.energy - HOLD_STAMINA)
	var ev := {"ok": true, "hold": true, "ap": cost, "stamina": HOLD_STAMINA, "chance": p,
		"success": false, "stolen": false, "ap_gained": 0, "injury": false, "out_of_ap": false,
		"goal": false, "flow_started": false, "flow_broken": false, "natural": false, "defense": false}
	_check_exhaustion(ev)
	_roll_injury(ev)
	var roll := rng.randf()
	ev["roll"] = roll
	ev["success"] = roll < p
	if ev["success"]:
		# Temporizar corta el Flow sin la penalización de estamina y renueva la mano.
		flow_active = false
		flow_cards.clear()
		streak = 0
		deck.discard_hand()
		deck.draw(player.draw_count())
		if cost == 0:
			ap += 1
			ev["ap_gained"] = 1
		_end_if_stuck(ev)
	else:
		ev["stolen"] = true
		stats["holds_lost"] += 1
		_finish_moment(false)
	ev["moment_over"] = moment_over
	ev["energy"] = player.energy
	ev["zone"] = player.zone()
	ev["progress"] = progress
	ev["ap_left"] = ap
	return ev


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
		if card.counter:
			counter_ready = true   # recuperas arriba: tu próximo Momento arranca con 1 jugada
		match card.kind:
			Card.Kind.PRESS:
				defense_result["pressure"] += card.effect if card.effect >= 0.0 else PRESS_EFFECT
			Card.Kind.BLOCK:
				defense_result["block"] += card.effect if card.effect >= 0.0 else BLOCK_EFFECT
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
		if transition:
			stats["transition_goals"] += 1
		if short_play:
			stats["short_goals"] += 1
	if moment_had_flow:
		stats["flow_moments"] += 1
	flow_active = false
	flow_cards.clear()
