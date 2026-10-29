class_name CardUI
extends Control

# Lámina de álbum (D-37), la misma en la semana y en el partido: doble marco impreso del color de la
# jugada, banda con el tipo ("RASGO" o ★ si la carta es de un jugador), moneda de PA arriba a la
# derecha, sello negro con el bono, ventana con trama de puntos y el dibujo de la jugada, nombre,
# palabras clave en vez de oraciones y pie con el desgaste de estamina.
# En el partido (update_stats) suma la silueta del que la juega si la carta tiene dueño (camiseta del
# club y puesto, sin cara), la placa de TV con el % que se tira (el número siempre visible) y, si no se
# puede jugar, una cinta con el motivo en vez de verse apagada. Todo lo que muestra ya lo calculó el
# motor. Se dibuja por código desde su tamaño (_layout y _draw_body): se ve nítida en la mano, en el
# sobre del entrenamiento y en el mazo de la semana.

signal chosen(ui: CardUI)

const TAMANO := Vector2(160, 240)          # en la mano del partido
const TAMANO_SEMANA := Vector2(176, 264)   # en el sobre del entrenamiento táctico
const TAMANO_MINI := Vector2(112, 168)     # en el mazo de la semana (sesión de video, Ver mazo)
const ANCHO_MINI := 130.0                  # más angosta que esto, la lámina no muestra palabras clave
const DISENO := 216.0                      # ancho de la lámina en el tablero de anatomía: medidas base

const TYPE_NAMES := {
    Card.Type.BASIC: "BÁSICA",
    Card.Type.TACTICAL: "TÁCTICA",
    Card.Type.ELITE: "ÉLITE",
    Card.Type.PENALTY: "PENALIZACIÓN",
}
# Lo que dice la banda de la lámina.
const KIND_NAMES := {
    Card.Kind.CONTROL: "CONTROL",
    Card.Kind.PASS: "PASE",
    Card.Kind.DRIBBLE: "REGATE",
    Card.Kind.CROSS: "CENTRO",
    Card.Kind.SHOT: "REMATE",
    Card.Kind.PAUSE: "PAUSA",
    Card.Kind.PRESS: "PRESIÓN",
    Card.Kind.BLOCK: "BLOQUEO",
    Card.Kind.INTERCEPT: "INTERCEPCIÓN",
    Card.Kind.CLEARANCE: "DESPEJE",
}
const ADVANCE_KINDS := [Card.Kind.CONTROL, Card.Kind.PASS, Card.Kind.DRIBBLE, Card.Kind.CROSS]

# Estilos de carta (tags con efecto en MatchEngine): palabra clave en la lámina y detalle en el tooltip.
const TAG_TEXT := {
    "potencia": "Potencia: el bloqueo rival cuenta la mitad en este remate.",
    "sangre_fria": "Sangre fría: +10 de acierto con la jugada a un fallo de perderse.",
    "fisica": "Física: gasta menos estamina con buen ritmo.",
}
const TAG_WORDS := {"potencia": "POTENCIA", "sangre_fria": "SANGRE FRÍA"}

static var _rasgos: Array = []   # ids de las cartas de rasgo del DT (decks.json "rasgos")

var card: Card
var hand_index := -1
var interactive := true
var slot_hidden := false
# Quién la juega en el partido: {"jugador": {name, role}, "colores": [camiseta, detalle], "propia": bool}.
var contexto := {}

var body: Control
var band_label: Label
var ap_label: Label
var seal_label: Label
var name_label: Label
var effect_label: Label    # palabras clave ("AVANZA · ROBA 1"); smoke_match revisa que nombre el efecto
var chance_label: Label    # placa de TV: el mismo % que usa la tirada
var cost_label: Label      # desgaste de estamina (junto a la gota)
var ribbon: Label          # cinta con el motivo por el que no se puede jugar
var glow: ColorRect

