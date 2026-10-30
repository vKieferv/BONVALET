extends Node3D

# T-12: la cancha de la prueba, a escala de TV (no a escala real: la zona mide 17 m para que los
# jugadores se vean como en la maqueta v5). Pasto con franjas, líneas, telestrador amarillo de la zona
# con su nombre pintado, carteles parodia y una tribuna con público generado por código.

const Malla := preload("res://scenes/prueba_3d/malla_low_poly.gd")

const SALIDA_X := -6.0          # línea entre la Salida y el Medio
const AREA_X := 11.0            # línea entre el Medio y el Área
const CENTRO_X := 2.5
const FONDO_Z := -9.6           # línea de banda del fondo
const FRENTE_Z := 14.0          # el pasto sigue hasta más allá del borde de la pantalla
const X_MIN := -40.0
const X_MAX := 52.0
const FRANJA := 3.2

const CESPED_A := Color("#2d6a3a")
const CESPED_B := Color("#3f8a4b")
const LINEA := Color(1, 1, 1, 0.78)
const TELESTRADOR := Color("#ffe14d")
const CARTELES := [
    ["CERVEZA GLACIAR", Color("#e9f3fb"), Color("#1d5f8a")],
    ["TELNET", Color("#1b3f8f"), Color.WHITE],
    ["DIARIO EL CHISME", Color("#c8321f"), Color.WHITE],
]
const CARTEL_ANCHO := 6.0
const CARTEL_ALTO := 1.15
const CARTEL_Z := -10.7


func _ready() -> void:
    _armar_pasto()
    _armar_marcas()
    _armar_nombres()
    _armar_carteles()
    _armar_tribuna()


func _armar_pasto() -> void:
    var m := Malla.new()
    var x := X_MIN
    var i := 0
    while x < X_MAX:
        m.suelo(x, -12.0, x + FRANJA, FRENTE_Z, 0.0, CESPED_A if i % 2 == 0 else CESPED_B)
        x += FRANJA
        i += 1
    var mi := MeshInstance3D.new()
    mi.mesh = m.a_malla()
    mi.set_surface_override_material(0, Malla.material_vertices())
    add_child(mi)


# Todo lo pintado en el suelo va en una sola malla transparente: una llamada de dibujo. El orden importa:
# primero las zonas, encima las líneas y el telestrador.
func _armar_marcas() -> void:
    var m := Malla.new()
    m.suelo(X_MIN, FONDO_Z, SALIDA_X, FRENTE_Z, 0.012, Color(1, 1, 1, 0.05))
    m.suelo(SALIDA_X, FONDO_Z, AREA_X, FRENTE_Z, 0.012, Color(1.0, 0.88, 0.3, 0.13))
    m.suelo(AREA_X, FONDO_Z, X_MAX, FRENTE_Z, 0.012, Color(0, 0, 0, 0.2))
    m.suelo(X_MIN, FONDO_Z - 0.06, X_MAX, FONDO_Z + 0.06, 0.02, LINEA)
    m.suelo(CENTRO_X - 0.055, FONDO_Z, CENTRO_X + 0.055, FRENTE_Z, 0.02, LINEA)
    m.anillo(3.95, 4.05, 48, 0.02, LINEA, Vector2(CENTRO_X, -0.2))
    m.anillo(0.0, 0.14, 12, 0.02, LINEA, Vector2(CENTRO_X, -0.2))
    for x: float in [SALIDA_X, AREA_X]:
        m.suelo(x - 0.26, FONDO_Z, x + 0.26, FRENTE_Z, 0.024, Color(TELESTRADOR, 0.26))
        var z := FONDO_Z
        while z < FRENTE_Z:
            m.suelo(x - 0.095, z, x + 0.095, minf(z + 0.85, FRENTE_Z), 0.028, TELESTRADOR)
            z += 1.35
    var mi := MeshInstance3D.new()
    mi.mesh = m.a_malla()
    mi.set_surface_override_material(0, Malla.material_vertices(false, true))
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


