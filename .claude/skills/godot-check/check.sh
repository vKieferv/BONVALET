#!/usr/bin/env bash
# Verificación headless de Futbolista Deckbuilder para Linux (GitHub Actions, sesiones en la nube).
# Mismos pasos que check.ps1. Uso (desde la raíz del repo):
#   bash .claude/skills/godot-check/check.sh [--matches N] [--balance] [--skip-smoke]
# Godot se busca en $GODOT, en el PATH y en ~/.cache/godot; si no está, se descarga la versión
# oficial (GODOT_VERSION) a ~/.cache/godot.
set -u

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
MATCHES=5
BALANCE=0
SKIP_SMOKE=0
TIMEOUT_SEC="${TIMEOUT_SEC:-240}"
BALANCE_TIMEOUT_SEC="${BALANCE_TIMEOUT_SEC:-600}"   # sim.gd juega miles de partidos con el planificador de CoachBot

while [ $# -gt 0 ]; do
	case "$1" in
		--matches) MATCHES="$2"; shift ;;
		--balance) BALANCE=1 ;;
		--skip-smoke) SKIP_SMOKE=1 ;;
		*) echo "Opción desconocida: $1"; exit 2 ;;
	esac
	shift
done

PROJECT="$(cd "$(dirname "$0")/../../.." && pwd)"
LOG_DIR="${TMPDIR:-/tmp}/godot-check"
mkdir -p "$LOG_DIR"

find_godot() {
	if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then echo "$GODOT"; return; fi
	for name in godot godot4 "Godot_v${GODOT_VERSION}-stable_linux.x86_64"; do
		if command -v "$name" >/dev/null 2>&1; then command -v "$name"; return; fi
	done
	local cached="$HOME/.cache/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
	if [ ! -x "$cached" ]; then
		local url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
		echo "Descargando Godot ${GODOT_VERSION} desde $url" >&2
		mkdir -p "$HOME/.cache/godot"
		curl -fsSL "$url" -o "$HOME/.cache/godot/godot.zip" && \
			unzip -oq "$HOME/.cache/godot/godot.zip" -d "$HOME/.cache/godot" && \
			chmod +x "$cached" && rm -f "$HOME/.cache/godot/godot.zip"
	fi
	[ -x "$cached" ] && echo "$cached"
}

GODOT_BIN="$(find_godot)"
if [ -z "$GODOT_BIN" ]; then
	echo "FALTA Godot: define \$GODOT con la ruta al ejecutable o permite la descarga desde github.com"
	exit 2
fi

# Ejecuta Godot con tiempo límite. Devuelve el código de salida (124 = tiempo agotado, 3 = error de script).
run_godot() {
	local name="$1" limit="$2"; shift 2
	local out="$LOG_DIR/$name.out.txt" err="$LOG_DIR/$name.err.txt"
	timeout "$limit" "$GODOT_BIN" --headless --path "$PROJECT" "$@" >"$out" 2>"$err"
	local code=$?
	if [ $code -eq 124 ]; then
		echo "[$name] TIEMPO AGOTADO tras $limit s"
		return 124
	fi
	# Un error de script en ejecución no cambia el código de salida de Godot: se cuenta aparte.
	if [ "$name" != "import" ] && grep -q "SCRIPT ERROR" "$err"; then
		echo "[$name] Hubo errores de script en ejecución (ver $err)"
		grep -E "SCRIPT ERROR|at: " "$err" | head -n 10 | sed "s/^/[$name] /"
		return 3
	fi
	if [ "$name" != "import" ]; then   # la salida del import es solo progreso del editor
		grep -v -e '^Godot Engine v' -e '^$' "$out" | sed "s/^/[$name] /"
	fi
	grep -E "ERROR|WARNING|at: " "$err" | head -n 30 | sed "s/^/[$name] /"
	return $code
}

failed=()

# 1. Importar (regenera la caché de class_name; en una copia limpia es obligatorio)
run_godot import "$TIMEOUT_SEC" --import
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG_DIR/import.err.txt"; then failed+=(import); fi

# 2. Compilar todos los scripts y escenas
run_godot check_scripts "$TIMEOUT_SEC" -s res://tests/check_scripts.gd || failed+=(check_scripts)

# 3. Reglas del motor y de los datos
if [ ${#failed[@]} -eq 0 ]; then
	run_godot engine_rules "$TIMEOUT_SEC" -s res://tests/engine_rules.gd || failed+=(engine_rules)
	run_godot career_rules "$TIMEOUT_SEC" -s res://tests/career_rules.gd || failed+=(career_rules)
fi

# 4. Pruebas de humo de las escenas
if [ $SKIP_SMOKE -eq 0 ] && [ ${#failed[@]} -eq 0 ]; then
	run_godot smoke_match "$TIMEOUT_SEC" -s res://tests/smoke_match.gd -- "--matches=$MATCHES" || failed+=(smoke_match)
	run_godot smoke_career "$TIMEOUT_SEC" -s res://tests/smoke_career.gd || failed+=(smoke_career)
fi

# 5. Métricas de balance (opcional)
if [ $BALANCE -eq 1 ] && [ ${#failed[@]} -eq 0 ]; then
	run_godot balance "$BALANCE_TIMEOUT_SEC" -s res://core/sim.gd || failed+=(balance)
fi

echo ""
echo "Logs completos: $LOG_DIR"
if [ ${#failed[@]} -gt 0 ]; then
	echo "RESULTADO: FALLA (${failed[*]})"
	exit 1
fi
echo "RESULTADO: OK"
exit 0
