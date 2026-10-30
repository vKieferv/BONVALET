# Hoja de ruta

Etapa actual: **prototipo jugable, entrando a vertical slice** (2026-10-26).

Cada hito tiene un criterio de salida. Al cerrarlo, sus reglas se congelan: cambiarlas exige una
entrada en `decisiones.md`. Las ideas nuevas van a `ideas.md`, no al hito en curso.

| Hito | Objetivo | Criterio de salida |
|---|---|---|
| **Sprint 0 · Cimientos** | Cerrar Aguantar, documentos de diseño, skills, GitHub y pruebas en la nube | El repo está en GitHub, las pruebas corren solas en cada PR y el GDD vive en el repo |
| **M1 · El partido es divertido** | Decidir y congelar las reglas del partido + mínimo de sensación de juego | 5 playtests seguidos (`docs/playtests/`) sin cambios grandes de reglas |
| **M2 · Deckbuilder de verdad** | Ganar, quitar y mejorar cartas; perfiles de DT; canteranos | Dos carreras distintas terminan con mazos claramente distintos |
| **M3 · Una temporada** (vertical slice) | Apertura 2006 completo: fixture, tabla, guardado, fin del torneo | Se juega de principio a fin con un club |
| **M4 · Identidad** | Dirección de arte, sonido, menú, tutorial | Hay GIFs y video para una página de Steam |
| **M5 · Contenido** | Más planteles, Primera B, Clausura, eventos | Demo pública |

