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

**Duelos (I-45, D-28 a D-48):** adoptado. El modo de duelos (portador, marcas, habilidades) es el partido
por defecto desde T-11; el modo actual y el de zonas quedan como opción para comparar. Los playtests de
M1 se hacen ahora sobre los duelos.

## Siguiente, en este orden (revisado el 2026-11-09)
1. **Cerrar T-15** (defensa por arrastre y desenlaces del fallo, D-44 y D-48): playtest del usuario y mezcla.
2. **Mazo nuevo y cartas v2** (D-45 y D-47): brief por escribir tras T-15.
3. **Una sola medición con el mazo nuevo** para decidir juntos la curva de la temporada (mitad y final
   sobre 2,6) y el cansancio (I-59: quitarlo, dejarlo o por jugador).
4. **T-03, más chico:** el resumen post-partido (I-35); la tirada visible ya cubre parte.
5. **M3:** la temporada completa.
Pendientes sueltos: perfiles de la élite (propuesta del 2026-11-03 sin confirmar), Steam Deck.

## Hecho · Cara visual y partido nuevo (2026-10-28 a 2026-11-09)
Antes de seguir, el juego tiene que dar ganas de jugarlo (usuario). Orden decidido (D-35): primero lo
visual, después el partido por zonas con su pantalla nueva.
- [x] T-09 · lámina, íconos y semana como mesa del DT (mezclada el 2026-10-29; capturas en `../capturas-t09/`)
- [x] T-10 · motor del partido por zonas, bots y medición (`T-10-partido-por-zonas.md`, D-36; puede
      correr en la nube; mejor tras mezclar T-06) · mezclada 2026-10-30 como modo en prueba (12 pts por jugador); falta jugarla a mano
- [x] T-12 · prueba técnica de la cancha 3D low poly (`T-12-prueba-3d.md`, I-54) · mezclada 2026-11-01 en `scenes/prueba_3d/`: T-11 va en 3D (D-41), falta medir en Steam Deck
- [x] T-13 · motor de D-40 a D-43: portador, marcas y habilidades (`T-13-motor-portador-marcas.md`) · mezclada 2026-11-03 como modo de duelos en prueba (2.45 goles al inicio)
- [x] T-11 · pantalla del partido: TV de 2006, cancha 3D y duelos (`T-11-pantalla-partido.md`) · mezclada 2026-11-04; duelos por defecto, defensa nueva (D-44) pendiente
- [ ] T-15 · la defensa nueva y los desenlaces del fallo (`T-15-defensa-nueva.md`, D-44, D-48) · en curso
- [x] T-14 · eventos de la semana: catálogo, medios y ramas (`T-14-eventos-semana.md`, I-57) · mezclada 2026-11-03; valores de los efectos en prueba
- [x] ¿Qué modo es el partido? → los duelos, por defecto desde T-11 (2026-11-04)

## M2 · Deckbuilder de verdad (diseño cerrado, en implementación)
Diseño:
- [x] Bucle del mazo (D-20 a D-22): Bloque 2 = carta (1 de 3) / mejora / kinesiología; los rivales
      también crecen. Detalle en GDD 3.4.
- [x] Mazo inicial estándar + carta de rasgo del DT (D-23, EN PRUEBA): medido con `balance-lab`
      (`tests/lab/m2_propuesta.json`, `m2_crecimiento.json`). Detalle en GDD 3.5.
- [ ] Curva de la temporada: medida en T-04 (2.47 / 2.73 / 2.65) y con duelos en T-15 (2.38 / 2.63 / 2.61). Espera
      el mazo nuevo (paso 3 de "Siguiente").
- [ ] Canteranos y progresión (I-05): por diseñar.
- [ ] Modo Copa (I-34): por diseñar; partida corta de 5-6 partidos con mazo que crece, sirve de demo.

Tareas (en este orden; cada una termina en un PR):
- [x] T-04 · mazo estándar, cartas de rasgo y balance por etapa (PR #4, mezclada el 2026-10-28)
- [x] T-05 · Bloque 2 con carta, video o kinesiología y mazo propio guardado (mezclada el 2026-10-28)
- [x] T-06 · los rivales crecen durante la temporada (mezclada el 2026-10-29)

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
