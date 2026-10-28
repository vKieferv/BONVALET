# GDD vivo · Futbolista Deckbuilder 2006

Documento de diseño único. Reemplaza al GDD pegado en el chat y a `pizarra.html` (fuera del repo).
Cada sección lleva su estado:

- **[DECIDIDO]** implementado o cerrado; cambiarlo requiere una entrada en `decisiones.md`.
- **[EN PRUEBA]** implementado pero sin validar con playtests, o con números provisorios.
- **[IDEA]** diseñado en papel, sin código. Se detalla en `ideas.md` antes de implementarlo.

Los números exactos viven en el código (cabecera de `core/match_engine.gd`, `data/*.json`); aquí va
la intención. Arquitectura y comandos: `CLAUDE.md`. Filtro de ideas: `pilares.md`.

---

## 1. Visión [DECIDIDO]
Deckbuilder táctico de fútbol al estilo Slay the Spire con gestión "modo carrera" arcade, en el
Torneo Nacional chileno 2006 (Apertura / Clausura). Eres el DT de un club de Primera A o B:
juegas los partidos con cartas (transmisión estilo TV) y gestionas la semana entre partidos
(sponsors, eventos, prensa, funas, entrenamiento, infraestructura).

- Plataforma objetivo: PC (Steam). Motor: Godot 4.7.2, GDScript, datos en JSON.
- Público: fans de deckbuilders (mecánica) + hinchas nostálgicos de la liga chilena (gancho).

## 2. El partido

### 2.1 Momentos Clave [DECIDIDO]
El partido no se juega minuto a minuto: cada equipo tiene **4 Momentos Clave** (LOW 3; HIGH puede
sumar extras) repartidos en los 90'. Cada Momento pide **3 jugadas exitosas terminando en un
remate**, salvo los de **Catenaccio, que piden 2** (su jugada ultra corta; vale también si tú
diriges un club Catenaccio). 2 fallos lo pierden. Tras un contragolpe o con espacio rival bastan 2
(un Momento de 2 no se acorta más). Ver D-12 y D-16.
- El largo del diseño original por arquetipo (Tiki-Taka 3-4, Directo 1-2, Contragolpe 2) se
  descartó en M1 (D-16): hundía a Tiki-Taka. Tiki-Taka 3-4 queda en I-09, atado a una mecánica
  que premie el pase largo.

### 2.2 Puntos de Acción y Estamina Global [DECIDIDO]
- **PA por turno:** LOW 3 / NORMAL 3 / HIGH 4; 2 en cada fase defensiva. No se acumulan.
- **Costos:** básicas 0-1 (pase corto, desmarque, canteranos gratis), tácticas 1, remates
  estándar 2, firmas con nombre propio 3, defensivas 1-2.
- **Estamina Global:** cada carta la desgasta (más en HIGH, menos en LOW, +50% si el jugador está
  funado). Se recupera entre Momentos según la postura. **Nunca baja el % de acierto**: sus zonas
  ÓPTIMO / CANSADO / AGOTADO solo achican la mano (−0/−1/−2), suben el riesgo de lesión y meten
  cartas de penalización.
- **Lesión:** solo al jugar agotado; termina tu partido.
- El robo es solo al iniciar el Momento.

### 2.3 Posturas [DECIDIDO]
LOW (aguantar, menos desgaste, −15 en remates, tope de Momentos), NORMAL, HIGH (más PA y
Momentos extra, desgaste ×1.5, recupera poco). Se fija entre Momentos, no durante la jugada.
Los clubes grandes castigan tu LOW (contragolpe: remates más baratos y Momento más corto).

### 2.4 Flow [DECIDIDO]
Rachas de jugadas exitosas activan Flow: la carta se queda en la mano y cada reuso cuesta +1 PA.
Romper el Flow cuesta 15% de estamina (salvo al Aguantar el Balón).

### 2.5 Ejecutor Natural [DECIDIDO]
Si la carta la juega su dueño (titular en cancha): +15 de acierto, doble carga de Flow y resplandor.
En el modelo de duelos (I-45) el bono baja a +5 de prueba (D-32).

### 2.6 Aguantar el Balón [EN PRUEBA]
Botón fijo junto a "Ceder Jugada", una vez por Momento: 1 PA (0 si no quedan, y si sale bien
da +1 PA), 3 de estamina, 80% menos la Presión rival. Éxito: mano nueva y Flow cortado sin
penalización. Fallo: el rival roba y contragolpea. Ver D-09, D-10.

