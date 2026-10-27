# T-02 · Reglas de M1: jugadas de Catenaccio y lesión tardía de Kamikaze

Brief para una sesión autónoma (skill `tarea-autonoma`).

- **Hito:** M1
- **Rama:** `tarea/t-02-reglas-m1`
- **Decisiones:** D-16 (3 jugadas, 2 para Catenaccio) y D-17 (Kamikaze lesión tardía ×2.5)

## Objetivo
Aplicar en el juego las dos decisiones de balance de M1, medidas antes con `balance-lab`
(`tests/lab/m1.json`): los Momentos de los equipos Catenaccio piden 2 jugadas (también cuando el
jugador dirige uno) y Kamikaze multiplica la lesión tardía por 2.5 en vez de 4.

## Alcance
- `core/bot_profile.gd`: campo exportado `moment_steps` (por defecto `MatchEngine.MOMENT_STEPS`, 3);
  `catenaccio()` lo fija en 2; `kamikaze()` pasa `late_injury_mult` de 4.0 a 2.5. `configure_engine`
  le pasa `moment_steps` al motor. Actualiza `describe()` si corresponde.
- `core/match_engine.gd`: variable `moment_steps` (por defecto `MOMENT_STEPS`) que usa `_make_moment`
  en lugar de la constante. Comenta la constante y la variable con su efecto (convención de la cabecera).
  Revisa `begin_moment`: `exploit_rival_space` y `counter_ready` deben seguir dejando el Momento en
  2 jugadas como mínimo (con `moment_steps` = 2 el espacio rival no lo acorta más; está bien).
- **El jugador también:** en `scenes/match_view.gd` (`_begin_match`), el motor del jugador toma
  `moment_steps` del perfil de **su** club (`_league.profile_for_team` del club propio), igual en
  partido rápido y en carrera. El rival ya lo recibe vía `configure_engine`.
- `core/duel_runner.gd`, `core/sim_runner.gd` y `core/sim.gd` ya pasan por `configure_engine`;
  comprueba que la constructibilidad de `sim.gd` siga midiendo Momentos de 3 jugadas.
- `tests/engine_rules.gd`: un club Catenaccio genera Momentos de 2 jugadas y uno de otro arquetipo de 3;
  Kamikaze tiene `late_injury_mult` 2.5.
- `CLAUDE.md` (Momentos, Versión actual con la nueva línea base) y `docs/gdd.md` (2.1 y arquetipos).

## Fuera de alcance
- Cualquier otra constante o carta. Tiki-Taka sigue en 3 (I-09 queda en espera).
- La Intercepción (D-18) y el guardado (D-19).

## Definición de terminado
- [ ] `godot-check` en verde **con `-Balance`** (`check.sh --balance`). Valores esperados según el
      laboratorio: matriz ~2.57 goles (dentro de 2.3-2.6), lesiones ~3.2%, Palestino ~1.18 goles a
      favor, La Serena ~14-15% de partidos con lesión. Si la matriz sale fuera de rango, **no
      recalibres**: repórtalo en el PR con la tabla.
- [ ] La línea base de `balance-lab` (sin variantes) coincide con la matriz de `-Balance`.
- [ ] PR con: qué cambia para el jugador (dirigir un club Catenaccio se siente distinto), tabla
      antes/después y lo que quedó sin verificar.

## Preguntas abiertas
- El margen superior de goles queda justo (2.57 de 2.6). Si al implementarlo sale 2.6 o más, se
  decide juntos qué hacer; anótalo en el PR.
