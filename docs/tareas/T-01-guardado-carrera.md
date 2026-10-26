# T-01 · Guardar y cargar la carrera

Brief para una sesión autónoma (skill `tarea-autonoma`). Primera tarea de prueba del ciclo
nube → PR → revisión desde el celular.

- **Hito:** M3 (adelantada: no depende de las decisiones de reglas de M1)
- **Rama:** `tarea/t-01-guardado-carrera`
- **Ideas / decisiones relacionadas:** I-11

## Objetivo
Que cerrar el juego no borre la carrera: el progreso se guarda solo y desde el calendario se puede
**continuar la carrera guardada** en la misma semana, con el mismo estado.

## Alcance
- `scripts/career.gd`:
  - `to_dict() -> Dictionary` con `"version": 1` y todo el estado de la carrera: `team_id`, `week`,
    `budget`, `popularity`, `discipline`, `fatigue`, `sponsor_id`, `history`, `event_result`,
    `training`, `match_mods`, `sponsor_week_lost`, `rival_id`, `pending_match` y el estado del
    `rng` (`seed` y `state`, para que los eventos aleatorios sigan igual tras cargar).
  - Carga: una función estática que reciba `LeagueManager`, `SquadManager` y la ruta, llame a
    `setup()` con el `team_id` guardado (recarga `data`, `templates`, etc. desde los JSON) y después
    aplique el estado guardado. Devuelve `null` y deja el motivo en `load_errors` si el archivo no
    existe, no es JSON, trae otra `version` o un club desconocido. Nunca debe romper el juego.
  - `save(path)` y la ruta por defecto en una variable estática `Career.save_path`
    (`"user://carrera.json"`). **Las pruebas la cambian** a una ruta propia
    (`"user://test_carrera.json"`) para no pisar la partida real del usuario.
- `scenes/calendar_view.gd`:
  - En la pantalla inicial, botón **"Continuar carrera"** junto al de comenzar, habilitado solo si
    hay un guardado válido, con el club y la semana en el texto (ej. "Continuar · Colo-Colo ·
    Semana 3").
  - Guardado automático tras cada acción de bloque (sponsor, evento, entrenamiento) y al volver del
    partido al calendario (la semana nueva ya registrada).
  - Comenzar una carrera nueva reemplaza el guardado.
- Si al cargar `pending_match` viene en `true` (se cerró el juego durante el partido), la carrera
  vuelve al calendario con el Bloque 3 listo para jugar ese partido desde el principio: no se
  guarda el estado a mitad de partido.

## Fuera de alcance
- Reglas del partido, números de balance, `core/` (salvo que algo sea imposible sin tocarlo: en ese
  caso, detente y explícalo en el PR).
- Varias ranuras de guardado, guardado en la nube, guardar a mitad de partido.
- Rediseñar la pantalla del calendario más allá del botón nuevo.

## Definición de terminado
- [ ] `tests/career_rules.gd`:
  - ida y vuelta: carrera con semilla fija → sponsor, evento, entrenamiento, `record_match` →
    guardar → cargar → todos los campos iguales, y el evento de la semana siguiente sale igual en la
    original y en la cargada (estado del `rng`);
  - archivo inexistente, JSON roto y `version` distinta → `null` con motivo, sin errores de script;
  - las pruebas usan `Career.save_path` de prueba y borran su archivo al final.
- [ ] `tests/smoke_career.gd` sigue pasando y **no** escribe en `user://carrera.json`.
- [ ] `godot-check` en verde (`check.sh` en Linux); no hace falta `-Balance` (no se toca `core/`).
- [ ] `CLAUDE.md` (sección Modo carrera) y `docs/gdd.md` (5.4: guardado pasa a DECIDIDO) actualizados;
      I-11 en `docs/ideas.md` marcada como implementada en esta tarea.
- [ ] PR hacia `main` con: qué cambia para el jugador, resultado de la verificación, y lo que quedó
      sin verificar (en particular, que el botón se vea bien: las pruebas no miran la pantalla).

## Preguntas abiertas
- Recargar el guardado permite repetir un partido perdido si se cierra el juego durante el partido.
  Para esta tarea se acepta; anótalo en el PR como decisión pendiente (¿guardar el resultado al
  entrar al partido como derrota provisional?).
