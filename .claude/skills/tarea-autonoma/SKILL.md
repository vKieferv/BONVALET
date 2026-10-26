---
name: tarea-autonoma
description: Procedimiento para ejecutar sola, sin el usuario presente (sesión en la nube o desde el celular), una tarea de Futbolista Deckbuilder descrita en docs/tareas/T-NN-*.md - rama propia, implementación dentro del alcance, verificación con godot-check y PR con métricas. Úsalo cuando te pidan "corre la tarea T-NN", "trabaja en esto mientras no estoy" o al iniciar una sesión autónoma sobre el repo.
---

# tarea-autonoma

El usuario revisa el resultado desde el celular, así que el PR tiene que poder entenderse sin abrir
el código, y la tarea no puede tomar decisiones de diseño por él.

## Antes de empezar
1. Lee el brief `docs/tareas/T-NN-*.md`, `CLAUDE.md` y las entradas de `docs/decisiones.md` que cite.
2. Comprueba que el brief tenga objetivo, alcance, fuera de alcance y definición de terminado. Si
   falta algo esencial, **no lo inventes**: abre el PR solo con el brief completado como propuesta, o
   detente explicando qué falta.
3. Crea la rama del brief (`tarea/t-nn-nombre`) desde `main` actualizado.

## Durante
- Solo toca lo que el alcance permite. Lo que veas fuera de alcance va como nota en el PR o como
  fila en `docs/ideas.md`, no como cambio.
- **No cambies reglas del partido ni números de balance** salvo que la tarea sea eso. Si una
  prueba de balance sale de rango por tu cambio, repórtalo; no recalibres por tu cuenta.
- Cada regla nueva lleva su comprobación en `tests/engine_rules.gd` (o `career_rules.gd`).
- Commits pequeños y descriptivos, en el estilo del historial (`feat(...)`, `fix(...)`, `docs:`).

## Verificar
- `godot-check` en verde; `-Balance` si tocaste `core/`, `data/` o `scripts/career.gd`.
- En Linux (sesión en la nube) usa la versión de la verificación para Linux cuando exista (ver
  Sprint 0 en `docs/roadmap.md`); si todavía no existe, dilo en el PR: "sin verificar en Godot".

## Entregar
PR hacia `main` con:
1. **Qué cambió** en 3-5 líneas, en lenguaje de juego (qué ve o hace el jugador distinto).
2. **Verificación:** resultado de `godot-check` y, si aplica, tabla de métricas antes/después.
3. **Decisiones pendientes** para el usuario (preguntas abiertas del brief).
4. **Lo que quedó sin hacer o sin verificar.**

Marca la casilla de la tarea en `docs/roadmap.md` solo cuando el PR esté aprobado por el usuario.
