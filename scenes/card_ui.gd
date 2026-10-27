class_name CardUI
extends Control

# Carta de la mano. Muestra los dos costos por separado (PA del turno en la insignia de arriba,
# desgaste de estamina abajo) y la probabilidad de éxito, todo ya calculado por el motor.

const AP_COLOR := Color("#e3b341")        # dorado: Puntos de Acción (igual que el orbe del HUD)
const STAMINA_COLOR := Color("#58a6ff")   # celeste: Estamina Global
const UP_COLOR := Color("#f0883e")        # cuesta más que lo impreso (reuso en Flow, postura, funado)
const DOWN_COLOR := Color("#3fb950")      # cuesta menos que lo impreso
const EFFECT_COLOR := Color("#b392f0")    # violeta: lo que hace la carta además de su jugada

signal chosen(ui: CardUI)

const TYPE_COLORS := {
    Card.Type.BASIC: Color("#8a9bb0"),
    Card.Type.TACTICAL: Color("#4299e1"),
    Card.Type.ELITE: Color("#ecc94b"),
    Card.Type.PENALTY: Color("#e53e3e"),
}
const TYPE_NAMES := {
    Card.Type.BASIC: "BÁSICA",
    Card.Type.TACTICAL: "TÁCTICA",
    Card.Type.ELITE: "ÉLITE",
    Card.Type.PENALTY: "PENALIZACIÓN",
}
const KIND_NAMES := {
    Card.Kind.CONTROL: "Control",
    Card.Kind.PASS: "Pase",
    Card.Kind.DRIBBLE: "Regate",
    Card.Kind.CROSS: "Centro",
    Card.Kind.SHOT: "Remate",
    Card.Kind.PAUSE: "Pausa",
    Card.Kind.PRESS: "Defensa · Presión",
    Card.Kind.BLOCK: "Defensa · Bloqueo",
    Card.Kind.INTERCEPT: "Defensa · Intercepción",
    Card.Kind.CLEARANCE: "Defensa · Despeje",
}

# Estilos de carta (tags con efecto en MatchEngine); se explican en el tooltip.
const TAG_TEXT := {
    "potencia": "Potencia: el bloqueo rival cuenta la mitad en este remate.",
    "sangre_fria": "Sangre fría: +10 de acierto con la jugada a un fallo de perderse.",
    "fisica": "Física: gasta menos estamina con buen ritmo.",
}

var card: Card
var hand_index := -1
var interactive := true
var slot_hidden := false

var _style: StyleBoxFlat
var _ap_style: StyleBoxFlat
var _tween: Tween
var _cost_tip := ""

@onready var body: PanelContainer = $Body
@onready var ap_badge: PanelContainer = $Body/VBox/TopRow/ApBadge
@onready var ap_label: Label = $Body/VBox/TopRow/ApBadge/ApLabel
@onready var type_label: Label = $Body/VBox/TopRow/TypeLabel
@onready var name_label: Label = $Body/VBox/NameLabel
@onready var kind_label: Label = $Body/VBox/KindLabel
@onready var effect_label: Label = $Body/VBox/EffectLabel
@onready var chance_label: Label = $Body/VBox/ChanceLabel
@onready var mod_label: Label = $Body/VBox/ModLabel
@onready var cost_label: Label = $Body/VBox/CostLabel
@onready var glow: ColorRect = $Body/Glow


func _ready() -> void:
    _style = StyleBoxFlat.new()
    _style.bg_color = Color("#1b2230")
    _style.set_corner_radius_all(12)
    _style.set_border_width_all(3)
    _style.set_content_margin_all(8)
    body.add_theme_stylebox_override("panel", _style)
    _ap_style = StyleBoxFlat.new()
    _ap_style.bg_color = AP_COLOR
    _ap_style.set_corner_radius_all(8)
    _ap_style.set_content_margin_all(2)
    ap_badge.add_theme_stylebox_override("panel", _ap_style)
    ap_label.add_theme_color_override("font_color", Color("#141b29"))
    glow.material = FlowGlow.make_material(Color("#ff7a18"))
    body.resized.connect(_on_body_resized)
    mouse_entered.connect(_on_enter)
    mouse_exited.connect(_on_exit)
    _on_body_resized()