var _en_partido := false   # update_stats ya llegó: hay placa de TV
var _chance := 0.0
var _moneda := "normal"
var _gota := Paleta.ESTAMINA
var _anillo := Color(0, 0, 0, 0)   # anillo alrededor de la lámina (encima, resultado de la tirada)
var _anillo_ancho := 0.0
var _encima := false
var _tween: Tween
var _cost_tip := ""
var _k := 1.0
var _r_inner := Rect2()
var _r_band := Rect2()
var _r_window := Rect2()
var _r_footer := Rect2()
var _r_plate := Rect2()
var _r_gota := Rect2()
var _coin_c := Vector2.ZERO
var _coin_r := 0.0
var _estrella := Rect2()   # ★ de la banda (tamaño cero = sin estrella)


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    body = Control.new()
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    add_child(body)
    body.draw.connect(_draw_body)
    band_label = _texto("condensada_negra", Color.WHITE)
    band_label.clip_text = true
    band_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ap_label = _texto("condensada_negra", Color("#1a1408"))
    ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    seal_label = _texto("condensada_negra", Paleta.PAPEL_CREMA)
    seal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_label = _texto("condensada_negra", Paleta.TINTA)
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    effect_label = _texto("condensada", Paleta.TINTA_GRIS)
    effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    chance_label = _texto("tv", Color.WHITE)
    chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    chance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    Paleta.sombra_tv(chance_label)
    chance_label.visible = false
    cost_label = _texto("condensada_negra", Paleta.ESTAMINA_TEXTO)
    cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ribbon = _texto("plumon", Paleta.PLUMON)
    ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ribbon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ribbon.add_theme_stylebox_override("normal", Paleta.caja(Paleta.CINTA_MOTIVO, 0, [Color(0, 0, 0, 0.3), 3, 2]))
    ribbon.visible = false
    glow = ColorRect.new()
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.material = FlowGlow.make_material(Color("#ff7a18"))
    glow.visible = false
    body.add_child(glow)
    resized.connect(_layout)
    mouse_entered.connect(_on_enter)
    mouse_exited.connect(_on_exit)


# Las medidas de las etiquetas necesitan el tema, que llega al entrar al árbol: se rehace el armado.
# Fuera de un contenedor, la lámina toma el tamaño pedido (custom_minimum_size) al entrar.
func _ready() -> void:
    if custom_minimum_size != Vector2.ZERO and not (get_parent() is Container):
        size = custom_minimum_size
    _layout()


func _texto(nombre: String, color: Color) -> Label:
    var l := Paleta.etiqueta("", nombre, Paleta.TEXTO_MIN, color)
    body.add_child(l)
    return l


func setup(c: Card, index: int, ctx: Dictionary = {}) -> void:
    card = c
    hand_index = index
    contexto = ctx
    _en_partido = false
    var penalty := c.type == Card.Type.PENALTY
    ap_label.text = "" if penalty else "%d" % c.ap_cost
    ap_label.visible = not penalty
    seal_label.text = "%+d" % roundi(c.effective_bonus() * 100.0)
    seal_label.visible = not penalty
    name_label.text = c.display_name.to_upper()
    effect_label.text = keywords(c, ctx)
    chance_label.visible = false
    _moneda = "normal"
    if penalty:
        _set_cost("SIN EFECTO", Paleta.TINTA_GRIS, Paleta.TINTA_GRIS)
    elif c.kind == Card.Kind.PAUSE:
        _set_cost("+%d%%" % roundi(MatchEngine.PAUSE_STAMINA_PCT * 100.0), Paleta.CUESTA_MENOS, Paleta.CUESTA_MENOS)
    else:
        _set_cost("%d" % roundi(c.stamina_cost * MatchEngine.STAMINA_SCALE), Paleta.ESTAMINA_TEXTO, Paleta.ESTAMINA)
    set_ribbon("")
    tooltip_text = _tip_semana()
    _layout()


