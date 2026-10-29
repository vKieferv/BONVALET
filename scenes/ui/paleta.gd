class_name Paleta
extends RefCounted

# Colores, letras y materiales de la cara visual (D-35, D-37): la mesa del DT (papeles, timbres de
# tinta, plumón, cinta Dymo) y la señal de TV (placas del %, marcador). Las escenas toman de aquí lo
# que pintan en vez de repetir constantes. Las texturas (grano del papel, trama de puntos, moneda) se
# generan en Godot: no hay imágenes bajadas de internet. El tema del proyecto es scenes/ui/tema.tres.

const TEXTO_MIN := 14   # ningún texto de juego bajo 14 px a 1280×720 (D-37: se lee en una Steam Deck)
const FONT_DIR := "res://assets/fonts/"
const LETRAS := {
    "texto": "Barlow-Medium.ttf",
    "texto_regular": "Barlow-Regular.ttf",
    "texto_semi": "Barlow-SemiBold.ttf",
    "texto_negrita": "Barlow-Bold.ttf",
    "condensada_semi": "BarlowCondensed-SemiBold.ttf",
    "condensada": "BarlowCondensed-Bold.ttf",
    "condensada_negra": "BarlowCondensed-ExtraBold.ttf",
    "tv": "BarlowCondensed-ExtraBoldItalic.ttf",       # gráficas de TV: cursiva con sombra dura
    "plumon": "PermanentMarker-Regular.ttf",           # solo lo escrito a mano por el DT
    "diario": "PlayfairDisplay-Variable.ttf",          # solo Diario El Chisme (peso 900)
}
const WGHT := 2003265652   # etiqueta OpenType 'wght' (eje de peso de la Playfair variable)

# ------------------------------------------------------------------ Mesa del DT
const MADERA := Color("#2a1b11")
const MADERA_VETA := Color(0.30, 0.18, 0.09)
const PAPEL_CREMA := Color("#f6f0e1")         # fondo de la lámina
const PAPEL_BLANCO := Color("#fbfaf6")        # contratos, ficha médica
const PAPEL_LIBRETA := Color("#fbf8ee")
const PAPEL_CALENDARIO := Color("#f6f1e4")
const PAPEL_DIARIO := Color("#efe7d2")
const FOTO_DIARIO := Color("#b8ad97")         # foto del diario, impresa en trama
const FOTO_TINTA := Color("#3a332a")
const LINEA_LIBRETA := Color("#a9c4e0")
const MARGEN_LIBRETA := Color("#e48a8a")
const ANILLO_LIBRETA := Color("#8a8f96")
const TINTA := Color("#15181f")               # imprenta: sello del bono, nombre de la lámina
const TINTA_MESA := Color("#1f1b16")          # texto impreso de los papeles
const TINTA_SEPIA := Color("#5a5146")
const TINTA_GRIS := Color("#4a4f5a")          # palabras clave de la lámina
const PUNTEADO := Color("#9a9080")
const PLUMON := Color("#1b2a6b")              # plumón azul sobre papel
const PLUMON_CREMA := Color("#fff3d6")        # plumón claro sobre la madera
const PLUMON_ALERTA := Color("#ffb3a8")       # "falta el paso N"
const PLUMON_ROJO := Color("#b3261e")
const TIMBRE_VERDE := Color("#1c6b3e")        # lo que suma
const TIMBRE_ROJO := Color("#b3261e")         # lo que resta o el riesgo
const TIMBRE_NARANJA := Color("#c25a12")      # fatiga que sube
const TIMBRE_DORADO := Color("#d9a400")
const TIMBRE_CLARO := Color("#d6dde8")        # timbre sobre el cassette negro
const ROJO_DIARIO := Color("#c8321f")
const DYMO := Color("#141414")
const DYMO_LETRA := Color("#f4f4f4")
const POSTIT_AMARILLO := [Color("#ffe97a"), Color("#f2d35a")]
const POSTIT_VERDE := [Color("#cdf09a"), Color("#b2d978")]
const CHINCHETA := [Color("#ff8a7a"), Color("#c8321f"), Color("#7d1a10")]
const CHINCHETA_HECHO := [Color("#7ee0a1"), Color("#1c6b3e"), Color("#0f3d23")]
const CINTA_ADHESIVA := Color(0.91, 0.855, 0.69, 0.78)
const CINTA_MOTIVO := Color(0.93, 0.87, 0.71, 0.95)   # cinta de una lámina que no se puede jugar
const SEPARADORES := {                                 # pestañas del archivador: [papel, letra]
    "prensa": [Color("#f3e6c4"), Color("#1f1b16")],
    "entrenamiento": [Color("#a9c98f"), Color("#1d2a14")],
    "partido": [Color("#7f9fbf"), Color("#1b2738")],
}
const LUZ_LAMPARA := Color(1.0, 0.84, 0.59, 0.30)