func setup(c: Card, index: int) -> void:
    card = c
    hand_index = index
    var col: Color = TYPE_COLORS[c.type]
    _style.border_color = col
    type_label.text = TYPE_NAMES[c.type]
    type_label.add_theme_color_override("font_color", col)
    name_label.text = c.display_name
    kind_label.text = "No jugable" if c.type == Card.Type.PENALTY else KIND_NAMES.get(c.kind, "")
    if c.owner_id != "":
        kind_label.text += " ★"   # carta firma: tiene Ejecutor Natural
    effect_label.text = effect_text(c)
    effect_label.visible = effect_label.text != ""
    effect_label.add_theme_color_override("font_color", EFFECT_COLOR)


# Efecto de la carta en una línea corta (pilar 2: lo que hace se ve en la carta); "" si no tiene uno
# propio. El detalle va en el tooltip (effect_tip). smoke_match compara esta línea con la carta.
static func effect_text(c: Card) -> String:
    var parts: Array = []
    for e in _effects(c):
        parts.append(e[0])
    return " · ".join(parts)


static func effect_tip(c: Card) -> String:
    var parts: Array = []
    for e in _effects(c):
        parts.append(e[1])
    return "\n".join(parts)


# [texto corto, detalle] por cada efecto: avances, robo, fuerza propia, contragolpe y cortes.
static func _effects(c: Card) -> Array:
    var out: Array = []
    if c == null or c.type == Card.Type.PENALTY:
        return out
    if c.steps > 1:
        out.append(["Avanza %d" % c.steps, "Si sale, cuenta como %d jugadas del Momento." % c.steps])
    if c.draw > 0:
        var cards := "carta" if c.draw == 1 else "cartas"
        out.append(["Si sale, robas %d %s" % [c.draw, cards], "Si sale, robas %d %s de ataque para seguir la jugada." % [c.draw, cards]])
    if c.effect >= 0.0 and c.kind == Card.Kind.PRESS:
        out.append(["Presión %+d" % roundi(c.effect * 100.0), "Si sale, todas las jugadas de ese ataque rival pierden %d pts (una Presión normal, %d)." % [
            roundi(c.effect * 100.0), roundi(MatchEngine.PRESS_EFFECT * 100.0)]])
    elif c.effect >= 0.0 and c.kind == Card.Kind.BLOCK:
        out.append(["Bloqueo %+d" % roundi(c.effect * 100.0), "Si sale, los remates de ese ataque rival pierden %d pts (un Bloqueo normal, %d)." % [
            roundi(c.effect * 100.0), roundi(MatchEngine.BLOCK_EFFECT * 100.0)]])
    var counter_tip := "tu próximo Momento arranca con una jugada hecha (contragolpe; no acorta los Momentos de 2 jugadas)."
    if c.kind == Card.Kind.INTERCEPT:
        out.append(["Corta + contragolpe", "Si sale, corta el ataque rival entero y " + counter_tip])
    elif c.kind == Card.Kind.CLEARANCE:
        out.append(["Corta el ataque", "Si sale, corta el ataque rival entero."])
    elif c.counter:
        out.append(["Si sale, contragolpe", "Si sale, " + counter_tip])
    return out