# Palabras clave de la lámina (D-37: nada de oraciones). En la semana, lo que hace la jugada y sus
# efectos ("AVANZA · ROBA 1"); en el partido, si la carta es de un jugador, su apellido y "PROPIA" cuando
# juega de titular (Ejecutor Natural). Los efectos siempre se nombran: smoke_match lo comprueba.
static func keywords(c: Card, ctx: Dictionary = {}) -> String:
    if c == null:
        return ""
    if c.type == Card.Type.PENALTY:
        return "OCUPA LA MANO"
    var parts: Array = []
    var jugador: Dictionary = ctx.get("jugador", {})
    if not jugador.is_empty():
        var nombre := String(jugador.get("name", ""))
        var apellido := nombre.get_slice(" ", nombre.get_slice_count(" ") - 1)
        if apellido != "" and not c.display_name.to_lower().contains(apellido.to_lower()):
            parts.append(apellido.to_upper())
        if ctx.get("propia", false):
            parts.append("PROPIA")
    var fx: Array = []
    for e in _effects(c):
        fx.append(e[0])
    if parts.is_empty():
        if c.kind in ADVANCE_KINDS and c.steps == 1:
            parts.append("AVANZA")
        elif fx.is_empty():
            parts.append("RECUPERA ESTAMINA" if c.kind == Card.Kind.PAUSE else "REMATA")
    parts.append_array(fx)
    for tag in c.tags:
        if TAG_WORDS.has(tag):
            parts.append(TAG_WORDS[tag])
    return " · ".join(parts)


# Efectos propios de la carta en palabras clave (pilar 2: lo que hace se ve en la carta); "" si no tiene.
# El detalle va en el tooltip (effect_tip).
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


# [palabras clave, detalle] por cada efecto: avances, robo, fuerza de la defensa, contragolpe y cortes.
static func _effects(c: Card) -> Array:
    var out: Array = []
    if c == null or c.type == Card.Type.PENALTY:
        return out
    if c.steps > 1:
        out.append(["AVANZA %d" % c.steps, "Si sale, cuenta como %d jugadas del Momento." % c.steps])
    if c.draw > 0:
        var cards := "carta" if c.draw == 1 else "cartas"
        out.append(["ROBA %d" % c.draw, "Si sale, robas %d %s de ataque para seguir la jugada." % [c.draw, cards]])
    if c.kind == Card.Kind.PRESS:
        var pts := roundi((c.effect if c.effect >= 0.0 else MatchEngine.PRESS_EFFECT) * 100.0)
        var normal := "" if c.effect < 0.0 else " (una Presión normal, %d)" % roundi(MatchEngine.PRESS_EFFECT * 100.0)
        out.append(["SU ATAQUE −%d" % pts, "Si sale, todas las jugadas de ese ataque rival pierden %d pts%s." % [pts, normal]])
    elif c.kind == Card.Kind.BLOCK:
        var pts := roundi((c.effect if c.effect >= 0.0 else MatchEngine.BLOCK_EFFECT) * 100.0)
        var normal := "" if c.effect < 0.0 else " (un Bloqueo normal, %d)" % roundi(MatchEngine.BLOCK_EFFECT * 100.0)
        out.append(["SUS REMATES −%d" % pts, "Si sale, los remates de ese ataque rival pierden %d pts%s." % [pts, normal]])
    var counter_tip := "tu próximo Momento arranca con una jugada hecha (contragolpe; no acorta los Momentos de 2 jugadas)."
    if c.kind == Card.Kind.INTERCEPT:
        out.append(["CORTA · CONTRAGOLPE", "Si sale, corta el ataque rival entero y " + counter_tip])
    elif c.kind == Card.Kind.CLEARANCE:
        out.append(["CORTA EL ATAQUE", "Si sale, corta el ataque rival entero."])
    elif c.counter:
        out.append(["CONTRAGOLPE", "Si sale, " + counter_tip])
    return out


# Por qué no se puede jugar la carta ahora, en pocas palabras para la cinta ("" si se puede).
static func unplayable_reason(engine: MatchEngine, c: Card) -> String:
    if engine == null or c == null or engine.can_play(c):
        return ""
    if c.type == Card.Type.PENALTY or not c.playable:
        return "NO SE JUEGA"
    if not DeckManager.fits_possession(c, engine.deck.possession):
        return "ES DE DEFENSA" if c.is_defensive() else "ES DE ATAQUE"
    if c.kind == Card.Kind.PAUSE and engine.pauses >= MatchEngine.MAX_PAUSES:
        return "YA HICISTE PAUSA"
    var zone_reason := engine.zone_block_reason(c)   # partido por zonas: remates solo en el Área
    if zone_reason != "":
        return zone_reason
    var missing := engine.ap_cost_of(c) - engine.ap
    if missing > 0:
        return "FALTA 1 PA" if missing == 1 else "FALTAN %d PA" % missing
    return "NO SE PUEDE"


