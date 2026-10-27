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

**D-12 · 2026-10-26 · 4 Momentos por equipo, de 3 jugadas** · VIGENTE (precisada por D-16)
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

**D-16 · 2026-10-26 · Largo de jugada: 3 para todos, 2 para Catenaccio** · VIGENTE
Los Momentos piden 3 jugadas salvo Catenaccio, que pide 2 (su identidad "ultra corta" del GDD). Vale
para bots y para el jugador: si diriges un club Catenaccio, tus Momentos son de 2. Por qué
(`tests/lab/m1.json`): Catenaccio 2 sube a Palestino de 0.72 a 1.18 goles y la matriz queda en 2.57.
Descartado: largo del GDD por arquetipo (3.46 goles) y el GDD suavizado (2.72), porque alargar la
jugada sin compensación hunde a Tiki-Taka (Colo-Colo 0.63-1.01 goles). Tiki-Taka 3-4 queda en I-09,
atado a una mecánica que premie el pase largo. Cierra también la pregunta "Catenaccio marca poco"
(cambiar cuándo remata el bot no movía nada).

**D-17 · 2026-10-26 · Kamikaze: lesión tardía ×2.5** · VIGENTE
`late_injury_mult` de Kamikaze baja de 4.0 a 2.5: La Serena pasa de 21% a 14-15% de partidos con
lesión (el "hasta 15%" del diseño) y el total de la liga de 4.5% a ~3.2%, sin cambiar los goles.
Descartado: ×2 (~12%) y dejar ×4.

**D-18 · 2026-10-26 · La Intercepción no se toca** · VIGENTE
Los datos no la señalan: corta ~0.9 ataques por partido a Colo-Colo y quitarla o encarecerla casi
no cambia la tabla. La ventaja de la UC (Contragolpe) es de ataque (1.58 goles). La jerarquía entre
clubes (el Colo-Colo de 2006 debería ser el mejor) se resuelve con la fuerza del plantel (I-06),
no con el arquetipo. Nota: la Intercepción ya tiene bono 0 y el motor ignora los bonos negativos.

**D-19 · 2026-10-26 · Cerrar el juego a mitad de partido: se repite el partido** · VIGENTE
Como funciona desde T-01: al volver, el partido se juega desde el principio. Se acepta que se
pueda abusar (juego para un jugador). Descartado: perder por secretaría 0-3 y guardar a mitad de
partido (caro: estado completo del motor).

**D-20 · 2026-10-27 · Las cartas nuevas salen del entrenamiento: elegir 1 de 3** · VIGENTE
En el Bloque 2, el entrenamiento táctico ofrece 3 cartas de tu estilo y te quedas con una (ritmo de
una carta por semana, como Slay the Spire). Si el mazo está en su tope, la nueva reemplaza a otra:
así también se quitan cartas. Descartado: premio por resultado (el que pierde se queda atrás) y
mercado con presupuesto (economía que todavía no existe). Fichajes y canteranos serán otra fuente (M3).

**D-21 · 2026-10-27 · Bloque 2: elegir UNA entre carta, mejora o kinesiología** · VIGENTE
Entrenamiento táctico (carta nueva, D-20), sesión de video (mejorar una carta: +10 pts o −1 PA) o
kinesiología (−25 de fatiga). Crecer el mazo compite con descansar (pilar 3). La forma +3% del
entrenamiento táctico actual se reemplaza por la carta. Descartado: carta gratis todas las semanas.

**D-22 · 2026-10-27 · Los rivales también crecen durante la temporada** · VIGENTE
Cada semana el mazo del rival suma o mejora una carta de su arquetipo (paridad, D-08), para que el
simulador siga midiendo el juego real y el jugador no se vuelva imparable a mitad de torneo.
Descartado: mazo fijo con dificultad que sube por fecha.

