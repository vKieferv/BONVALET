class_name PlayerStats
extends RefCounted

enum Zone { SAFE, TIRED, EXHAUSTED }

# Atributos base (0-100)
var tecnica := 60
var vision := 60
var stamina := 60
var ritmo := 60
var concentracion := 60

# Estamina Global: la barra `energy` es el desgaste físico del partido (no paga jugadas; eso lo
# hacen los PA por turno de MatchEngine). Su tope depende del atributo `stamina`.
var energy_min := 40.0   # tope con Stamina 0
var energy_max := 70.0   # tope con Stamina 100
var regen_normal_pct := 0.22   # % del tope que se recupera entre momentos en postura NORMAL (LOW y HIGH escalan desde aquí)

# Umbral de Flow de prueba. Si es > 0, ignora la Visión. Poner 0 para volver a 2/3 por Visión.
const FLOW_THRESHOLD_TEST := 2

# Ejecutor Natural: una carta lo activa si su owner_id es player_id o uno de los titulares en cancha.
var player_id := ""
var lineup: Array[String] = []

var energy := 0.0     # Estamina Global actual
var fatigue := 0.0   # 0-100, acumulada entre partidos

# Robo por zona de estamina al iniciar un Momento: ÓPTIMO 0, CANSADO -1, AGOTADO -2 (mínimo MIN_DRAW).
const DRAW_PENALTY := {Zone.SAFE: 0, Zone.TIRED: 1, Zone.EXHAUSTED: 2}
const MIN_DRAW := 3


func max_energy() -> float:
	return lerpf(energy_min, energy_max, clampf(stamina / 100.0, 0.0, 1.0))


# Fija el tope pensando en un jugador con Stamina 60 (58 pts = valores por defecto 40/70).
func set_energy_cap(cap_at_stamina_60: float) -> void:
	energy_max = cap_at_stamina_60 * 7.0 / 5.8
	energy_min = energy_max * 4.0 / 7.0


func start_match_energy() -> void:
	energy = max_energy() * (1.0 - fatigue / 200.0)


func energy_pct() -> float:
	return energy / max_energy()


func zone() -> Zone:
	var pct := energy_pct()
	if pct >= 0.70:
		return Zone.SAFE
	if pct >= 0.30:
		return Zone.TIRED
	return Zone.EXHAUSTED


# Mano llena según la Visión: <40 -> 5, 40-69 -> 6, >=70 -> 7.
func base_hand_size() -> int:
	if vision < 40:
		return 5
	if vision < 70:
		return 6
	return 7


# Cartas a robar al empezar un Momento: la mano llena menos la penalización de la zona de estamina.
func draw_count() -> int:
	return maxi(MIN_DRAW, base_hand_size() - DRAW_PENALTY[zone()])


func flow_threshold() -> int:
	if FLOW_THRESHOLD_TEST > 0:
		return FLOW_THRESHOLD_TEST
	return 2 if vision >= 70 else 3


func base_success() -> float:
	return 0.30 + tecnica * 0.004