static func is_trait(c: Card) -> bool:
    if _rasgos.is_empty():
        var lists := CardDB.load_deck_lists()
        _rasgos = lists.get("rasgos", {}).values() if not lists.is_empty() else [""]
    return _rasgos.has(c.id)


# ap = PA que cuesta ahora (con reusos en Flow, etc.), base_ap = PA impresos en la carta,
# stamina = desgaste de estamina que tendrá al jugarla.
# chance = MatchEngine.success_chance() y breakdown = MatchEngine.chance_breakdown(): el % de la placa
# es exactamente el que usa la tirada, y el desglose del tooltip explica de dónde sale.
# reason = CardUI.unplayable_reason(): la cinta dice por qué no se puede jugar ("" = sin cinta).
func update_stats(ap: int, base_ap: int, stamina: float, chance: float, usable: bool, glow_on: bool,
        breakdown: Array = [], reason: String = "") -> void:
    _en_partido = true
    tooltip_text = ""
    if card != null and card.type == Card.Type.PENALTY:
        ap_label.visible = false
        chance_label.visible = false
        chance_label.text = "—"
        _set_cost("SIN EFECTO", Paleta.TINTA_GRIS, Paleta.TINTA_GRIS)
        tooltip_text = "Penalización: ocupa un lugar en la mano y no se puede jugar."
    else:
        # Moneda de PA: dorada; naranja si hoy cuesta más de lo impreso, verde si menos.
        ap_label.visible = true
        ap_label.text = "%d" % ap
        _moneda = "mas" if ap > base_ap else ("menos" if ap < base_ap else "normal")
        _chance = chance
        chance_label.visible = true
        chance_label.text = "%d%%" % roundi(chance * 100.0)
        chance_label.add_theme_color_override("font_color", Paleta.placa(chance)[1])
        # Desgaste: azul; naranja si la postura, el desgaste tardío o una funa lo suben, verde si baja.
        var printed := card.stamina_cost * MatchEngine.STAMINA_SCALE
        if card.kind == Card.Kind.PAUSE:
            _set_cost("+%d%%" % roundi(MatchEngine.PAUSE_STAMINA_PCT * 100.0), Paleta.CUESTA_MENOS, Paleta.CUESTA_MENOS)
        else:
            var sc := Paleta.ESTAMINA_TEXTO
            var drop := Paleta.ESTAMINA
            if stamina > printed + 0.5:
                sc = Paleta.CUESTA_MAS
                drop = Paleta.CUESTA_MAS
            elif stamina < printed - 0.5:
                sc = Paleta.CUESTA_MENOS
                drop = Paleta.CUESTA_MENOS
            _set_cost("%d" % roundi(stamina), sc, drop)
        _cost_tip = "Cuesta %d PA del turno · desgasta %d de estamina" % [ap, roundi(stamina)]
        if card.kind == Card.Kind.PAUSE:
            _cost_tip = "Cuesta %d PA del turno · recupera %d%% de estamina" % [ap, roundi(MatchEngine.PAUSE_STAMINA_PCT * 100.0)]
        _show_breakdown(breakdown, chance)
        var tip := effect_tip(card)
        if tip != "":
            tooltip_text = tip if tooltip_text == "" else tooltip_text + "\n" + tip
    set_ribbon(reason if not usable else "")
    glow.visible = glow_on
    if slot_hidden:
        modulate.a = 0.0
    _layout()


# Desglose completo del % en el tooltip (de dónde sale el número de la placa).
func _show_breakdown(breakdown: Array, chance: float) -> void:
    var tip: Array = [_cost_tip] if _cost_tip != "" else []
    for item in breakdown:
        tip.append("%s: %+d" % [item["label"], roundi(float(item["value"]) * 100.0)])
    if not breakdown.is_empty():
        tip.append("= %d%% (tirada de 0 a 99: éxito si sale menos de %d)" % [roundi(chance * 100.0), roundi(chance * 100.0)])
    for tag in card.tags:
        if TAG_TEXT.has(tag):
            tip.append(TAG_TEXT[tag])
    tooltip_text = "\n".join(tip)