# Sombras de material: [color, tamaño (difuminado), desplazamiento hacia abajo]
const SOMBRA_PAPEL := [Color(0, 0, 0, 0.55), 16, 10]
const SOMBRA_LAMINA := [Color(0, 0, 0, 0.6), 14, 9]
const SOMBRA_POSTIT := [Color(0, 0, 0, 0.5), 10, 14]
const SOMBRA_OBJETO := [Color(0, 0, 0, 0.7), 20, 14]

# ------------------------------------------------------------------ Lámina
const DORADO := Color("#f2b63d")
const MARCO_ELITE := Color("#f1cf72")          # marco exterior de las láminas élite (brillantes)
const BORDE_PIE := Color("#d6ccb4")
const ESTAMINA := Color("#2b8fd0")             # gota
const ESTAMINA_TEXTO := Color("#1d4f9e")
const ROBO := Color("#a3271b")
const CUESTA_MAS := Color("#c25a12")           # cuesta más de lo impreso (Flow, postura, funa)
const CUESTA_MENOS := Color("#1c6b3e")         # cuesta menos de lo impreso
# Banda y fondo de la ventana por jugada (pase azul, control verde, centro violeta, remate naranja).
const JUGADA := {
    Card.Kind.CONTROL: [Color("#1f8a5c"), Color("#dcefe3")],
    Card.Kind.PASS: [Color("#2f6fd6"), Color("#dfe8f8")],
    Card.Kind.DRIBBLE: [Color("#0f8b8d"), Color("#d8eeee")],
    Card.Kind.CROSS: [Color("#7a4fc2"), Color("#e9e0f6")],
    Card.Kind.SHOT: [Color("#d0562a"), Color("#f7e1d6")],
    Card.Kind.PAUSE: [Color("#6b7280"), Color("#e6e7ea")],
    Card.Kind.PRESS: [Color("#a23a55"), Color("#f2dde3")],
    Card.Kind.BLOCK: [Color("#4f5d70"), Color("#e1e5ea")],
    Card.Kind.INTERCEPT: [Color("#8a5a2b"), Color("#f0e4d6")],
    Card.Kind.CLEARANCE: [Color("#3a3f47"), Color("#e2e3e5")],
}
const PENALIZACION := [Color("#8a1f14"), Color("#eadcd8")]
# Moneda de PA: [brillo, cuerpo, borde, sombra]; naranja si cuesta más de lo impreso, verde si menos.
const MONEDA := {
    "normal": [Color("#ffe08a"), Color("#f2b63d"), Color("#b9801a"), Color("#7a5410")],
    "mas": [Color("#ffc58f"), Color("#ec8a3a"), Color("#a5501a"), Color("#6b3210")],
    "menos": [Color("#a8ecc0"), Color("#3fae6a"), Color("#1d6e40"), Color("#0f3d23")],
}

# ------------------------------------------------------------------ Señal de TV
# Placa del %: [arriba, medio, corte, abajo] (dos tonos de 2006) y color del número.
const PLACA_VERDE := [Color("#5fd08f"), Color("#2e9b5a"), Color("#23824a"), Color("#2b9355")]
const PLACA_DORADA := [Color("#ffe08a"), Color("#f2b63d"), Color("#d99a22"), Color("#ecae35")]
const PLACA_CORAL := [Color("#ff9d90"), Color("#d9483b"), Color("#b93a2f"), Color("#cf4337")]
const TV_FONDO := Color("#0b111b")
const TV_AZUL := [Color("#3c62b8"), Color("#23438f"), Color("#172f6b"), Color("#22428c")]


# Placa de TV según el % que se tira (D-37): verde 60% o más, dorada 40-59%, coral menos de 40%.
static func placa(chance: float) -> Array:
    var pct := roundi(chance * 100.0)
    if pct >= 60:
        return [PLACA_VERDE, Color.WHITE]
    if pct >= 40:
        return [PLACA_DORADA, Color("#1a1408")]
    return [PLACA_CORAL, Color.WHITE]


# ------------------------------------------------------------------ Letras

static var _letras := {}


# Letra por nombre (LETRAS) con espaciado opcional entre letras, en píxeles. Se cachea.
static func letra(nombre: String, espaciado: int = 0) -> Font:
    var key := "%s/%d" % [nombre, espaciado]
    if _letras.has(key):
        return _letras[key]
    var base: Font = load(FONT_DIR + String(LETRAS[nombre]))
    var f: Font = base
    if nombre == "diario" or espaciado != 0:
        var v := FontVariation.new()
        v.base_font = base
        if nombre == "diario":
            v.variation_opentype = {WGHT: 900}
        v.spacing_glyph = espaciado
        f = v
    _letras[key] = f
    return f


