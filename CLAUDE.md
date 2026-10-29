# CLAUDE.md

Futbolista Deckbuilder 2006: deckbuilder de fútbol chileno en Godot 4.7.2 / GDScript. Todo en español.
Detalle técnico (reglas del motor, carrera, guardado, mazos, línea base de balance): `docs/arquitectura.md`,
**por secciones** (busca el título con grep). Diseño: `docs/pilares.md`, `docs/gdd.md`, `docs/decisiones.md`.

## Arquitectura
- `core/`: lógica pura (`RefCounted`, sin nodos ni RNG global; cada motor recibe su `RandomNumberGenerator`).
  `MatchEngine` (partido), `CoachBot` (bots), `DuelRunner`/`sim.gd` (partidos bot contra bot y balance).
- `scenes/`: UI. `calendar_view` (semana como mesa del DT, escena principal), `match_view` (partido),
  `card_ui` (lámina) y `scenes/ui/` (tema, `Paleta`, `Icono`, `Escudo`, `Mesa`; letras en `assets/fonts/`).
- `scripts/`: carrera y liga (`Career`, `SquadManager`, `LeagueManager`). `Career.current` sobrevive entre escenas.
- `data/`: catálogo y reglas en JSON (`cards.json`, `decks.json`, `career_2006.json`, ...).
- `tests/`: `engine_rules`, `career_rules`, `data_rules`, `smoke_match`, `smoke_career`, `balance_lab`.
- La probabilidad de una carta sale solo de `MatchEngine.chance_breakdown`; si cambias el flujo del
  partido en `match_view`, replícalo en `DuelRunner`.

## Restricción de lectura (ahorro de tokens)
- **Nunca leas enteros** `data/squads_2006.json`, `data/history_2006.json`, `data/teams_chile_2006.json`
  ni `docs/mercado.md`. Para ver el formato: `head -n 20`; para un dato: `grep`. Las lecturas de esos
  JSON, `.godot/`, `*.uid` y `tools/t08/` están bloqueadas en `.claude/settings.json`.
- No escanees carpetas enteras: busca con Grep/Glob y lee solo los archivos y líneas que necesites.

## Comandos
- Verificación: `& .\.claude\skills\godot-check\check.ps1` (`-SkipSmoke`, `-Balance`; Linux: `check.sh`).
  Imprime una línea si pasa y las últimas 25 si falla; el log completo queda en `%TEMP%\godot-check\`.
- Capturas de la UI (con pantalla): `..\Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/capturas.gd -- --out=RUTA`.
- git: `C:\Program Files\Git\cmd\git.exe` (no está en el PATH). Repo `vKieferv/BONVALET`, rama `main`.

## Reglas
- Una sola fuente de verdad: `main`. Antes de numerar una decisión (D-NN) o idea (I-NN), revisa el último número.
- Ideas nuevas → skill `idea-nueva` (sin código); balance → `balance-lab`; tareas sin el usuario → `tarea-autonoma`.
- Estilo visual → skill `director-arte-2006`. Tras tocar `.gd`, `.tscn` o `data/*.json` → `godot-check`.
- Godot 4.7 no infiere tipo desde un `Variant`: `var x: float = dict["k"]`. Indentación: tabs en `core/` y
  `tests/`, 4 espacios en `scenes/` y `scripts/` (respeta la del archivo).
- Marcas siempre parodiadas (Cerveza Glaciar, Telnet, Diario El Chisme); datos históricos solo con fuente.
- No mates procesos Godot por nombre: el usuario suele tener el editor abierto.