## Sprint 0 · Cimientos
- [x] Aguantar el Balón, remates a 2 PA, constructibilidad (D-10 a D-13)
- [x] Pilares, GDD vivo, buzón de ideas, registro de decisiones, esta hoja de ruta
- [x] `balance-lab` permanente y skills de proceso (`idea-nueva`, `playtest`, `tarea-autonoma`)
- [x] Repo privado en GitHub (`vKieferv/BONVALET`)
- [x] Versión Linux de la verificación (`check.sh`) + GitHub Actions en cada push y PR
- [x] Probar una tarea autónoma de punta a punta: T-01 (sesión en la nube → PR #1 → revisión → mezcla)

## M1 · El partido es divertido
Preguntas, medidas con `balance-lab` (`tests/lab/m1.json`) y decididas el 2026-10-26:
- [x] Largo de jugada → 3 para todos, 2 para Catenaccio (D-16). Tiki-Taka 3-4 en espera (I-09).
- [x] Kamikaze → lesión tardía ×2.5, ~15% (D-17).
- [x] Catenaccio marca poco → se resuelve con sus 2 jugadas (D-16).
- [x] Contragolpe sobre Colo-Colo → no se toca la Intercepción; jerarquía con el plantel, I-06 (D-18).
- [x] Guardado: cerrar a mitad de partido → se repite el partido (D-19).
- [ ] Sensación de juego: 5 playtests con `docs/playtests/_plantilla.md`, foco en: ¿entiendo por qué
      gané o perdí cada jugada?, ¿el ritmo de las animaciones cansa?, ¿sé cuándo mi mano puede armar
      un gol? (si no, I-32).

Tareas:
- [x] T-02 · aplicar D-16 y D-17 (autónoma, mezclada: 2.55 goles, 3.3% lesiones, Kamikaze 14.7%)
- [ ] T-03 · resumen post-partido con el % de cada jugada y goles esperados vs. reales (I-35):
      hace visible que el azar es justo (pilar 2) y ayuda a responder los playtests (brief por escribir)
- [ ] Playtests 1-5 (usuario) → skill `playtest`; los arreglos que salgan, como tareas nuevas

**Duelos por línea (I-45, D-28 a D-32, `docs/cartas.md`):** el usuario diseñó en papel un modelo nuevo
del partido (cada jugada contra un jugador rival, habilidades, formaciones por estilo, fallar no corta el
Momento, cansancio por jugador). Si se adopta, cambia el corazón de M1 y obliga a recalibrar. Siguiente
paso: un **prototipo medido** en una rama de diseño (motor mínimo + `balance-lab` + playtest) antes de
decidir. Mientras tanto no se sigue afinando el modelo actual (la curva de M2 espera esa decisión).

## Ahora · Cara visual y partido por zonas (2026-10-28)
Antes de seguir, el juego tiene que dar ganas de jugarlo (usuario). Orden decidido (D-35): primero lo
visual, después el partido por zonas con su pantalla nueva.
- [x] T-09 · lámina, íconos y semana como mesa del DT (mezclada el 2026-10-29; capturas en `../capturas-t09/`)
- [x] T-10 · motor del partido por zonas, bots y medición (`T-10-partido-por-zonas.md`, D-36; puede
      correr en la nube; mejor tras mezclar T-06) · mezclada 2026-10-30 como modo en prueba (12 pts por jugador); falta jugarla a mano
- [ ] T-12 · prueba técnica de la cancha 3D low poly (`T-12-prueba-3d.md`, I-54; en el PC; decide si T-11 va en 3D)
- [ ] T-11 · pantalla del partido como señal de TV por zonas (`T-11-pantalla-partido.md`, D-37; en el PC; tras T-09 y T-10)
- [ ] Decisión del usuario tras medir y jugar: ¿el modo de zonas reemplaza al actual?

## M2 · Deckbuilder de verdad (diseño cerrado, en implementación)
Diseño:
- [x] Bucle del mazo (D-20 a D-22): Bloque 2 = carta (1 de 3) / mejora / kinesiología; los rivales
      también crecen. Detalle en GDD 3.4.
- [x] Mazo inicial estándar + carta de rasgo del DT (D-23, EN PRUEBA): medido con `balance-lab`
      (`tests/lab/m2_propuesta.json`, `m2_crecimiento.json`). Detalle en GDD 3.5.
- [ ] Curva de la temporada: medida oficialmente en T-04 (inicio 2.47, mitad 2.73, final 2.65). Espera
      la decisión de los duelos antes de recalibrar.
- [ ] Canteranos y progresión (I-05): por diseñar.
- [ ] Modo Copa (I-34): por diseñar; partida corta de 5-6 partidos con mazo que crece, sirve de demo.

Tareas (en este orden; cada una termina en un PR):
- [x] T-04 · mazo estándar, cartas de rasgo y balance por etapa (PR #4, mezclada el 2026-10-28)
- [x] T-05 · Bloque 2 con carta, video o kinesiología y mazo propio guardado (mezclada el 2026-10-28)
- [ ] T-06 · los rivales crecen durante la temporada (`T-06-rivales-crecen.md`, tras T-04; mejor después de T-05)

## M3 · Una temporada (diseño decidido, datos en preparación)
- [x] Formato fiel a 2006 (D-24), los demás partidos simulados (D-25), comparar con la realidad (I-36).
- [x] Nombres reales en desarrollo, inventados al lanzar, datos reemplazables (D-26); base de jugadores
      con Wikidata y atributos propios (D-27).
- [x] T-07 · datos históricos del Apertura y Clausura 2006 (mezclada el 2026-10-28; corrida en el PC)
- [x] Descenso real de 2006 (D-33): último directo; 17.º y 18.º a liguilla con Primera B.
- [x] T-08 · planteles 2006 desde Wikidata (mezclada el 2026-10-28): Audax, Unión Española y Palestino
      quedaron reales (D-34); los demás siguen generados. Por decisión del usuario se cierra la extracción
      de bases: para desarrollar basta Chile 2006 tal como está.
- [ ] Implementación de la temporada (fixture real, tabla, grupos, repechaje, playoffs, descenso,
      comparación): briefs después de M2.

## Antes de M4 (comercial, del estudio `docs/mercado.md`)
- [ ] Paquetes de datos reemplazables y Steam Workshop (I-37, D-26): el paquete por defecto, con nombres
      inventados; lo público (página, tráiler, demo) nunca con nombres reales.
- [ ] Textos traducibles con las tablas de Godot, para una demo en inglés y español (I-33, tarea autónoma)
- [ ] Consulta con un abogado sobre nombres reales (I-20, la hace el usuario) y paquete de datos
      ficticio que pase todas las pruebas, para que cualquier respuesta se resuelva cambiando datos
- Precio orientativo US$14,99; Steam PC + Steam Deck; página al cerrar M4; demo en Steam 2-3 meses
  antes del Next Fest elegido (revisar los datos en vivo antes de decidir)

## Trabajo autónomo vs. juntos
- **Autónomo** (sesión en la nube, termina en PR): tareas con brief cerrado y verificables con
  pruebas o el simulador. Plantilla: `docs/tareas/_plantilla.md`.
- **Juntos:** decisiones de reglas, sensación de juego, prioridades, revisión de playtests.
