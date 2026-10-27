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

## 3. Cartas y mazo

### 3.1 Mazo unificado [DECIDIDO] · tamaño EN DISEÑO (ver 3.5)
Hoy 18-20 cartas: cartas del DT (`data/cards.json`) + cartas firma de los titulares
(`data/signature_cards.json`). Reglas de liga: máx. 6 extranjeros, mín. 2 Sub-21.

### 3.2 Cartas del DT [EN PRUEBA]
Ataque: Pase corto, Promesa: Control (canterano), Desmarque, Pase al pie, Pausa, Pase filtrado,
Amague, Centro al área, Tiro de lejos, Chilena, Remate de primera. Defensa: Presión, Bloqueo,
Intercepción, Despeje.

### 3.3 Cartas firma [EN PRUEBA]
Propias de una figura (Zapatazo de Suazo, Arremetida de Alcázar, Sangre fría de Aróstegui) o la
genérica "Sello de [figura]". Estilos por tag: potencia (el bloqueo cuenta la mitad), sangre fría
(+10 con el Momento a un fallo de perderse), física.

### 3.4 Construcción del mazo — el corazón del deckbuilder [DECIDIDO] · se implementa en M2
Decidido el 2026-10-27 (D-20 a D-22):
- **Bloque 2 = la decisión del mazo.** Eliges UNA: **entrenamiento táctico** (te ofrecen 3 cartas de
  tu estilo y eliges 1; si el mazo está en su tope, reemplaza a otra), **sesión de video** (mejoras
  una carta: +10 pts o −1 PA) o **kinesiología** (−25 de fatiga). Crecer compite con descansar.
- **Los rivales también crecen** con cartas de su arquetipo, una por semana (paridad).
- Fichajes, ojeo y canteranos serán otra fuente de cartas (M3).

Datos (`tests/lab/m2_cartas.json`, `m2_estandar.json`): con un mazo de 20, una carta mueve ~±0.04-0.11
goles por partido; con uno de 13, el doble. La mano pesa más que una carta (mano 7: +0.18; mano 5: −0.23).

### 3.5 Mazo inicial estándar y carta de rasgo del DT [EN DISEÑO] · M2
Idea del usuario (2026-10-27): como en Slay the Spire, todos empiezan con un **mazo estándar de
cartas básicas** (ataque básico, defensa básica) más **una carta de acción con el rasgo del DT**, y
el mazo crece con las elecciones. Reemplaza los "perfiles de DT con mazos de 12-22" del GDD original.
Preguntas abiertas:
1. **Las básicas tienen que ser débiles a propósito.** Una aproximación con cartas que ya existen
   (13 cartas sin Chilena, Intercepción ni Despeje) dio **2.94 goles** (sube, porque son cartas
   buenas y hay menos cortes) y mucho cansancio (78% en el 2T). Con mano de 5, 2.51. Hay que diseñar
   cartas básicas nuevas y calibrarlas.
2. **Tamaño inicial y tope:** ¿~10-13 al empezar y hasta ~20? Hoy la regla es 18-20 (`DeckManager`).
3. **Carta de rasgo:** ¿una por arquetipo (5 cartas) o una por DT real (32, más nostalgia)? Se
   puede empezar por arquetipo y sumar las de DT famosos después.
4. **Firmas de los titulares:** ¿entran al mazo inicial o se ganan durante la carrera?
5. **Reglas de liga** (máx. 6 extranjeros, mín. 2 Sub-21 en el mazo): ¿cómo conviven con un mazo chico?

Borrador para discutir (no decidido):
- **Básicas:** Pase corto ×4-5 (ataque, 0 PA), Remate simple ×2 (1 PA, acierto bajo), Marca ×3
  (defensa, efecto chico).
- **Rasgo por arquetipo:** Tiki-Taka "Toque-toque" (pase que, si sale, roba una carta: premia la
  jugada larga, ver I-09); Directo "Pelotazo" (cuenta como 2 pasos, acierto bajo); Catenaccio
  "Cerrojo" (defensa que bloquea y abarata tu próximo ataque); Kamikaze "Presión total" (presión fuerte
  que gasta mucha estamina); Contragolpe "Salida rápida" (tras cortar, tu Momento parte avanzado).
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
2. **Preparación:** entrenamiento táctico (+3 de forma, +10 de fatiga) o kinesiología (−25 de fatiga).
3. **El partido** (`match_view`), previa validación del mazo.

### 5.2 Reputación y funas [DECIDIDO] · contenido [EN PRUEBA]
Doble eje Popularidad (hinchada) vs Disciplina (directiva/sponsors). Hoy hay un evento
("Bautizazo en Bellavista"): da forma en los primeros Momentos y popularidad, con 30% de riesgo de
funa (−disciplina, +50% de desgaste en las cartas del funado, puede costar la semana de sponsor).
Faltan más eventos (conferencia polémica, charla técnica, agentes): `ideas.md`.

### 5.3 Fatiga entre partidos [DECIDIDO]
La estamina gastada deja fatiga (6 + 18 × desgaste), que define con cuánta estamina arrancas el
siguiente partido.

### 5.4 Temporada · guardado [DECIDIDO] · fixture y tabla [IDEA] · prioridad M3
Fixture completo del Apertura 2006, tabla de posiciones y fin del torneo. Hoy la carrera es una
sucesión de semanas sin tabla.

**Guardado (T-01):** una sola ranura, automática: se guarda tras cada acción de bloque, al ir al
partido y al volver al calendario. "Continuar carrera" retoma la misma semana con el mismo estado,
incluido el azar (los eventos siguen saliendo igual). No se guarda a mitad de partido: si el juego se
cierra durante el partido, se vuelve al Bloque 3 y ese partido se juega desde el principio
(pendiente: ¿contarlo como derrota provisional para que no se pueda repetir?).

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

## 7. Presentación [IDEA] · M4
Hoy: UI de prototipo, cancha dibujada por código, sin arte ni audio. Pendiente: dirección de arte
sostenible para un desarrollador solo (propuesta: transmisión de TV 2006 + cartas como láminas de
álbum, I-30), sonido, menú principal, tutorial.

## 8. Comercial [IDEA] · antes de M4
Steam PC primero, página temprana para wishlists, demo en itch.io. Riesgo principal: licencias de
nombres reales (I-20).
