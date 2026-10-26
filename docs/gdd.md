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

### 2.1 Momentos Clave [DECIDIDO] · largo por arquetipo [EN PRUEBA]
El partido no se juega minuto a minuto: cada equipo tiene **4 Momentos Clave** (LOW 3; HIGH puede
sumar extras) repartidos en los 90'. Cada Momento pide **3 jugadas exitosas terminando en un
remate**; 2 fallos lo pierden. Tras un contragolpe o con espacio rival bastan 2.
- **Pendiente M1:** el diseño original quería largo por arquetipo (Tiki-Taka 3-4 pases, Directo
  1-2, Contragolpe 2, Catenaccio 1). Hoy es fijo en 3 (D-12). Decidir si se vuelve a esa idea.

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

### 3.1 Mazo unificado [DECIDIDO]
18-20 cartas: cartas del DT (`data/cards.json`) + cartas firma de los titulares
(`data/signature_cards.json`). Reglas de liga: máx. 6 extranjeros, mín. 2 Sub-21.

### 3.2 Cartas del DT [EN PRUEBA]
Ataque: Pase corto, Promesa: Control (canterano), Desmarque, Pase al pie, Pausa, Pase filtrado,
Amague, Centro al área, Tiro de lejos, Chilena, Remate de primera. Defensa: Presión, Bloqueo,
Intercepción, Despeje.

### 3.3 Cartas firma [EN PRUEBA]
Propias de una figura (Zapatazo de Suazo, Arremetida de Alcázar, Sangre fría de Aróstegui) o la
genérica "Sello de [figura]". Estilos por tag: potencia (el bloqueo cuenta la mitad), sangre fría
(+10 con el Momento a un fallo de perderse), física.

### 3.4 Construcción del mazo — el corazón del deckbuilder [IDEA] · prioridad M2
Hoy el mazo **se arma solo**: el jugador no elige, quita ni mejora cartas. Es la mayor brecha con
el género. Diseño original: el 60% del mazo son cartas tácticas que **generan los entrenamientos de
la semana**, el 40% cartas privadas de los titulares. Falta definir: cómo se ganan cartas, cómo se
quitan, cómo se mejoran y qué límites hay. Ver `ideas.md` (I-01 a I-04).

### 3.5 Perfiles de DT [IDEA] · M2
- Posesión: mazo 20-22, mano de 6.
- Directo: mazo 12-15, mano de 4.
- Catenaccio: mazo 16, un casillero fijo de defensa/enfriamiento.
- Kamikaze: mazo 18, Descarte Agresivo (descartar 2 para +25% en la jugada).

### 3.6 Canteranos y progresión [IDEA] · M2
Cualquier jugador (también Sub-21) mejora con entrenamientos y puede desbloquear su propia carta
privada. Hoy las cartas "canterano" solo se asignan a un Sub-21 del plantel.

## 4. Arquetipos (IA y estilos) [DECIDIDO] · números [EN PRUEBA]
Cinco perfiles (`BotProfile`) que mueven la IA y algunas reglas (clubes según
`teams_chile_2006.json`, que difiere en algunos ejemplos del GDD original):
- **Tiki-Taka** (Colo-Colo, Audax, Huachipato): posesión, Flow, jugadas largas.
- **Directo** (Cobreloa, Everton, U. de Concepción): remate rápido.
- **Catenaccio** (Palestino, Wanderers, Coquimbo): bloque bajo, poco desgaste; hoy es el que menos marca.
- **Kamikaze** (O'Higgins, La Serena, Rangers): +20% en los Momentos 1-2, fatiga doble después.
  El diseño dice lesiones "hasta 15%"; hoy mide ~22% (revisar en M1).
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
