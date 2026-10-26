# Registro de decisiones

Cada decisión de diseño o de balance que cierra un debate. Antes de reabrir algo, se lee su entrada;
para cambiarlo se agrega una entrada nueva que la reemplace (no se borra la vieja).

Formato: **D-NN · fecha · título** — qué se decidió, por qué, qué se descartó, cómo se mide.
Estado: VIGENTE, REEMPLAZADA (por D-NN) o EN REVISIÓN (con el hito donde se revisa).

---

**D-01 · 2026-10-26 · Marcas siempre parodiadas** · VIGENTE
Sponsors, diarios, canales y marcas nunca usan nombres reales: parodias nostálgicas (Cerveza
Glaciar, Telnet, Diario El Chisme, Televisora Nacional). Clubes, DT y jugadores sí son reales por
ahora (ver I-20 sobre licencias antes de vender).

**D-02 · 2026-10-26 · Datos históricos solo con fuente** · VIGENTE
Si un dato de 2006 no se puede confirmar, va `null` y una entrada en `review`; el juego tiene textos
por defecto. Fuente que funcionó: Wikidata (P54, P569, P27).

**D-03 · 2026-10-26 · Mazo unificado con filtro de posesión** · VIGENTE
Un solo mazo de 18-20 cartas; `DeckManager.possession` filtra qué se roba en ataque y en defensa.
Despeje de Emergencia fuera del mazo. Descartado: mazos separados de ataque y defensa.

**D-04 · 2026-10-26 · PA por turno y Estamina Global separados** · VIGENTE
Los PA (LOW 3, NORMAL 3, HIGH 4; defensa 2) limitan qué se juega en un turno; la estamina es el
desgaste del partido. **La estamina nunca toca el % de acierto ni bloquea jugadas**: solo cambia el
robo (−0/−1/−2 cartas), las lesiones y las cartas de penalización. Por qué: un solo recurso mezclaba
decisiones de turno y de partido y castigaba dos veces el cansancio. Descartado: penalizar el
acierto por zona de estamina.

**D-05 · 2026-10-26 · LOW conserva 3 PA** · VIGENTE
Su identidad es gastar menos estamina (×0.75), el −15 en remates y el tope de Momentos, no tener
menos acciones. Descartado: LOW con 2 PA (no podía jugar élites).

**D-06 · 2026-10-26 · Funado = +50% de desgaste en sus cartas** · VIGENTE
Reemplaza el "+1 de estamina" del GDD original, que no escalaba con el nuevo desgaste.

**D-07 · 2026-10-26 · Una sola fuente de probabilidad** · VIGENTE
`chance_breakdown(card)` arma el % mostrado y el tirado (`roll < success_chance`). Todo modificador
nuevo entra ahí. Lo comprueban `engine_rules` y `smoke_match` (pilar 2).

**D-08 · 2026-10-26 · Paridad del rival** · VIGENTE
El rival arma su mazo con `SquadManager` igual que tú, activa el Ejecutor Natural y defiende tus
ataques según su perfil. Por qué: un rival con reglas propias no se puede balancear con el simulador.

**D-09 · 2026-10-26 · Ceder Jugada se mantiene junto a Aguantar** · VIGENTE
Ceder sigue siendo la salida sin riesgo; Aguantar es la apuesta. Descartado: que Aguantar
reemplazara a Ceder.

**D-10 · 2026-10-26 · Aguantar el Balón** · VIGENTE
Una vez por Momento, 1 PA (0 si no quedan, y entonces el éxito da +1 PA), 3 de estamina, 80% menos
la Presión rival. Éxito: mano nueva según la zona y Flow cortado sin la penalización del 15%.
Fallo: el rival roba y queda con contragolpe. Por qué: en el playtest muchas manos no podían armar
jugada y la única salida era ceder.

**D-11 · 2026-10-26 · Costos de PA de los remates** · VIGENTE
Desmarque 0 PA (física, desgaste alto), Tiro de lejos 1, Remate de primera y el genérico "Sello de
[figura]" 2, firmas con nombre propio 3 (Zapatazo, Arremetida; Sangre fría 2). Mide: constructibilidad
de mano ≥85% (Momentos de 3 jugadas, estamina llena). Resultado: 87%.

**D-12 · 2026-10-26 · 4 Momentos por equipo, de 3 jugadas** · VIGENTE · EN REVISIÓN en M1
4 Momentos propios (LOW 3, HIGH puede sumar) y todos piden 3 jugadas; los de 2 salen solo del
contragolpe o del espacio rival. Por qué: con remates a 2 PA y Aguantar, la matriz subió a 2.96
goles; 3 jugadas fijas la dejan en rango sin bajar los % que ve el jugador. Descartado: dificultad
+7 pts (bajaba todos los % mostrados). **Choca con el GDD** (largo de jugada por arquetipo:
Tiki-Taka 3-4, Directo 1-2, Catenaccio 1): se decide en M1.

**D-13 · 2026-10-26 · Desgaste y lesiones tras Aguantar** · VIGENTE
`STAMINA_SCALE` 2.0 → 1.6 y `INJURY_CHANCE_MAX` 0.012 → 0.009. Por qué: Aguantar suma jugadas
estando agotado. Descartado: `STAMINA_SCALE` 1.5 (no alcanzaba y adelgazaba el cansancio).

**D-14 · 2026-10-26 · Objetivos de balance** · VIGENTE
Matriz neutral bot vs bot (`godot-check -Balance`): 2.3-2.6 goles totales por partido, 2-5% de
equipos lesionados, cansancio concentrado en el 2T, constructibilidad ≥85%. Son barandas del
simulador; la diversión se valida con playtests humanos (`docs/playtests/`).

**D-15 · 2026-10-26 · Proceso de desarrollo** · VIGENTE
Pilares (`pilares.md`), GDD vivo con estados (`gdd.md`), buzón de ideas (`ideas.md`), este
registro y hitos con criterio de salida (`roadmap.md`). Las ideas nuevas no entran al sprint en
curso. Las sesiones autónomas implementan tareas decididas; las reglas del partido se deciden juntos.

### Descartadas (para no reabrirlas sin datos nuevos)
- **Tempo ofensivo +7 / regen +3** (2026-10-26): no llegaba al objetivo de goles y quedó obsoleto con
  PA + Estamina; el stash se borró.
- **Dificultad base +7 pts** como palanca de goles (2026-10-26): ver D-12.
