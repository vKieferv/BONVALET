# T-16: captura de una escena cualquiera tal como abre (para revisar pantallas sueltas, como la tabla de
# posiciones de scenes/sim_dashboard.tscn). Necesita pantalla: NO se corre con --headless.
# Uso (desde futbolista/):
#   ..\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s res://tools/captura_escena.gd -- --escena=res://scenes/sim_dashboard.tscn --out=C:/ruta/nombre.png
# Opciones: --espera=N (cuadros antes de capturar, 60 por defecto), --bajar=N (píxeles de scroll del primer
# ScrollContainer, para ver lo que queda más abajo).
extends SceneTree

var escena := "res://scenes/sim_dashboard.tscn"
var out := "user://captura_escena.png"
var espera := 60
var bajar := 0
var cuadros := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--escena="):
			escena = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--espera="):
			espera = int(arg.get_slice("=", 1))
		elif arg.begins_with("--bajar="):
			bajar = int(arg.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Career.current = null
	change_scene_to_file(escena)


func _process(_delta: float) -> bool:
	cuadros += 1
	if cuadros == espera / 2 and bajar > 0 and current_scene != null:
		var barras := current_scene.find_children("*", "ScrollContainer", true, false)
		if not barras.is_empty():
			(barras[0] as ScrollContainer).scroll_vertical = bajar
	if cuadros < espera:
		return false
	root.get_texture().get_image().save_png(out)
	print("captura: ", out)
	quit(0)
	return true