### 2.7 Defensa y posesión [DECIDIDO]
Antes de cada ataque rival robas una mano defensiva (Presión, Bloqueo, Intercepción, Despeje) con
2 PA, o usas el **Despeje de Emergencia** (botón fuera del mazo: todos los PA + 15% de estamina).
Intercepción y Despeje cortan el ataque; Presión y Bloqueo lo encarecen. El rival hace lo mismo
contra ti según su estilo.

### 2.8 Transparencia [DECIDIDO]
El % de cada carta es el que se tira, con desglose en el tooltip (pilar 2).

### 2.9 Duelos por línea [IDEA · I-45] · M2/M3
Cada jugada del Momento cruza una línea del rival y enfrenta a uno de sus jugadores: la carta usa un
atributo de tu jugador contra el de él (como los enemigos de Slay the Spire). La formación del estilo
define cuántos hay en cada línea (superioridad numérica, I-44) y el nivel de tu DT, cuánto ves antes
(I-41, I-46). Decidido en papel: habilidades (D-29), cinco formaciones, una por estilo (D-30), y las
reglas de los duelos (D-31: fallar no corta el Momento, eliges a quién pasar, cansancio por jugador),
y sus ajustes (D-32: fórmula más corta, Ejecutor Natural +5, robo según la línea, el cansancio quita PA).
Borrador y ejemplos (M14 contra Kalule, un Momento contra Palestino) y maqueta de la pantalla: `cartas.md`.

## 3. Cartas y mazo
Catálogo por familia, nombres, variantes y jugadas anotadas: `cartas.md` (bloc de trabajo).
**Complejidad progresiva [DECIDIDO · D-28]:** se empieza con cartas básicas (verbo y %, sin texto); las
cartas con más texto se desbloquean jugando, con el nivel del DT (I-46).

### 3.1 Mazo unificado [DECIDIDO] · tamaño EN PRUEBA (ver 3.5)
10-20 cartas (`DeckManager`): cartas del DT (catálogo en `data/cards.json`, mazos en `data/decks.json`)
+ cartas firma de los titulares (`data/signature_cards.json`). Se arranca con 12 (3.5). Reglas de
liga: máx. 6 extranjeros, mín. 2 Sub-21.

### 3.2 Cartas del DT [EN PRUEBA]
Ataque: Pase corto, Promesa: Control (canterano), Desmarque, Pase al pie, Pausa, Pase filtrado,
Amague, Centro al área, Tiro de lejos, Chilena, Remate de primera. Defensa: Presión, Bloqueo,
Intercepción, Despeje.

### 3.3 Cartas firma [EN PRUEBA]
Propias de una figura (Zapatazo de Suazo, Arremetida de Alcázar, Sangre fría de Aróstegui) o la
genérica "Sello de [figura]". Estilos por tag: potencia (el bloqueo cuenta la mitad), sangre fría
(+10 con el Momento a un fallo de perderse), física.

### 3.4 Construcción del mazo — el corazón del deckbuilder [DECIDIDO] · tu mazo en el juego desde T-05; los rivales, T-06
Decidido el 2026-10-27 (D-20 a D-22):
- **Bloque 2 = la decisión del mazo.** Eliges UNA: **entrenamiento táctico** (te ofrecen 3 cartas de
  tu estilo y eliges 1; si el mazo está en su tope, reemplaza a otra), **sesión de video** (mejoras
  una carta: +10 pts o −1 PA) o **kinesiología** (−25 de fatiga). Crecer compite con descansar.
- **Los rivales también crecen** con cartas de su arquetipo, una por semana (paridad).
- Fichajes, ojeo y canteranos serán otra fuente de cartas (M3).

**Cómo quedó en el juego (T-05; los números son iniciales):**
- **Tu mazo es tuyo:** arranca con el mazo de inicio de tu club (3.5) y se guarda con la carrera.
- **Táctico (fatiga +10):** la oferta son 3 cartas distintas, 2 de la lista de tu estilo y 1 de una
  lista general (`data/decks.json` `"ofertas"`; hoy la de cada estilo = su `crecimiento`), nunca la
  carta de rasgo; puede salir una carta que ya tienes (segunda copia). Se sortea al empezar la semana
  con el azar de la carrera y se guarda: recargar no la cambia. Puedes no tomar ninguna. Con el mazo
  en 20, eliges cuál de tus cartas del DT sale; no se acepta un reemplazo que deje el mazo fuera de
  las reglas de liga (sacar una Promesa te dejaría con 1 Sub-21 y la carrera quedaría trabada). Ya no
  da +3% de forma (D-21).