**D-23 · 2026-10-27 · Mazo inicial estándar y cartas de rasgo del DT** · VIGENTE · EN PRUEBA
Todos los clubes empiezan con el mismo mazo estándar de 11 cartas del DT (Pase corto ×4, Promesa:
Control ×2, Remate simple ×1, Marca ×2, Despeje ×1) + una carta de rasgo según el arquetipo + la carta
firma de su figura (12 en total). Rasgos: Toque-toque (Tiki-Taka), Pelotazo (Directo), Cerrojo
(Catenaccio), Remate en carrera (Kamikaze) y Anticipo (Contragolpe); valores en GDD 3.5. Por qué:
idea del usuario (identidad desde la semana 1 y un mazo que crece con las elecciones, como Slay the
Spire). Medido en `tests/lab/m2_propuesta.json`: 2.47 / 2.71 / 2.61 goles al inicio, a mitad y al
final de la temporada. Reemplaza I-04 (perfiles de DT con mazos de 12-22). Los números de las cartas
son iniciales y se validan con playtests. Descartado: rasgos de Presión o Bloqueo reforzados (diluyen
el Despeje y empeoraban la defensa de su propio club) y 2 Remates simples (constructibilidad 99-100%).

**D-24 · 2026-10-27 · Temporada fiel al formato 2006** · VIGENTE
Apertura y Clausura como en 2006: 19 clubes (Deportes Concepción suspendido), todos contra todos a una
vuelta (19 fechas, 18 partidos y una fecha libre por club), 4 grupos para clasificar (los 2 mejores de
cada grupo, repechaje si un tercero supera en puntos a un segundo de otro grupo), cuartos, semis y final
a ida y vuelta (penales si hay empate global) y descenso por tabla acumulada del año (último directo,
penúltimo a liguilla de promoción). El calendario es el real de 2006 (mismo orden, local y fecha libre),
para poder comparar con la realidad (I-36). Descartado: playoffs a partido único y liga sin playoffs.
Fuente del formato: es.wikipedia, "Torneo Apertura 2006 (Chile)" y "Torneo Clausura 2006 (Chile)".

**D-25 · 2026-10-27 · Los demás partidos de la fecha se simulan** · VIGENTE
Los partidos entre otros clubes se juegan con los bots (`DuelRunner`), no se copian de 2006. La
realidad se muestra solo como comparación (I-36). Descartado: repetir los resultados reales.

**D-26 · 2026-10-27 · Nombres reales en desarrollo, inventados al lanzar, y datos reemplazables** · VIGENTE
Mientras se desarrolla, el juego usa clubes, DT y jugadores reales para que sea familiar. La versión
que se publique (y todo lo público: página de Steam, tráiler, demo) usa nombres inventados, y la
comunidad podrá cargar sus propias bases con equipos reales (Steam Workshop). Por eso **todo nombre de
club, DT y jugador tiene que salir de datos fáciles de reemplazar**, nunca del código. Reemplaza la
parte de I-20 sobre qué nombres llevar; la consulta con un abogado sigue pendiente (I-20). Paquetes de
datos y Workshop: I-37.

**D-27 · 2026-10-27 · Base de jugadores: Wikidata y atributos propios** · VIGENTE
Los hechos (club en 2006, posición, nacimiento, nacionalidad) salen de fuentes libres: Wikidata (CC0)
y, para cruzar, Wikipedia. Los atributos de juego (rol, estamina, nivel) los calcula una fórmula propia
y documentada. Sin fuente, `null` y una entrada en `review` (D-02). Descartado: copiar bases de otros
juegos (Football Manager, archivos de PES): son propiedad de sus estudios o de origen dudoso, y sus
puntajes son trabajo creativo ajeno.

**D-28 · 2026-10-27 · Planteles: es.wikipedia fecha lo que Wikidata deja sin fechas** · VIGENTE
Amplía D-27 (T-08). Si Wikidata registra que un jugador fue del club (P54) pero sin fecha de inicio o
de fin, la trayectoria de la ficha de su artículo en es.wikipedia (años por club) decide si estuvo en
2006. La ficha también afina una posición genérica de Wikidata en la misma línea (defensa → lateral),
da la posición si Wikidata no la tiene y desempata nacimiento y nacionalidad cuando Wikidata se
contradice o no los tiene. Los hechos siguen saliendo de fuentes libres. Por qué: con fechas, Wikidata
solo alcanzaba para 3 de los 16 clubes. Descartado: Transfermarkt (no es una fuente libre: sus
condiciones prohíben la extracción automatizada y su base está protegida; además bloquea las
consultas). Se mide en T-08: cuántos clubes de Primera A llegan a 18 jugadores con fuente.

### Descartadas (para no reabrirlas sin datos nuevos)
- **Tempo ofensivo +7 / regen +3** (2026-10-26): no llegaba al objetivo de goles y quedó obsoleto con
  PA + Estamina; el stash se borró.
- **Dificultad base +7 pts** como palanca de goles (2026-10-26): ver D-12.
