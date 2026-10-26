---
name: playtest
description: Convierte las notas de una sesión de juego del usuario (texto suelto, audio transcrito, capturas) en un informe de playtest estructurado en docs/playtests/ con hallazgos clasificados por pilar, tipo y severidad, y propuestas para el buzón de ideas o tareas de bugs. Úsalo cuando el usuario cuente cómo le fue jugando, pegue impresiones de un partido o una carrera, o diga "hice un playtest".
---

# playtest

Los playtests del usuario valen más que la matriz de bots: son la única forma de saber si el juego
es divertido. Esta skill los convierte en datos sin perder su voz.

## Pasos
1. **Ubicar la versión:** commit actual (`git log -1 --format=%h`) y modo jugado (partido rápido o
   carrera, club, rival, posturas). Si faltan datos clave, pregunta una sola vez.
2. **Separar** en las notas: lo que intentó hacer, lo que se sintió bien, lo que se sintió mal o
   confuso (qué pasó vs. qué esperaba).
3. **Contrastar con el código** antes de clasificar: muchas quejas son de lectura (el juego hizo lo
   correcto pero no se entendió) y no de reglas. Revisa `core/match_engine.gd` y la UI en
   `scenes/match_view.gd` si hace falta.
4. **Clasificar cada hallazgo:** pilar afectado (`docs/pilares.md`), tipo (regla / balance / UI /
   bug / contenido) y severidad (alta = rompe la partida o la decisión central; media = molesta
   seguido; baja = detalle).
5. **Escribir** `docs/playtests/AAAA-MM-DD-tema.md` con la plantilla `docs/playtests/_plantilla.md`.
6. **Derivar:**
   - bugs → tarea en `docs/tareas/` (plantilla `_plantilla.md`) o arreglo inmediato si el usuario lo pide;
   - cambios de reglas o mecánicas → filas en `docs/ideas.md` (vía el método de la skill `idea-nueva`);
   - balance → hipótesis para `balance-lab`, con la métrica que debería moverse.
7. **Resumir** en el chat: los 3 hallazgos más importantes y qué propones hacer con cada uno.

## Reglas
- No cambies reglas ni números del juego dentro de esta skill.
- Cita al usuario cuando su frase capture bien la sensación ("se me quedaba la mano muerta").
- Los criterios de salida de M1 cuentan playtests sin cambios grandes de reglas: indica en el
  informe si este playtest pide uno.