# Etiqueta con letra, tamaño (nunca bajo TEXTO_MIN) y color; no captura el mouse.
static func etiqueta(texto: String, nombre: String, tam: int, color: Color, espaciado: int = 0) -> Label:
    var l := Label.new()
    l.text = texto
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    estilo_texto(l, nombre, tam, color, espaciado)
    return l


static func estilo_texto(c: Control, nombre: String, tam: int, color: Color, espaciado: int = 0) -> void:
    c.add_theme_font_override("font", letra(nombre, espaciado))
    c.add_theme_font_size_override("font_size", maxi(TEXTO_MIN, tam))
    c.add_theme_color_override("font_color", color)


# Texto con sombra dura, como las gráficas de TV de 2006.
static func sombra_tv(l: Label, distancia: int = 2) -> void:
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
    l.add_theme_constant_override("shadow_offset_x", 0)
    l.add_theme_constant_override("shadow_offset_y", distancia)


# ------------------------------------------------------------------ Cajas

static func caja(color: Color, radio: int = 0, sombra: Array = []) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    sb.set_corner_radius_all(radio)
    sb.anti_aliasing = true
    if not sombra.is_empty():
        sb.shadow_color = sombra[0]
        sb.shadow_size = int(sombra[1])
        sb.shadow_offset = Vector2(0, float(sombra[2]))
    return sb


# ------------------------------------------------------------------ Texturas generadas

static var _trama: Texture2D
static var _grano: Texture2D
static var _monedas := {}


# Trama de puntos (ventana de la lámina, foto del diario): un punto blanco por casilla, para teñir
# con modulate y repetir (texture_repeat).
static func trama() -> Texture2D:
    if _trama == null:
        var n := 5
        var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
        var c := Vector2(n, n) / 2.0
        for y in n:
            for x in n:
                var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(c)
                img.set_pixel(x, y, Color(1, 1, 1, clampf(1.6 - d, 0.0, 1.0)))
        _trama = ImageTexture.create_from_image(img)
    return _trama


# Grano del papel: motas oscuras casi transparentes, para repetir sobre papeles y madera.
static func grano() -> Texture2D:
    if _grano == null:
        var noise := FastNoiseLite.new()
        noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
        noise.frequency = 0.45
        noise.seed = 3
        var n := 96
        var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
        for y in n:
            for x in n:
                var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
                img.set_pixel(x, y, Color(0.1, 0.07, 0.04, clampf((v - 0.35) * 0.22, 0.0, 0.14)))
        _grano = ImageTexture.create_from_image(img)
    return _grano


# Moneda de PA (o chincheta): círculo con degradé radial y brillo arriba a la izquierda.
static func moneda(colores: Array) -> Texture2D:
    var key := str(colores)
    if _monedas.has(key):
        return _monedas[key]
    var n := 64
    var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
    var c := Vector2(n, n) / 2.0
    var luz := Vector2(n * 0.35, n * 0.30)
    var r := n / 2.0 - 0.5
    for y in n:
        for x in n:
            var p := Vector2(x, y) + Vector2(0.5, 0.5)
            var alpha := clampf(r - p.distance_to(c) + 0.5, 0.0, 1.0)
            var t := clampf(p.distance_to(luz) / (n * 0.78), 0.0, 1.0)
            var col: Color = colores[0].lerp(colores[1], t / 0.45) if t < 0.45 else colores[1].lerp(colores[2], (t - 0.45) / 0.55)
            col.a = alpha
            img.set_pixel(x, y, col)
    var tex := ImageTexture.create_from_image(img)
    _monedas[key] = tex
    return tex


# Grano repetido sobre un rectángulo de un CanvasItem (el CanvasItem necesita texture_repeat).
static func dibujar_grano(ci: CanvasItem, rect: Rect2, fuerza: float = 1.0) -> void:
    ci.draw_texture_rect(grano(), rect, true, Color(1, 1, 1, fuerza))


# Textos visibles bajo TEXTO_MIN dentro de `root` (etiquetas y botones con texto). Lo revisan
# smoke_career y smoke_match en cada pantalla que recorren; [] = todo se lee.
static func textos_chicos(root: Node) -> Array:
    var out: Array = []
    for n in root.find_children("*", "Control", true, false):
        var c := n as Control
        if not (c is Label or c is Button) or not c.is_visible_in_tree() or String(c.get("text")) == "":
            continue
        var tam := c.get_theme_font_size("font_size")
        if tam < TEXTO_MIN:
            out.append("'%s' (%d px)" % [String(c.get("text")).left(30), tam])
    return out