func _tip_semana() -> String:
    if card.type == Card.Type.PENALTY:
        return "Penalización: ocupa un lugar en la mano y no se puede jugar."
    var lines: Array = ["Carta %s · %s" % [TYPE_NAMES[card.type].to_lower(), KIND_NAMES.get(card.kind, "").to_lower()]]
    var wear := "recupera %d%% de estamina" % roundi(MatchEngine.PAUSE_STAMINA_PCT * 100.0) if card.kind == Card.Kind.PAUSE \
            else "desgasta %d de estamina" % roundi(card.stamina_cost * MatchEngine.STAMINA_SCALE)
    lines.append("Cuesta %d PA · %+d de acierto · %s" % [card.ap_cost, roundi(card.effective_bonus() * 100.0), wear])
    var tip := effect_tip(card)
    if tip != "":
        lines.append(tip)
    for tag in card.tags:
        if TAG_TEXT.has(tag):
            lines.append(TAG_TEXT[tag])
    if card.owner_id != "":
        lines.append("★ Carta de un jugador del plantel: Ejecutor Natural si es titular.")
    elif is_trait(card):
        lines.append("Rasgo: la carta del estilo de tu DT.")
    return "\n".join(lines)


func _set_cost(text: String, color: Color, drop: Color) -> void:
    cost_label.text = text
    cost_label.add_theme_color_override("font_color", color)
    _gota = drop


# Cinta con el motivo por el que no se puede jugar o elegir (la lámina no se apaga). "" la saca.
func set_ribbon(text: String) -> void:
    ribbon.text = text
    ribbon.visible = text != ""
    if is_inside_tree():
        _layout()


func set_interactive(v: bool) -> void:
    interactive = v


func hide_slot() -> void:
    slot_hidden = true
    modulate.a = 0.0


# Anillo del resultado de la tirada alrededor de la lámina lanzada.
func flash(color: Color) -> void:
    _anillo = color
    _anillo_ancho = maxf(3.0, 6.0 * _k)
    body.queue_redraw()


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
        _encima = true
        _lift(-size.y * 0.13, 1.07)
        body.queue_redraw()


func _on_exit() -> void:
    if interactive:
        _encima = false
        _lift(0.0, 1.0)
        body.queue_redraw()


func _lift(y: float, s: float) -> void:
    if _tween != null:
        _tween.kill()
    _tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween.tween_property(body, "position:y", y, 0.14)
    _tween.tween_property(body, "scale", Vector2(s, s), 0.14)


func _gui_input(event: InputEvent) -> void:
    if not interactive:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        chosen.emit(self)


# ================================================================== Medidas y dibujo

func _fs(l: Label, base: float) -> int:
    var tam := maxi(Paleta.TEXTO_MIN, roundi(base * _k))
    l.add_theme_font_size_override("font_size", tam)
    return tam


func _colores() -> Array:
    if card == null:
        return Paleta.JUGADA[Card.Kind.PASS]
    if card.type == Card.Type.PENALTY:
        return Paleta.PENALIZACION
    return Paleta.JUGADA.get(card.kind, Paleta.JUGADA[Card.Kind.PASS])


func _con_jugador() -> bool:
    return _en_partido and not contexto.get("jugador", {}).is_empty()


