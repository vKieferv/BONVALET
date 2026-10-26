# Compila todos los scripts y carga todas las escenas del proyecto.
# Uso: godot --headless --path futbolista -s res://tests/check_scripts.gd
# Sale con código 1 si algo no carga.
extends SceneTree


func _initialize() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	var failed: Array[String] = []
	files.erase(get_script().resource_path)   # recargar el script en ejecución hace caer a Godot
	for path in files:
		var res := ResourceLoader.load(path)
		var ok := res != null
		if ok and res is GDScript:
			ok = (res as GDScript).can_instantiate()
		if not ok:
			failed.append(path)
	print("check_scripts: %d archivos, %d con errores" % [files.size(), failed.size()])
	for path in failed:
		print("  FALLA: " + path)
	quit(1 if failed.size() > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if f.get_extension() in ["gd", "tscn"]:
			out.append(dir_path.path_join(f))
