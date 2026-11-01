extends RefCounted

# T-12: mallas de pocos polígonos hechas en código. Cada cara lleva sus propios vértices, así las
# normales quedan planas y se ven las facetas. Se juntan triángulos y a_malla() los pasa a un ArrayMesh
# (una superficie por llamada, para poder ponerle un material a cada parte).

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()


# Godot toma como frente el lado desde el que los vértices giran en sentido horario.
func tri(a: Vector3, b: Vector3, c: Vector3, color: Color = Color.WHITE) -> void:
    var n := (c - a).cross(b - a).normalized()
    for p: Vector3 in [a, b, c]:
        _v.append(p)
        _n.append(n)
        _c.append(color)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color = Color.WHITE) -> void:
    tri(a, b, c, color)
    tri(a, c, d, color)


# Rectángulo sobre el suelo (visto desde arriba), a la altura y.
func suelo(x0: float, z0: float, x1: float, z1: float, y: float, color: Color) -> void:
    quad(Vector3(x0, y, z1), Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), color)


# Prisma de `lados` caras entre dos secciones elípticas (radios x, z), con centros c0 y c1 en el plano xz.
func prisma(y0: float, r0: Vector2, y1: float, r1: Vector2, lados: int = 6, color: Color = Color.WHITE,
        c0: Vector2 = Vector2.ZERO, c1: Vector2 = Vector2.ZERO, giro: float = 0.0) -> void:
    var abajo := PackedVector3Array()
    var arriba := PackedVector3Array()
    for i in lados:
        var a := giro + TAU * i / lados
        abajo.append(Vector3(c0.x + r0.x * cos(a), y0, c0.y + r0.y * sin(a)))
        arriba.append(Vector3(c1.x + r1.x * cos(a), y1, c1.y + r1.y * sin(a)))
    var centro_abajo := Vector3(c0.x, y0, c0.y)
    var centro_arriba := Vector3(c1.x, y1, c1.y)
    for i in lados:
        var j := (i + 1) % lados
        quad(abajo[j], arriba[j], arriba[i], abajo[i], color)
        tri(centro_arriba, arriba[i], arriba[j], color)
        tri(centro_abajo, abajo[j], abajo[i], color)


# Caja alineada a los ejes, entre dos esquinas.
func caja(minimo: Vector3, maximo: Vector3, color: Color = Color.WHITE) -> void:
    var a := Vector2(maximo.x - minimo.x, maximo.z - minimo.z) * 0.5 * sqrt(2.0)
    var centro := Vector2(minimo.x + maximo.x, minimo.z + maximo.z) * 0.5
    prisma(minimo.y, a, maximo.y, a, 4, color, centro, centro, PI / 4.0)


# Anillo plano sobre el suelo.
func anillo(radio_int: float, radio_ext: float, lados: int, y: float, color: Color,
        centro: Vector2 = Vector2.ZERO) -> void:
    for i in lados:
        var a := TAU * i / lados
        var b := TAU * (i + 1) / lados
        var pa := Vector2(cos(a), sin(a))
        var pb := Vector2(cos(b), sin(b))
        var ia := centro + pa * radio_int
        var ib := centro + pb * radio_int
        var ea := centro + pa * radio_ext
        var eb := centro + pb * radio_ext
        quad(Vector3(ib.x, y, ib.y), Vector3(eb.x, y, eb.y), Vector3(ea.x, y, ea.y), Vector3(ia.x, y, ia.y), color)


# Pelota: icosaedro truncado (12 pentágonos negros y 20 hexágonos blancos), como una de verdad.
func pelota(radio: float) -> void:
    var t := (1.0 + sqrt(5.0)) * 0.5
    var v: Array[Vector3] = []
    for p: Vector3 in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
            Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
            Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
        v.append(p.normalized() * radio)
    var caras := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
            [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
    for cara: Array in caras:
        var a: Vector3 = v[cara[0]]
        var b: Vector3 = v[cara[1]]
        var c: Vector3 = v[cara[2]]
        var hexagono: Array[Vector3] = [a.lerp(b, 1.0 / 3.0), a.lerp(b, 2.0 / 3.0), b.lerp(c, 1.0 / 3.0),
                b.lerp(c, 2.0 / 3.0), c.lerp(a, 1.0 / 3.0), c.lerp(a, 2.0 / 3.0)]
        for i in hexagono.size():
            hexagono[i] = hexagono[i].normalized() * radio
        for i in range(1, 5):
            _tri_afuera(hexagono[0], hexagono[i], hexagono[i + 1], Color("#f7f7f7"))
        _tri_afuera(a, hexagono[0], hexagono[5], Color("#16181c"))
        _tri_afuera(b, hexagono[2], hexagono[1], Color("#16181c"))
        _tri_afuera(c, hexagono[4], hexagono[3], Color("#16181c"))


func _tri_afuera(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
    if (c - a).cross(b - a).dot(a + b + c) < 0.0:
        tri(a, c, b, color)
    else:
        tri(a, b, c, color)


func a_malla(malla: ArrayMesh = null) -> ArrayMesh:
    var m := malla if malla != null else ArrayMesh.new()
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = _v
    arrays[Mesh.ARRAY_NORMAL] = _n
    arrays[Mesh.ARRAY_COLOR] = _c
    m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return m


# Material opaco con luz y facetas, de un color. Se comparte por color: menos llamadas de dibujo.
static var _materiales := {}


static func material(color: Color) -> StandardMaterial3D:
    var key := color.to_html()
    if not _materiales.has(key):
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mat.roughness = 1.0
        mat.metallic_specular = 0.15
        _materiales[key] = mat
    return _materiales[key]


# Material que toma el color de cada vértice (pasto, pelota).
static func material_vertices(con_luz: bool = true, transparente: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.vertex_color_is_srgb = true
    mat.roughness = 1.0
    mat.metallic_specular = 0.1
    if not con_luz:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if transparente:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return mat
