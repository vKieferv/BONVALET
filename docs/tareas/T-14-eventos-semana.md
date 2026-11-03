# T-14 · Eventos de la semana: catálogo, medios y ramas

Brief para una sesión (skill `tarea-autonoma`). Necesita ver la pantalla para las capturas de la mesa del DT
(`tools/capturas.gd`); el resto corre sin ventana.

- **Hito:** M2
- **Rama:** `tarea/t-14-eventos-semana`
- **Ideas / decisiones relacionadas:** **I-57** (el catálogo), D-35 y D-37 (la mesa del DT), D-01 (marcas
  parodia). Catálogo completo: `docs/eventos.md`. Origen: playtest 2026-10-29 ("hay que variar más opciones
  de prensa").

## Objetivo
Que cada semana traiga un evento distinto del catálogo de `docs/eventos.md`, con 2 o 3 opciones, los
efectos a la vista antes de elegir y ramas que vuelven semanas después. Hoy hay un solo evento y
`Career.resolve_event` solo sabe hacer "fiesta con riesgo de funa".

## Alcance
1. **Datos** en `data/career_2006.json` (o en un archivo nuevo `data/eventos_2006.json` si queda más limpio):
   los 27 eventos y las 8 ramas de `docs/eventos.md`, con su medio, su tipo, sus opciones y sus efectos.
   Formato genérico: cada opción es una lista de efectos de la tabla 1 de `eventos.md`. El Bautizazo se
   reescribe en ese formato y debe seguir dando lo mismo.
2. **Efectos en `Career`**, uno por tipo de la tabla 1: popularidad, disciplina, presupuesto, fatiga, arranque
   (también negativo), rival motivado, funa con su probabilidad, carta temporal por una semana, promesa (se
   resuelve en `record_match` según el resultado) y "vuelve en N semanas" (marca guardada que dispara el
   evento de la rama). Si un efecto necesita tocar el partido (arranque negativo, rival motivado), entra por
   `configure_match` y el `match_mods`, como hoy el arranque. **No se toca `core/`** salvo que no haya otra
   forma; si hace falta, dilo en el informe.
3. **Mazo de eventos:** se baraja con el RNG de la carrera al empezar la temporada; no se repite hasta salir
   todos; los de rama y los que tienen condición ("después de una derrota", "antes de un clásico") entran
   cuando corresponde. Los nombres entre corchetes salen del plantel real (como hoy el funado).
4. **Guardado:** las marcas de rama, el mazo y las promesas pendientes se guardan y se cargan (subir la
   versión del guardado con migración, como en T-01).
5. **Pantalla (`calendar_view`, paso Prensa):** el medio de cada evento se reconoce (su nombre y su letra en
   la portada o en el micrófono de la conferencia), con las 2 o 3 opciones y sus efectos en íconos, según la
   skill `director-arte-2006`. Hoy la portada siempre dice "Diario El Chisme".
6. **Pruebas:** en `career_rules.gd`, cada tipo de efecto, el mazo sin repetir en una temporada, una rama que
   vuelve a las N semanas, una promesa cumplida y una rota, y guardar y cargar con ramas pendientes. En
   `smoke_career.gd`, varias semanas seguidas con eventos distintos. En `data_rules.gd`, que todo evento sea
   válido (medio conocido, efectos conocidos, ramas que apuntan a eventos que existen).

## Fuera de alcance
- El motor del partido y su balance. Los valores de los efectos son de prueba: se ajustan jugando.
- La relación con cada medio (idea para más adelante en `eventos.md`).
- Escribir eventos nuevos fuera del catálogo: si falta uno para que una rama tenga sentido, anótalo.

## Definición de terminado
- [ ] `godot-check` en verde.
- [ ] Pruebas nuevas en `career_rules`, `smoke_career` y `data_rules`.
- [ ] Capturas antes y después del paso Prensa con 3 medios distintos (`tools/capturas.gd`).
- [ ] `docs/arquitectura.md` (formato de eventos y efectos) y `docs/gdd.md` actualizados.
- [ ] Rama subida e informe con lo que quedó sin verificar.

## Preguntas abiertas
- Si un efecto del catálogo es ambiguo, se toma la versión más simple y se anota.