func _layout() -> void:
    var w := size.x
    var h := size.y
    if w <= 0.0 or h <= 0.0 or card == null:
        return
    _k = w / DISENO
    var k := _k
    var mini := w < ANCHO_MINI
    var marco := 8.0 * k
    _r_inner = Rect2(marco, marco, w - 2.0 * marco, h - 2.0 * marco)
    var band_h := maxf(36.0 * k, 20.0)
    _r_band = Rect2(_r_inner.position, Vector2(_r_inner.size.x, band_h))
    _coin_r = maxf(21.0 * k, 12.0)
    _coin_c = Vector2(_r_inner.end.x - 6.0 * k - _coin_r, _r_inner.position.y + 3.0 * k + _coin_r)
    var foot_h := maxf(40.0 * k, 24.0)
    _r_footer = Rect2(_r_inner.position.x, _r_inner.end.y - foot_h, _r_inner.size.x, foot_h)
    var pad := 12.0 * k

    # Banda: tipo de jugada; "RASGO" o la estrella si caben antes de la moneda.
    var band_size := _fs(band_label, 19.0)
    band_label.add_theme_font_override("font", Paleta.letra("condensada_negra", 2 if k >= 0.7 else 1))
    var band_x := _r_band.position.x + pad
    var star := 16.0 * k if card.owner_id != "" else 0.0
    var room := (_coin_c.x - _coin_r - 4.0 * k if ap_label.visible else _r_band.end.x - pad) - band_x - star
    var font := band_label.get_theme_font("font")
    var kind_name: String = "PENALIZACIÓN" if card.type == Card.Type.PENALTY else KIND_NAMES.get(card.kind, "")
    var band_text := kind_name
    if card.type != Card.Type.PENALTY and is_trait(card) and font.get_string_size(kind_name + " · RASGO", HORIZONTAL_ALIGNMENT_LEFT, -1, band_size).x <= room:
        band_text = kind_name + " · RASGO"
    band_label.text = band_text
    var band_w := minf(font.get_string_size(band_text, HORIZONTAL_ALIGNMENT_LEFT, -1, band_size).x + 2.0, room)
    band_label.position = Vector2(band_x, _r_band.position.y)
    band_label.size = Vector2(band_w, band_h)
    _estrella = Rect2()
    if star > 0.0:
        _estrella = Rect2(band_x + band_w + 4.0 * k, _r_band.get_center().y - star / 2.0, star, star)

    _fs(ap_label, 26.0)
    ap_label.position = _coin_c - Vector2(_coin_r, _coin_r)
    ap_label.size = Vector2(_coin_r, _coin_r) * 2.0

    # Nombre y palabras clave debajo de la ventana; la ventana cede alto si el nombre ocupa dos líneas.
    var text_w := _r_inner.size.x - 2.0 * pad
    var name_size := _fs(name_label, 28.0)
    name_label.add_theme_constant_override("line_spacing", -roundi(4.0 * k))
    name_label.size = Vector2(text_w, 0)
    while name_label.get_line_count() > 2 and name_size > Paleta.TEXTO_MIN:
        name_size -= 1
        name_label.add_theme_font_size_override("font_size", name_size)
    var name_h := name_label.get_minimum_size().y
    name_label.size = Vector2(text_w, name_h)
    effect_label.visible = not mini and effect_label.text != ""
    var kw_h := 0.0
    if effect_label.visible:
        _fs(effect_label, 18.0)
        effect_label.add_theme_font_override("font", Paleta.letra("condensada", 1))
        effect_label.add_theme_constant_override("line_spacing", -roundi(3.0 * k))
        effect_label.size = Vector2(text_w, 0)
        kw_h = effect_label.get_minimum_size().y
        effect_label.size = Vector2(text_w, kw_h)
    var text_h := name_h + (2.0 * k + kw_h if effect_label.visible else 0.0)
    var win_top := _r_band.end.y + 8.0 * k
    var win_h := clampf(_r_footer.position.y - 4.0 * k - text_h - 8.0 * k - win_top, 40.0 * k, 134.0 * k)
    _r_window = Rect2(_r_inner.position.x + 10.0 * k, win_top, _r_inner.size.x - 20.0 * k, win_h)
    name_label.position = Vector2(_r_inner.position.x + pad, _r_window.end.y + 6.0 * k)
    effect_label.position = Vector2(name_label.position.x, name_label.position.y + name_h + 2.0 * k)

    # Sello negro con el bono, arriba a la izquierda de la ventana (igual en la semana y en el partido).
    _fs(seal_label, 28.0)
    var seal_box := Paleta.caja(Paleta.TINTA)
    seal_box.content_margin_left = 8.0 * k
    seal_box.content_margin_right = 8.0 * k
    seal_label.add_theme_stylebox_override("normal", seal_box)
    seal_label.position = _r_window.position
    seal_label.size = seal_label.get_minimum_size()

    # Placa de TV con el % (solo en el partido), pegada al borde derecho, sobre el pie de la ventana.
    if chance_label.visible:
        var plate_size := _fs(chance_label, 42.0)
        var tw := chance_label.get_theme_font("font").get_string_size(chance_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, plate_size).x
        var ph := plate_size * 1.12
        _r_plate = Rect2(_r_inner.end.x + 6.0 * k - (tw + 30.0 * k), _r_window.end.y - ph + 4.0 * k, tw + 30.0 * k, ph)
        chance_label.position = _r_plate.position
        chance_label.size = _r_plate.size

    # Pie: gota y desgaste, centrados.
    _fs(cost_label, 24.0)
    var cw := cost_label.get_minimum_size().x
    var icon := maxf(20.0 * k, 14.0)
    var x0 := _r_footer.get_center().x - (icon + 5.0 * k + cw) / 2.0
    _r_gota = Rect2(x0, _r_footer.get_center().y - icon / 2.0, icon, icon)
    cost_label.position = Vector2(x0 + icon + 5.0 * k, _r_footer.position.y)
    cost_label.size = Vector2(cw, foot_h)

    # Cinta en diagonal sobre la ventana.
    if ribbon.visible:
        _fs(ribbon, 20.0)
        var rb := ribbon.get_theme_stylebox("normal") as StyleBoxFlat
        rb.content_margin_top = 2.0 * k
        rb.content_margin_bottom = 2.0 * k
        ribbon.size = Vector2(_r_window.size.x + 24.0 * k, 0)
        ribbon.size = Vector2(ribbon.size.x, ribbon.get_minimum_size().y)
        ribbon.pivot_offset = ribbon.size / 2.0
        ribbon.position = _r_window.get_center() - ribbon.size / 2.0
        ribbon.rotation = deg_to_rad(-12.0)

    body.size = size
    body.pivot_offset = size / 2.0
    glow.position = Vector2.ZERO
    glow.size = size
    body.queue_redraw()