- **Video (sin fatiga):** +10 de acierto o −1 PA (solo cartas de 1 PA o más), una mejora por carta;
  la carta mejorada lleva "+" en el nombre ("Remate simple+"). Las firmas de los titulares no se
  mejoran ni se sacan: no son del DT.
- **Kinesiología:** −25 de fatiga, como antes.
- Cada opción es final para la semana; "Ver mazo" muestra el mazo completo con sus mejoras.

Datos (`tests/lab/m2_cartas.json`, `m2_estandar.json`): con un mazo de 20, una carta mueve ~±0.04-0.11
goles por partido; con uno de 13, el doble. La mano pesa más que una carta (mano 7: +0.18; mano 5: −0.23).

### 3.5 Mazo inicial estándar y carta de rasgo del DT [EN PRUEBA · D-23] · en el juego desde T-04; crece con T-05 y T-06
Idea del usuario (2026-10-27): como en Slay the Spire, todos empiezan con un **mazo estándar de
cartas básicas** más **una carta de acción con el rasgo del DT**, y el mazo crece con las elecciones.
Reemplaza los "perfiles de DT con mazos de 12-22" del GDD original. Aprobada el 2026-10-27 (D-23)
tras medirla con `balance-lab` (`tests/lab/m2_propuesta.json`; cada rasgo por separado en
`m2_rasgos_2.json`). Los números son iniciales: se ajustan con playtests.

**Mazo estándar (11 cartas del DT + la firma de la figura = 12):**
| Carta | Copias | Qué es |
|---|---|---|
| Pase corto | 4 | ataque básico, 0 PA |
| Promesa: Control | 2 | ataque básico de un canterano (cumple la regla de 2 Sub-21) |
| **Remate simple** (nueva) | 1 | remate barato y poco certero: 1 PA, +10 |
| **Marca** (nueva) | 2 | defensa básica: presión chica, 1 PA, +4 |
| Despeje | 1 | la única carta que corta un ataque al empezar |
| Carta de rasgo | 1 | según el arquetipo del DT |

**Cartas de rasgo (por arquetipo; las de DT famosos, después):**
| Arquetipo | Carta | Efecto | Medido (goles por partido de ese club) |
|---|---|---|---|
| Tiki-Taka | **Toque-toque** | pase de 0 PA, +20; si sale bien robas una carta | +0.07 a +0.10 (sube a medida que el mazo crece) |
| Directo | **Pelotazo** | balonazo de 1 PA, +0; si sale bien cuenta como 2 avances | +0.11 a +0.14 |
| Catenaccio | **Cerrojo** | despeje barato: corta el ataque, 1 PA, +0 | neutro (identidad: "cancela la iniciativa rival") |
| Kamikaze | **Remate en carrera** | remate de 1 PA, +25, desgaste muy alto (10) | +0.14 a favor y +0.12 en contra: partidos locos |
| Contragolpe | **Anticipo** | intercepción de 1 PA: corta y deja listo el contragolpe | +0.09 a favor, defensa igual |

**Resultados (matriz neutral de `godot-check -Balance`, 400 partidos por cruce; medición oficial de
T-04 con el crecimiento de `data/decks.json`, que alterna ataque y defensa):**
| Momento de la temporada | Goles | Lesiones | Cansancio 1T/2T | Constructibilidad (por club, `balance-lab`) |
|---|---|---|---|---|
| Inicio (12 cartas) | **2.47** | 2.8% | 16% / 49% | 91-99% (Colo-Colo en `sim.gd`: 92%) |
| Mitad (+4 cartas de su estilo) | 2.73 | 3.2% | 17% / 53% | 93-100% |
| Final (+8 cartas) | 2.65 | 3.5% | 16% / 53% | 93-99% |

La propuesta medida antes en `m2_propuesta.json` (otras listas de crecimiento, primero las de ataque)
daba 2.71 y 2.61 a mitad y final, con constructibilidad de 80% para Tiki-Taka al final.

**Lo que se aprendió midiendo (para no repetir experimentos):**
- **Sin un Despeje en el mazo estándar no hay cortes:** cada equipo ataca ~3.9 veces por partido en
  vez de ~2.9 y los goles suben a ~3.0, aunque las básicas sean débiles (los goles por Momento
  incluso bajan). Con un Despeje: 2.35 sin rasgos.
