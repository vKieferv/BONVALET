# T-12: guarda 3 capturas de la prueba 3D (antes del pase, la pelota en el aire, Fernández recibiendo) e
# imprime los cuadros por segundo de 10 segundos de pase en loop. Necesita pantalla: NO se corre con --headless.
# Uso (desde futbolista/):
#   ..\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s res://tools/prueba_3d_captura.gd -- --out=C:/ruta/capturas
# Para Compatibility: agrega --rendering-method gl_compatibility antes de -s. Más opciones (después de --):
#   --sufijo=texto      se agrega al nombre de las capturas
#   --extras=13         jugadores de más (22 en total), para ver cómo cae el rendimiento
#   --sin-sombras       apaga las sombras del sol
#   --msaa=0            0, 2 o 4 (por defecto, el de la escena: 4x)
#   --solo-fotos        no mide
extends SceneTree

const ESCENA := "res://scenes/prueba_3d/prueba_3d.tscn"
const CALENTAR_S := 3.0
const MEDIR_S := 10.0

var out := "user://capturas_t12"
var sufijo := ""
var extras := 0
var sin_sombras := false
var msaa := -1
var solo_fotos := false
var view: Control
var paso := "boot"
var frames := 0
var _fotos := []
var _ini := 0
var _ult := 0
var _tiempos: Array[int] = []
var _gpu := 0.0
var _gpu_n := 0
var _vista_rid := RID()
var _prev := 0
var _peor_inicio := 0   # peor cuadro antes de empezar a medir: el tirón de compilar shaders al abrir


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--sufijo="):
			sufijo = "_" + arg.get_slice("=", 1)
		elif arg.begins_with("--extras="):
			extras = arg.get_slice("=", 1).to_int()
		elif arg == "--sin-sombras":
			sin_sombras = true
		elif arg.begins_with("--msaa="):
			msaa = arg.get_slice("=", 1).to_int()
		elif arg == "--solo-fotos":
			solo_fotos = true
	DirAccess.make_dir_recursive_absolute(out)
	# Sin tope: se mide lo que la máquina alcanza, no la frecuencia del monitor.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file(ESCENA)


func _shot(nombre: String) -> void:
	var ruta := out.path_join(nombre + sufijo + ".png")
	root.get_texture().get_image().save_png(ruta)
	print("captura: ", ruta)


func _process(_delta: float) -> bool:
	frames += 1
	if paso != "medir":
		var ahora := Time.get_ticks_usec()
		if _prev > 0:
			_peor_inicio = maxi(_peor_inicio, ahora - _prev)
		_prev = ahora
	if frames > 200000:
		print("prueba_3d_captura: tiempo agotado en el paso '%s'" % paso)
		quit(1)
		return true
	match paso:
		"boot":
			view = current_scene as Control
			if view != null and frames > 10:
				_preparar()
				paso = "fotos"
		"fotos":
			if view.t >= view.T_ANTES and not _fotos.has("antes"):
				_fotos.append("antes")
				_shot("1_antes_del_pase")
			elif view.t >= view.T_AIRE and not _fotos.has("aire"):
				_fotos.append("aire")
				_shot("2_pelota_en_el_aire")
			elif view.t >= view.T_RECIBE and not _fotos.has("recibe"):
				_fotos.append("recibe")
				_shot("3_fernandez_recibe")
				if solo_fotos:
					quit(0)
					return true
				paso = "calentar"
				_ini = Time.get_ticks_usec()
		"calentar":
			if Time.get_ticks_usec() - _ini > int(CALENTAR_S * 1000000.0):
				paso = "medir"
				_ini = Time.get_ticks_usec()
				_ult = _ini
		"medir":
			_medir()
			if Time.get_ticks_usec() - _ini > int(MEDIR_S * 1000000.0):
				_informe()
				quit(0)
				return true
	return false


func _preparar() -> void:
	var vista: SubViewport = view.get_node("Senal/Vista3D")
	if extras > 0:
		view.agregar_extras(extras)
	if sin_sombras:
		for n in vista.get_children():
			if n is DirectionalLight3D:
				n.shadow_enabled = false
	if msaa == 0:
		vista.msaa_3d = Viewport.MSAA_DISABLED
	elif msaa == 2:
		vista.msaa_3d = Viewport.MSAA_2X
	elif msaa == 4:
		vista.msaa_3d = Viewport.MSAA_4X
	_vista_rid = vista.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vista_rid, true)
	view.reiniciar()


func _medir() -> void:
	var ahora := Time.get_ticks_usec()
	_tiempos.append(ahora - _ult)
	_ult = ahora
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_vista_rid)
	if gpu > 0.0:
		_gpu += gpu
		_gpu_n += 1


func _informe() -> void:
	var total := 0
	for dt in _tiempos:
		total += dt
	var ordenados := _tiempos.duplicate()
	ordenados.sort()
	var n := ordenados.size()
	var vista: SubViewport = view.get_node("Senal/Vista3D")
	print("---- T-12 rendimiento ----")
	print("renderizador: ", RenderingServer.get_current_rendering_method(), " / ", RenderingServer.get_current_rendering_driver_name())
	print("equipo: ", RenderingServer.get_video_adapter_name(), " | ", OS.get_processor_name(), " | ", OS.get_processor_count(), " hilos")
	print("ventana: ", root.size, " | 3D: ", vista.size, " | MSAA: ", ["no", "2x", "4x", "8x"][vista.msaa_3d], " | jugadores: ", 9 + extras, " | sombras: ", not sin_sombras)
	print("cuadros por segundo (promedio de %d s): %.1f" % [roundi(total / 1000000.0), n * 1000000.0 / total])
	print("cuadro mediano: %.2f ms | peor 1%%: %.2f ms" % [ordenados[n / 2] / 1000.0, ordenados[mini(n - 1, n * 99 / 100)] / 1000.0])
	print("peor cuadro al abrir la escena: %.1f ms" % (_peor_inicio / 1000.0))
	if _gpu_n > 0:
		print("GPU de la cancha 3D: %.2f ms por cuadro" % (_gpu / _gpu_n))
	print("llamadas de dibujo por cuadro: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" | triángulos: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("triángulos por jugador: ", view.Jugador.triangulos_por_jugador("corto"))