func _armar_nombres() -> void:
    for dato: Array in [["SALIDA", -14.0, 0.85], ["MEDIO", -2.5, 0.85], ["ÁREA", 19.0, 0.5]]:
        var l := Label3D.new()
        l.text = dato[0]
        l.font = Paleta.letra("plumon")
        l.font_size = 128
        l.outline_size = 0
        l.pixel_size = 0.015
        l.modulate = Color(TELESTRADOR, dato[2])
        l.shaded = false
        l.rotation.x = -PI / 2.0
        l.scale = Vector3(1.0, 2.0, 1.0)   # estirado a lo largo, como las letras pintadas en el pasto
        l.position = Vector3(dato[1], 0.035, -7.4)
        l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(l)


func _armar_carteles() -> void:
    var m := Malla.new()
    var i := 0
    var x := X_MIN
    while x < X_MAX:
        var c: Array = CARTELES[i % CARTELES.size()]
        var fondo: Color = c[1]
        m.caja(Vector3(x + 0.04, 0.0, CARTEL_Z), Vector3(x + CARTEL_ANCHO - 0.04, CARTEL_ALTO, CARTEL_Z + 0.2), fondo)
        var l := Label3D.new()
        l.text = c[0]
        l.font = Paleta.letra("condensada_negra", 2)
        l.font_size = 64
        l.outline_size = 0
        l.pixel_size = 0.0115
        l.modulate = c[2]
        l.shaded = false
        l.position = Vector3(x + CARTEL_ANCHO * 0.5, CARTEL_ALTO * 0.5, CARTEL_Z + 0.215)
        l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(l)
        x += CARTEL_ANCHO
        i += 1
    var mi := MeshInstance3D.new()
    mi.mesh = m.a_malla()
    mi.set_surface_override_material(0, Malla.material_vertices())
    add_child(mi)


# Tribuna: un plano inclinado con una textura de público hecha en código.
func _armar_tribuna() -> void:
    var abajo := 1.0
    var arriba := 13.0
    var z0 := CARTEL_Z - 0.3
    var z1 := CARTEL_Z - 22.0
    # El plano va de atrás hacia adelante; las coordenadas de textura se calculan en el material.
    var ancho := (X_MAX - X_MIN) * 1.3
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var a := Vector3(X_MIN * 1.3, abajo, z0)
    var b := Vector3(X_MIN * 1.3, arriba, z1)
    var c := Vector3(X_MAX * 1.3, arriba, z1)
    var d := Vector3(X_MAX * 1.3, abajo, z0)
    var repeticion := Vector2(ancho / 26.0, 1.0)
    for vertice: Array in [[a, Vector2(0, 1)], [b, Vector2(0, 0)], [c, Vector2(1, 0)], [a, Vector2(0, 1)], [c, Vector2(1, 0)], [d, Vector2(1, 1)]]:
        st.set_uv(Vector2(vertice[1]) * repeticion)
        st.add_vertex(vertice[0])
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_texture = _textura_publico()
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mi.set_surface_override_material(0, mat)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


# Público: una mota de color por persona sobre filas oscuras, con semilla fija.
func _textura_publico() -> ImageTexture:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2006
    var ancho := 256
    var alto := 96
    var img := Image.create(ancho, alto, false, Image.FORMAT_RGB8)
    img.fill(Color("#121c15"))
    var colores := [Color("#e8e8e8"), Color("#2b3f8f"), Color("#b3261e"), Color("#3a3a40"), Color("#caa98a"), Color("#5a6470"), Color("#20293a")]
    for y in range(0, alto, 3):
        for x in range(0, ancho, 3):
            if rng.randf() < 0.82:
                var col: Color = colores[rng.randi_range(0, colores.size() - 1)]
                col = col.darkened(0.25 + 0.3 * rng.randf())
                img.fill_rect(Rect2i(x, y, 2, 2), col)
    return ImageTexture.create_from_image(img)
