class_name BotProfile
extends Resource

# Perfil de comportamiento de un bot. A futuro lo define el Entrenador (DT).
# Al ser un Resource, también se puede crear/editar como .tres desde el Inspector.

@export var profile_name := "Directo"
## 0 = cierra la jugada cuanto antes. 1 = encadena el Flow con las mejores cartas aunque suba el costo.
@export_range(0.0, 1.0, 0.05) var flow_aggression := 0.5
## 0 = gasta sin mirar el costo. 1 = cuida cada punto de energía. También define qué tan cerrado defiende (defense_rating).
@export_range(0.0, 1.0, 0.05) var energy_conservation := 0.5
## Reserva mínima de energía (% del tope) que debe quedar tras pagar una carta de élite.
## -1 = derivarla de energy_conservation.
@export_range(-1.0, 1.0, 0.05) var energy_reserve_threshold := -1.0
## 0 = evita las cartas de élite. 1 = las prioriza apenas puede pagarlas.
@export_range(0.0, 1.0, 0.05) var elite_preference := 0.5
## Cuanto más baja, más evita jugadas poco fiables (penaliza las cartas con baja probabilidad de éxito).
## -1 = sin filtro de riesgo (comportamiento original).
@export_range(-1.0, 1.0, 0.05) var risk_tolerance := -1.0
## Si el mejor remate tiene menos de esta probabilidad, el bot enfría la jugada con
## pases seguros (hasta stall_plays) o la cede sin rematar. -1 = remata siempre.
@export_range(-1.0, 1.0, 0.05) var shot_min_chance := -1.0
@export_range(0, 5, 1) var stall_plays := 0
## Bono de acierto (en puntos, 0.05 = +5%) a todas las jugadas de los primeros `opening_moments` Momentos Clave.
@export_range(0.0, 0.3, 0.01) var opening_bonus := 0.0
@export_range(0, 5, 1) var opening_moments := 2
## Desgaste tardío: desde el Momento Clave `late_from_moment` (0 = primero) los costos de energía
## y el riesgo de lesión se multiplican. 5 = nunca.
@export_range(0, 5, 1) var late_from_moment := 5
@export_range(1.0, 3.0, 0.05) var late_cost_mult := 1.0
@export_range(1.0, 10.0, 0.5) var late_injury_mult := 1.0
## Postura entre Momentos Clave: 0 = Baja (LOW), 1 = Normal, 2 = Alta (HIGH).
@export_enum("Baja (LOW)", "Normal", "Alta (HIGH)") var default_posture := 1
## Regla de emparejamiento: si el rival juega en postura LOW, este perfil aprovecha los espacios
## (+probabilidad y -costo en remates; valores en MatchEngine.PASSIVITY_*).
@export var punishes_passivity := false
## Puntos de acierto extra en remates al castigar la pasividad.
@export_range(0.0, 0.3, 0.01) var passivity_shot_bonus := MatchEngine.PASSIVITY_SHOT_BONUS


# Traspasa al motor todo lo que depende solo del perfil. exploit_rival_space depende también
# de la postura del rival, así que lo fija quien arma el partido.
func configure_engine(e: MatchEngine) -> void:
    e.posture = default_posture as MatchEngine.Posture
    e.opening_bonus = opening_bonus
    e.opening_moments = opening_moments
    e.late_from_moment = late_from_moment
    e.late_cost_mult = late_cost_mult
    e.late_injury_mult = late_injury_mult
    e.exploit_shot_bonus = passivity_shot_bonus


# Energía mínima (como % del tope) que debe quedar tras pagar una carta de élite.
func elite_reserve_pct() -> float:
    if energy_reserve_threshold >= 0.0:
        return energy_reserve_threshold
    return lerpf(0.05, 0.60, energy_conservation)


# 0 = muy abierto (Kamikaze), 1 = muy cerrado (Catenaccio). Mezcla conservación y postura.
func defense_rating() -> float:
    return (energy_conservation + (1.0 - default_posture / 2.0)) / 2.0


func describe() -> String:
    var s := "Flow %d%%  |  Conserva energía %d%%  |  Élite %d%%  |  Postura %s" % [
        roundi(flow_aggression * 100.0), roundi(energy_conservation * 100.0),
        roundi(elite_preference * 100.0), ["LOW", "NORMAL", "HIGH"][default_posture]]
    if energy_reserve_threshold >= 0.0:
        s += "  |  Reserva élite %d%%" % roundi(energy_reserve_threshold * 100.0)
    if risk_tolerance >= 0.0:
        s += "  |  Riesgo %d%%" % roundi(risk_tolerance * 100.0)
    if opening_bonus > 0.0:
        s += "  |  +%d%% acierto en M1-M%d" % [roundi(opening_bonus * 100.0), opening_moments]
    if late_from_moment < MatchEngine.MAX_MOMENTS and (late_cost_mult > 1.0 or late_injury_mult > 1.0):
        s += "  |  Desde M%d: costo x%.1f, lesión x%.1f" % [late_from_moment + 1, late_cost_mult, late_injury_mult]
    if shot_min_chance >= 0.0:
        s += "  |  Remata desde %d%%" % roundi(shot_min_chance * 100.0)
    if punishes_passivity:
        s += "  |  Castiga la pasividad (+%d%% remates)" % roundi(passivity_shot_bonus * 100.0)
    return s


static func make(p_name: String, flow: float, conserve: float, elite: float, posture: int) -> BotProfile:
    var p := BotProfile.new()
    p.profile_name = p_name
    p.flow_aggression = flow
    p.energy_conservation = conserve
    p.elite_preference = elite
    p.default_posture = posture
    return p


static func tiki_taka() -> BotProfile:
    return make("Tiki-Taka", 0.8, 0.55, 0.15, 1)

static func catenaccio() -> BotProfile:
    var p := make("Catenaccio", 0.2, 0.9, 0.05, 0)
    p.shot_min_chance = 0.40
    p.stall_plays = 2
    return p

static func directo() -> BotProfile:
    return make("Directo", 0.5, 0.4, 0.5, 1)

# Presión asfixiante: +20 pts de acierto en M1-M2; desde M3, fatiga doble y lesiones disparadas.
static func kamikaze() -> BotProfile:
    var p := make("Kamikaze", 1.0, 0.0, 1.0, 2)
    p.energy_reserve_threshold = 0.10
    p.opening_bonus = 0.20
    p.opening_moments = 2
    p.late_from_moment = 2
    p.late_cost_mult = 2.0
    p.late_injury_mult = 4.0
    return p

# Reactivo: reserva equilibrada, no persigue el Flow, élite solo para definir,
# riesgo moderado-bajo y castiga a los rivales pasivos.
static func contragolpe() -> BotProfile:
    var p := make("Contragolpe", 0.30, 0.50, 0.50, 1)
    p.energy_reserve_threshold = 0.45
    p.risk_tolerance = 0.40
    p.punishes_passivity = true
    return p


static func presets() -> Array:
    return [tiki_taka(), catenaccio(), directo(), kamikaze(), contragolpe()]