- **En un mazo chico la defensa es frágil:** con 3 cartas defensivas y mano defensiva de 3, el
  Despeje sale siempre; una cuarta carta defensiva lo diluye. Por eso un rasgo defensivo tiene que
  **cortar él mismo** (Cerrojo, Anticipo) o ser de ataque: los rasgos de Presión/Bloqueo reforzados
  (Cerrojo ×2 de bloqueo, Presión total, Salida rápida) empeoraban la defensa de su propio club.
- **Robar cartas vale poco con mazo chico** (casi siempre ya hay plan de gol): Toque-toque gana
  valor cuando el mazo crece. El bot lo subestima; con una persona debería rendir más.
- Con 2 Remates simples en vez de 1: inicio 2.51 y constructibilidad 99-100% (demasiado parejo).

Preguntas abiertas (cada una con la tarea que la resuelve):
1. **La curva de la temporada queda sobre el rango** (2.73 a mitad y 2.65 al final; medido en T-04):
   alternar ataque y defensa en el crecimiento no la bajó (la propuesta daba 2.71 / 2.61). Decidir con
   el usuario: aceptar la curva (los mazos mejoran y se ataca mejor), bajar el inicio o un ajuste global.
   En la carrera, tu mazo ya crece (T-05, a tu ritmo: una carta por semana si eliges el táctico); los
   rivales todavía no (T-06).
2. **Constructibilidad de Tiki-Taka al final:** con las listas de `decks.json` queda en 93% (era 80%
   con las de la propuesta). Lo que ofrece el entrenamiento a cada estilo quedó, para empezar, igual a
   su crecimiento + una lista general (T-05, 3.4); se revisa con playtests.
3. **Tamaño — resuelta (T-04):** `DeckManager` admite 10-20 cartas; se empieza en 12 y
   `season_templates` no deja que el crecimiento pase de 20 con las firmas.
4. **Firmas de los titulares:** entran al mazo inicial (una por club). Los 12 clubes de Primera B sin
   figura no tienen firma y arrancan con 11 cartas con el Remate simple como único remate: una matriz
   de 5 de ellos da 1.57 goles al inicio (2.49 con +8) y su Catenaccio (Curicó) hace 0.30 goles, porque
   su bot solo remata desde 40% y el Remate simple ronda el 35%. Abierta: firma genérica para todos,
   otro remate en su mazo o aceptar una Primera B más cerrada.
5. **Reglas de liga:** las 2 Promesas cubren los Sub-21; los extranjeros no son problema con 12 cartas
   (`career_rules` lo comprueba en los 32 clubes, también con +8).
6. **Motor y datos:** los efectos `steps` y `draw` los usan Pelotazo y Toque-toque, y la carta muestra
   su efecto (`CardUI`); `effect` y `counter` siguen sin uso en los datos del juego.
### 3.6 Canteranos y progresión [IDEA] · M2
Cualquier jugador (también Sub-21) mejora con entrenamientos y puede desbloquear su propia carta
privada. Hoy las cartas "canterano" solo se asignan a un Sub-21 del plantel.

## 4. Arquetipos (IA y estilos) [DECIDIDO] · números [EN PRUEBA]
Cinco perfiles (`BotProfile`) que mueven la IA y algunas reglas (clubes según
`teams_chile_2006.json`, que difiere en algunos ejemplos del GDD original):
- **Tiki-Taka** (Colo-Colo, Audax, Huachipato): posesión, Flow, jugadas largas.
- **Directo** (Cobreloa, Everton, U. de Concepción): remate rápido.
- **Catenaccio** (Palestino, Wanderers, Coquimbo): bloque bajo, poco desgaste, Momentos de 2
  jugadas (D-16; Palestino ~1.1 goles por partido en la matriz).