func _draw_body() -> void:
    if card == null or _r_inner.size.x <= 0.0:
        return
    var b := body
    var k := _k
    var cols := _colores()
    var col: Color = cols[0]
    var fondo: Color = cols[1]
    var elite := card.type == Card.Type.ELITE
    var full := Rect2(Vector2.ZERO, size)

    # Lámina: marco exterior (blanco; dorado si es élite) con su sombra sobre la mesa.
    var outer := Paleta.caja(Paleta.MARCO_ELITE if elite else Color.WHITE, roundi(12.0 * k),
            [Paleta.SOMBRA_LAMINA[0], roundi(float(Paleta.SOMBRA_LAMINA[1]) * k), roundi(float(Paleta.SOMBRA_LAMINA[2]) * k)])
    b.draw_style_box(outer, full)
    var ring := _anillo
    var ring_w := _anillo_ancho
    if ring.a <= 0.0 and _encima and interactive:
        ring = Paleta.DORADO
        ring_w = maxf(2.0, 3.0 * k)
    if ring.a > 0.0:
        var rs := StyleBoxFlat.new()
        rs.draw_center = false
        rs.set_border_width_all(roundi(ring_w))
        rs.border_color = ring
        rs.set_corner_radius_all(roundi(12.0 * k + ring_w))
        rs.anti_aliasing = true
        b.draw_style_box(rs, full.grow(ring_w))
    # Papel crema y doble marco impreso del color de la jugada.
    b.draw_style_box(Paleta.caja(Paleta.PAPEL_CREMA, roundi(6.0 * k)), _r_inner)
    var frame := StyleBoxFlat.new()
    frame.draw_center = false
    frame.set_border_width_all(maxi(1, roundi(2.6 * k)))
    frame.border_color = col
    frame.set_corner_radius_all(roundi(3.0 * k))
    b.draw_style_box(frame, _r_inner.grow(-4.0 * k))
    var band := Paleta.caja(col)
    band.corner_radius_top_left = roundi(6.0 * k)
    band.corner_radius_top_right = roundi(6.0 * k)
    b.draw_style_box(band, _r_band)
    if _estrella.size.x > 0.0:
        Icono.dibujar(b, "estrella", _estrella, Color.WHITE)

    # Ventana: trama de puntos, dibujo de la jugada y, en el partido, la silueta del que la juega.
    b.draw_rect(_r_window, fondo)
    b.draw_texture_rect(Paleta.trama(), _r_window, true, Color(col, 0.30))
    if _con_jugador():
        var drawing := Rect2(_r_window.end.x - 6.0 * k - 88.0 * k, _r_window.position.y + 4.0 * k, 88.0 * k, 70.0 * k)
        Icono.jugada(b, card, drawing, col)
        var jug: Dictionary = contexto["jugador"]
        var shirt: Array = contexto.get("colores", [Color.WHITE, Color.BLACK])
        var sil_h := minf(94.0 * k, _r_window.size.y * 0.92)
        var sil := Rect2(_r_window.position.x + 6.0 * k, _r_window.end.y - sil_h + 12.0 * k, sil_h * 60.0 / 70.0, sil_h)
        Icono.jugador(b, sil, shirt[0], shirt[1], String(jug.get("role", "")), _r_window)
    else:
        var seal_h := seal_label.size.y if seal_label.visible else 0.0
        var avail := Vector2(_r_window.size.x - 20.0 * k, _r_window.size.y - seal_h * 0.6 - 14.0 * k)
        var dw := minf(130.0 * k, minf(avail.x, avail.y * 70.0 / 56.0))
        var dsize := Vector2(dw, dw * 56.0 / 70.0)
        var at := _r_window.end - Vector2(10.0 * k, 10.0 * k) - dsize
        Icono.jugada(b, card, Rect2(at, dsize), col)
    b.draw_rect(_r_window, col, false, maxf(1.0, k))

    # Placa de TV inclinada, en dos tonos como las gráficas de 2006.
    if chance_label.visible:
        var pc: Array = Paleta.placa(_chance)[0]
        var r := _r_plate
        var o := tan(deg_to_rad(12.0)) * r.size.y / 2.0
        var mid := r.position.y + r.size.y / 2.0
        var sh := Vector2(0, 2.0 * k)
        b.draw_colored_polygon(PackedVector2Array([r.position + Vector2(o, 0) + sh, Vector2(r.end.x + o, r.position.y) + sh,
                r.end - Vector2(o, 0) + sh, Vector2(r.position.x - o, r.end.y) + sh]), Color(0, 0, 0, 0.4))
        var top_l := Vector2(r.position.x + o, r.position.y)
        var top_r := Vector2(r.end.x + o, r.position.y)
        var mid_l := Vector2(r.position.x, mid)
        var mid_r := Vector2(r.end.x, mid)
        var bot_l := Vector2(r.position.x - o, r.end.y)
        var bot_r := Vector2(r.end.x - o, r.end.y)
        b.draw_polygon(PackedVector2Array([top_l, top_r, mid_r, mid_l]), PackedColorArray([pc[0], pc[0], pc[1], pc[1]]))
        b.draw_polygon(PackedVector2Array([mid_l, mid_r, bot_r, bot_l]), PackedColorArray([pc[2], pc[2], pc[3], pc[3]]))

    # Pie con la gota del desgaste.
    b.draw_line(_r_footer.position, Vector2(_r_footer.end.x, _r_footer.position.y), Paleta.BORDE_PIE, 1.0)
    if card.type != Card.Type.PENALTY:
        Icono.dibujar(b, "gota", _r_gota, _gota)

    # Moneda de PA, arriba a la derecha.
    if ap_label.visible:
        var coin: Array = Paleta.MONEDA[_moneda]
        b.draw_circle(_coin_c + Vector2(0, 2.0 * k), _coin_r, coin[3], true, -1.0, true)
        b.draw_texture_rect(Paleta.moneda(coin), Rect2(_coin_c - Vector2(_coin_r, _coin_r), Vector2(_coin_r, _coin_r) * 2.0), false)

    # Brillo de lámina élite.
    if elite:
        var x := _r_inner.position.x + _r_inner.size.x * 0.25
        var sw := _r_inner.size.x * 0.16
        var sheen := PackedVector2Array([Vector2(x, _r_inner.position.y), Vector2(x + sw, _r_inner.position.y),
                Vector2(x + sw - _r_inner.size.y * 0.45, _r_inner.end.y), Vector2(x - _r_inner.size.y * 0.45, _r_inner.end.y)])
        var clip := PackedVector2Array([_r_inner.position, Vector2(_r_inner.end.x, _r_inner.position.y), _r_inner.end,
                Vector2(_r_inner.position.x, _r_inner.end.y)])
        for poly in Geometry2D.intersect_polygons(sheen, clip):
            b.draw_colored_polygon(poly, Color(1, 1, 1, 0.16))