# ap = PA que cuesta ahora (con reusos en Flow, etc.), base_ap = PA impresos en la carta,
# stamina = desgaste de estamina que tendrá al jugarla.
# chance = MatchEngine.success_chance() y breakdown = MatchEngine.chance_breakdown(): el % que se
# muestra es exactamente el que usa la tirada, y el desglose explica de dónde sale.
func update_stats(ap: int, base_ap: int, stamina: float, chance: float, usable: bool, glow_on: bool,
        breakdown: Array = []) -> void:
    mod_label.text = ""
    tooltip_text = ""
    if card != null and card.type == Card.Type.PENALTY:
        ap_badge.visible = false
        chance_label.text = "—"
        cost_label.text = "Sin efecto"
        chance_label.add_theme_color_override("font_color", Color("#a0aec0"))
        cost_label.add_theme_color_override("font_color", Color("#a0aec0"))
    else:
        # Insignia de PA: dorada; naranja si hoy cuesta más de lo impreso, verde si menos.
        ap_badge.visible = true
        ap_label.text = "%d PA" % ap
        _ap_style.bg_color = UP_COLOR if ap > base_ap else (DOWN_COLOR if ap < base_ap else AP_COLOR)
        chance_label.text = "%d%%" % roundi(chance * 100.0)
        var cc := Color("#3fb950") if chance >= 0.65 else (Color("#ecc94b") if chance >= 0.45 else Color("#f85149"))
        chance_label.add_theme_color_override("font_color", cc)
        # Desgaste: celeste; naranja si la postura, el desgaste tardío o una funa lo suben.
        var printed := card.stamina_cost * MatchEngine.STAMINA_SCALE
        if card.kind == Card.Kind.PAUSE:
            cost_label.text = "Recupera %d%% Est." % roundi(MatchEngine.PAUSE_STAMINA_PCT * 100.0)
            cost_label.add_theme_color_override("font_color", DOWN_COLOR)
        else:
            cost_label.text = "Desgaste: %d Est." % roundi(stamina)
            var sc := STAMINA_COLOR
            if stamina > printed + 0.5:
                sc = UP_COLOR
            elif stamina < printed - 0.5:
                sc = DOWN_COLOR
            cost_label.add_theme_color_override("font_color", sc)
        _cost_tip = "Cuesta %d PA del turno · desgasta %d de estamina" % [ap, roundi(stamina)]
        _show_breakdown(breakdown, chance)
        var tip := effect_tip(card)
        if tip != "":
            tooltip_text = tip if tooltip_text == "" else tooltip_text + "\n" + tip
    glow.visible = glow_on
    body.modulate = Color.WHITE if usable else Color(0.55, 0.55, 0.62)
    if slot_hidden:
        modulate.a = 0.0


# Línea corta con los modificadores (sin base, carta ni dificultad) y el desglose completo en el tooltip.
func _show_breakdown(breakdown: Array, chance: float) -> void:
    var mods: Array = []
    var tip: Array = [_cost_tip] if _cost_tip != "" else []
    var penalized := false
    for item in breakdown:
        var pts := roundi(float(item["value"]) * 100.0)
        tip.append("%s: %+d" % [item["label"], pts])
        if item["label"] not in ["Base (técnica)", "Carta", "Defensa rival", "Ataque rival"]:
            mods.append("%s %+d" % [item["label"], pts])
            penalized = penalized or pts < 0
    if breakdown.is_empty():
        return
    tip.append("= %d%% (tirada de 0 a 99: éxito si sale menos de %d)" % [roundi(chance * 100.0), roundi(chance * 100.0)])
    for tag in card.tags:
        if TAG_TEXT.has(tag):
            tip.append(TAG_TEXT[tag])
    tooltip_text = "\n".join(tip)
    mod_label.text = " · ".join(mods)
    mod_label.add_theme_color_override("font_color", Color("#f85149") if penalized else Color("#ecc94b"))


func set_interactive(v: bool) -> void:
    interactive = v


func hide_slot() -> void:
    slot_hidden = true
    modulate.a = 0.0


func flash(color: Color) -> void:
    _style.border_color = color
    _style.set_border_width_all(6)


# Resplandor de Ejecutor Natural (reemplaza el naranjo del Flow en esta carta).
func natural_glow(color: Color) -> void:
    glow.material = FlowGlow.make_material(color, 1.6)
    glow.visible = true


func shake() -> void:
    var t := create_tween()
    for dx in [-8.0, 8.0, -5.0, 5.0, 0.0]:
        t.tween_property(body, "position:x", dx, 0.04)


func appear(delay: float) -> void:
    modulate.a = 0.0
    await get_tree().process_frame
    if not is_instance_valid(self):
        return
    body.position.y = 70.0
    var t := create_tween().set_parallel(true)
    t.tween_property(self, "modulate:a", 1.0, 0.25).set_delay(delay)
    t.tween_property(body, "position:y", 0.0, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_enter() -> void:
    if interactive:
        _lift(-32.0, 1.07)


func _on_exit() -> void:
    if interactive:
        _lift(0.0, 1.0)


func _lift(y: float, s: float) -> void:
    if _tween != null:
        _tween.kill()
    _tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween.tween_property(body, "position:y", y, 0.14)
    _tween.tween_property(body, "scale", Vector2(s, s), 0.14)


func _on_body_resized() -> void:
    body.pivot_offset = body.size / 2.0


func _gui_input(event: InputEvent) -> void:
    if not interactive:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        chosen.emit(self)