- **Kamikaze** (O'Higgins, La Serena, Rangers): +20% en los Momentos 1-2, fatiga doble después.
  Lesión tardía ×2.5 (D-17): La Serena se lesiona en ~15% de sus partidos, el "hasta 15%" del diseño.
- **Contragolpe** (U. de Chile, UC, U. Española): castiga tu LOW; su Intercepción corta ~1.4
  ataques por partido.

La IA en ataque planifica combinaciones de su mano y en defensa elige según su estilo.

## 5. La semana (modo carrera)

### 5.1 Bucle de 3 bloques [DECIDIDO]
1. **Planificación y prensa:** sponsor (Cerveza Glaciar o Telnet) y evento social.
2. **Preparación (la decisión del mazo, D-21):** UNA entre entrenamiento táctico (1 de 3 cartas nuevas,
   +10 de fatiga), sesión de video (mejorar una carta, sin fatiga) o kinesiología (−25 de fatiga).
   Detalle en 3.4. Desde T-05 tu mazo se guarda con la carrera.
3. **El partido** (`match_view`), previa validación del mazo.

### 5.2 Reputación y funas [DECIDIDO] · contenido [EN PRUEBA]
Doble eje Popularidad (hinchada) vs Disciplina (directiva/sponsors). Hoy hay un evento
("Bautizazo en Bellavista"): da forma en los primeros Momentos y popularidad, con 30% de riesgo de
funa (−disciplina, +50% de desgaste en las cartas del funado, puede costar la semana de sponsor).
Faltan más eventos (conferencia polémica, charla técnica, agentes): `ideas.md`.

### 5.3 Fatiga entre partidos [DECIDIDO]
La estamina gastada deja fatiga (6 + 18 × desgaste), que define con cuánta estamina arrancas el
siguiente partido.

### 5.4 Temporada [DECIDIDO · D-24, D-25] · se implementa en M3 · guardado [DECIDIDO]
Apertura y Clausura fieles a 2006: 19 clubes, una vuelta de 19 fechas (cada club tiene una fecha
libre), 4 grupos para clasificar, repechaje, cuartos, semis y final a ida y vuelta, y descenso por tabla
acumulada como en 2006 (D-33): el último baja directo y el 17.º y el 18.º juegan liguilla contra el
3.º y el 4.º de Primera B. El calendario es el real de 2006; los demás partidos
de la fecha se simulan con los bots. La realidad se muestra como comparación (I-36). Datos históricos:
`data/history_2006.json` (T-07: calendario, resultados, tablas y playoffs reales de es.wikipedia y RSSSF),
validado por `tests/data_rules.gd`; ojo, el descenso real de 2006 no fue el de arriba (el 17.º y el 18.º
fueron a liguilla, ver su `review`). Hoy la carrera es una sucesión de semanas contra una lista fija de
rivales, sin tabla ni final.

**Guardado (T-01):** una sola ranura, automática: se guarda tras cada acción de bloque, al ir al
partido y al volver al calendario. "Continuar carrera" retoma la misma semana con el mismo estado,
incluido el azar (los eventos siguen saliendo igual). No se guarda a mitad de partido: si el juego se
cierra durante el partido, se vuelve al Bloque 3 y ese partido se juega desde el principio (D-19).

### 5.5 Economía, fichajes, ojeo, infraestructura [IDEA] · M3+
Presupuesto y masa salarial existen en los datos pero casi no se usan. Diseño: ojeo por niveles,
agentes que ofrecen jugadores en eventos, clubes grandes que invierten en estadio y cracks, clubes
chicos que invierten en gimnasio y centro médico para bajar fatiga y lesiones.

## 6. Datos y contenido [DECIDIDO]
- 32 clubes de 2006 con DT, arquetipo, estadio, colores, presupuesto, instalaciones y figura.
- Planteles reales de Colo-Colo, U. de Chile y UC (Wikidata); el resto generados con nombres
  ficticios de forma determinista.
- Todo en JSON: otra liga u otra época = otro conjunto de datos.
- Marcas siempre parodiadas (D-01); datos históricos solo con fuente (D-02).

## 7. Presentación [DECIDIDO: D-35 y D-37] · semana en T-09, partido en T-11
Dirección (D-35): transmisión de TV 2006 + cartas como láminas de álbum, jugadores sin caras, escudos
generados con los colores del club. Concepto (D-37, maqueta v3 del lienzo "Dirección visual"): la semana
es la mesa del DT (objetos con su material, timbres de tinta y plumón, una acción a la vez con
chinchetas numeradas y la luz de la lámpara) y el partido es la señal de TV (cámara en perspectiva,
telestrador, gráficas de 2006), con las láminas en la mano. Íconos propios y palabras clave en vez de
oraciones; texto de juego de 14 px o más. Hoy: UI de prototipo, cancha dibujada por código, sin audio.
Pendiente: sonido, menú principal, tutorial.

## 8. Comercial [IDEA] · antes de M4
Steam PC primero, página temprana para wishlists, demo en itch.io. Riesgo principal: licencias de
nombres reales (I-20).
