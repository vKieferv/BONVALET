# Bloc de cartas

Borrador de trabajo (2026-10-27) para ir anotando nombres, variantes y jugadas. Lo que se decida aquí
pasa al GDD (sección 3) y a los JSON; las ideas con efecto nuevo van primero a `ideas.md`.

## Reglas del bloc (propuesta, por revisar)
- **Familia** = lo que la carta hace: clase, PA, desgaste, bono y efectos. Los números se escriben una
  sola vez, en la familia.
- **Variante** = otro nombre para una familia, con exactamente los mismos números. No mueve el balance:
  no hace falta medirla.
- Si cambia cualquier número, ya no es variante: es una carta nueva (`idea-nueva` + `balance-lab`).
- Las copias de una carta dentro de un mazo se llaman igual. Las variantes dan identidad: de qué
  jugador, DT o club es la carta.
- En pantalla, bajo el nombre, la carta muestra su familia ("Bombazo · Remate de primera"), para que el
  jugador aprenda las familias y no cada nombre (pilar 2).

## Idioma de las cartas: un verbo por tipo (aceptado como dirección, 2026-10-27, I-43)
Hoy pase, control, regate y centro son la misma regla con otro bono. La dirección es que cada tipo
tenga su verbo, y que toda carta nueva se arme con uno de ellos más el toque de su estilo. Todavía sin
código: cambiar estas reglas mueve el balance y se mide con `balance-lab`.

| Tipo | Verbo | Ejemplo de uso |
|---|---|---|
| Pase | avanza la jugada (la base) | Pase corto |
| Control | prepara: en ataque, la siguiente jugada +X; desde la defensa es la **Transición** | Bajarla de pecho |
| Regate | ignora la Presión rival | Amague |
| Centro | el próximo remate +X | Centro al área |
| Remate | cierra el Momento | Remate de primera |
| Presión | encarece todas sus jugadas | Marca, Presión |
| Bloqueo | encarece su remate | Bloqueo |
| Intercepción | corta y deja el contragolpe | Intercepción, Anticipo |
| Despeje | corta | Despeje, Cerrojo |
| Transición | no frena, prepara tu próximo Momento | Salida limpia |

Nombres de las cartas de T-04 confirmados tal como están en el brief (2026-10-27).

## Catálogo actual por familia
Estado: **estándar** = mazo inicial de todos (D-23) · **rasgo** = carta de rasgo de un arquetipo (D-23)
· **catálogo** = se gana en el entrenamiento (D-20) · **firma** = de un jugador · **T-04** = definida,
todavía no está en el juego.

### Ataque · armar la jugada
| Carta | Qué hace | PA | Desgaste | Bono | Estado | Otros nombres |
|---|---|---|---|---|---|---|
| Pase corto | pase básico | 0 | 2 | +6 | estándar ×4 | |
| Promesa: Control | control de un canterano (Sub-21) | 0 | 1 | +5 | estándar ×2 | |
| Desmarque | movimiento sin balón, física | 0 | 4 | +7 | catálogo | |
| Pase al pie | pase seguro | 1 | 2 | +8 | catálogo | |
| Pausa | si sale, recupera 10% de estamina (1 por Momento) | 1 | 0 | +25 | catálogo | |
| Pase filtrado | pase entre líneas | 1 | 4 | +20 | catálogo | |
| Amague | regate, física | 1 | 4 | +18 | catálogo | |
| Centro al área | centro | 1 | 4 | +22 | catálogo | |
| Toque-toque | si sale, robas 1 carta | 0 | 2 | +20 | rasgo Tiki-Taka · T-04 | |
| Pelotazo | si sale, cuenta como 2 avances | 1 | 3 | +0 | rasgo Directo · T-04 | |

### Ataque · rematar
| Carta | Qué hace | PA | Desgaste | Bono | Estado | Otros nombres |
|---|---|---|---|---|---|---|
| Remate simple | remate barato y poco certero | 1 | 4 | +10 | estándar ×1 · T-04 | |
| Tiro de lejos | remate barato | 1 | 4 | +18 | catálogo | |
| Remate en carrera | remate barato con mucho desgaste, física | 1 | 10 | +25 | rasgo Kamikaze · T-04 | |
| Remate de primera | remate estándar | 2 | 6 | +40 | catálogo | |
| Chilena | remate acrobático, física, extranjero | 3 | 8 | +45 | catálogo | |
| Sello de [figura] | firma genérica de la figura del club | 2 | 6 | +36 | firma | |
| Zapatazo | firma de Suazo | 3 | 6 | +38 | firma | |
| Arremetida | firma de Alcázar: física, el bloqueo cuenta la mitad | 3 | 8 | +40 | firma | |
| Sangre fría | firma de Aróstegui: +10 a un fallo de perder el Momento | 2 | 4 | +30 | firma | |

### Defensa
| Carta | Qué hace | PA | Desgaste | Bono | Estado | Otros nombres |
|---|---|---|---|---|---|---|
| Marca | presión chica | 1 | 2 | +4 | estándar ×2 · T-04 | |
| Presión | encarece el ataque rival, física | 1 | 4 | +6 | catálogo | |
| Bloqueo | encarece el remate rival | 1 | 2 | +8 | catálogo | |
| Despeje | corta el ataque | 2 | 2 | +12 | estándar ×1 | |
| Cerrojo | despeje barato: corta el ataque | 1 | 2 | +0 | rasgo Catenaccio · T-04 | |
| Intercepción | corta el ataque y deja el contragolpe | 2 | 4 | +0 | catálogo | |
| Anticipo | intercepción barata | 1 | 4 | +0 | rasgo Contragolpe · T-04 | |

### Fuera del mazo (botones)
Aguantar el Balón, Ceder Jugada y Despeje de Emergencia. No son cartas: no llevan variantes.

## Variantes de nombre (en revisión)
| Nombre | Familia | De quién | Estado |
|---|---|---|---|

_Sin entradas todavía._

## Habilidades de los jugadores (aprobadas, D-29; paso 2 de I-45)
Principios: pocas, para que quepan en una lámina de álbum (I-30); cada habilidad tiene su rival en el
duelo; salen de lo que ya tenemos (nivel y puesto) más un perfil de diseño para los que destacan, sin
copiar puntajes de otros juegos (D-27); básico primero (D-28).

**Cinco de campo + Atajada, y el Físico que ya existe:**
| Habilidad | Qué mide | Tus cartas que la usan | En el duelo, contra |
|---|---|---|---|
| **Pase** | poner el balón donde va | Pase corto, Pase al pie, Pase filtrado, Centro, Toque-toque | Lectura |
| **Regate** | ganar el uno contra uno, técnica con balón | Amague, Desmarque, Promesa: Control | Quite |
| **Remate** | definir | todos los remates y las firmas | Atajada |
| **Quite** | quitar, presionar, poner el cuerpo | Presión, Marca, Bloqueo | Regate |
| **Lectura** | anticipar, cortar líneas de pase | Intercepción, Anticipo, Despeje, Cerrojo | Pase |
| **Atajada** | solo el arquero | ninguna: frena todos los remates del rival | Remate |
| **Físico** | ya existe (`stamina_max`), hoy sin uso en el partido | estamina y cartas físicas | — |

Para recordarlas: **el regate se mide con el quite, el pase con la lectura y el remate con la atajada.**
Cada defensa tiene dos números (Quite y Lectura): si uno es bajo, ese es su lado débil, como la
debilidad de un enemigo de Slay the Spire. El Pelotazo no pelea: se salta la línea.
Cuando el rival ataca es al revés: tu Quite y tu Lectura le bajan su % aunque no juegues carta (el
"escudo"); tus cartas de defensa suman encima.

**Por qué cinco:** con tres (Ataque, Defensa, Físico) no hay lado débil y M14 contra Kalule sería solo
"84 contra 72"; con ocho o más (velocidad, cabezazo, visión...) no caben en una lámina y hay que
asignarlas a ~340 jugadores (19 clubes × 18). Velocidad y Juego aéreo pueden llegar después (D-28).

**De dónde salen (D-32):** habilidad = nivel (`skill_rating`, la media) + ajuste del puesto + perfil
(+6), tope 95. Los ajustes positivos no pasan de +3, para que nadie se dispare (con +5 y +10, Alcázar
llegaba a 95 de Remate).
| Puesto | Pase | Regate | Remate | Quite | Lectura |
|---|---|---|---|---|---|
| DFC | −10 | −20 | −25 | +3 | +3 |
| LAT | −5 | −5 | −20 | 0 | −5 |
| MCD | 0 | −10 | −15 | +3 | +3 |
| MCO | +3 | 0 | −5 | −15 | −10 |
| EXT | −5 | +3 | −5 | −20 | −15 |
| DEL | −10 | 0 | +3 | −25 | −20 |
| POR | Atajada = nivel | | | | |

**Perfiles** (+6 a una habilidad): **solo la élite**, 1-2 por club. La mayoría no tiene perfil, y eso
es lo que separa a los buenos de la élite (usuario). Los asigna el diseño, como los estilos de las cartas
firma (juicio de diseño en datos reemplazables, D-26). Tipos: Gambeteador (Regate), Enganche (Pase),
Goleador (Remate), Perro de presa (Quite), Recuperador (Lectura), Atleta (Físico), Atajador (Atajada);
¿sacar uno? (candidato: Atleta, porque el Físico no pelea duelos). T-08 no cambia: entrega nivel y puesto.

**Láminas de ejemplo** (con la fórmula; perfiles puestos para el ejemplo):
| Jugador | Puesto · nivel | Perfil | Pase | Regate | Remate | Quite | Lectura |
|---|---|---|---|---|---|---|---|
| Matías Fernández (M14) | MCO 84 | Gambeteador | 87 | **90** | 79 | 69 | 74 |
| Rodrigo "Kalule" Meléndez | MCD 72 | — | 72 | 62 | 57 | 75 | 75 |
| Humberto Suazo | DEL 86 | Goleador | 76 | 86 | **95** | 61 | 66 |
| Claudio Bravo | POR 80 | Atajador | Atajada **86** | | | | |
| Un DFC generado | DFC 66 | — | 56 | 46 | 41 | 69 | 69 |

**El duelo en %:** % = 39 + carta + **0,5** × (tu habilidad − la suya). El 0,5 es el valor de prueba
(usuario). El 39 es lo de hoy (base 54 menos la defensa rival de 15): **a igual habilidad cada carta queda
con el % de hoy**, así no se pierde el balance medido. El desglose lo muestra como "Duelo: Regate 90
contra Quite 75 · +7,5" (pilar 2). Jugada 2, te toca Kalule (Quite 75, Lectura 75):
- M14 juega Amague: 39 + 18 + 7,5 = **65%**. A Kalule le queda 35%.
- Un jugador como el FF de tu ejemplo (Regate 65, Pase 70): Amague 39 + 18 − 5 = **52%**; Pase filtrado
  39 + 20 − 2,5 = **57%**; Pelotazo sin duelo **39%**, pero avanza 2 (una tirada en vez de dos).
- Contra un "Perro de presa" (Quite 85, Lectura 70) hasta M14 debería pasarla: Amague 60%, Pase
  filtrado 68%.

**Por decidir o medir:**
- Cuántos % vale cada punto de diferencia: **0,5 para las pruebas** (usuario). Con la fórmula de D-32,
  Suazo con Remate de primera contra un arquero de 80 queda en 87%. Se ajusta con `balance-lab`.
- Quién juega cada carta: ver "Formaciones".
- El Ejecutor Natural se mantiene, más chico: +5 de prueba (D-32; antes +15).
- Técnica (del equipo) desaparece: la reemplazan los duelos. Visión (mano), ritmo y concentración siguen
  siendo del equipo por ahora. El Físico podría dar la estamina del equipo (promedio de los titulares).
- Con el nivel del DT (I-46): con nivel bajo ves el nivel general del rival; con nivel alto, sus
  habilidades (su lado débil).

## Formaciones (D-30, asignación confirmada)
Decidido (usuario, 2026-10-27): cinco formaciones, una por estilo de DT. Más adelante se podrán mezclar
estilos (I-47). Las formaciones salen del estilo (diseño), no de la formación real de cada club en 2006.

| Formación | Estilo | Atrás · Medio · Arriba | Puestos | Identidad en los duelos |
|---|---|---|---|---|
| 5-3-2 | Catenaccio | 5 · 3 · 2 | 3 DFC, 2 LAT · 2 MCD, MCO · 2 DEL | definir contra ellos es lo más difícil; arriba nunca más de 3, aun en HIGH; sus Momentos de 2 se saltan el medio |
| 4-4-2 | Directo | 4 · 4 · 2 | 2 DFC, 2 LAT · 2 MCD, 2 EXT · 2 DEL | equilibrada; extremos para el centro y dos puntas para el pelotazo |
| 4-1-2-1-2 | Tiki-Taka | 4 · 4 · 2 | 2 DFC, 2 LAT · MCD, 2 volantes, MCO · 2 DEL | mismos números que el 4-4-2, pero todo por adentro: enganche detrás de los puntas (M14 en Colo-Colo), sin extremos |
| 4-3-3 | Contragolpe | 4 · 3 · 3 | 2 DFC, 2 LAT · MCD, 2 volantes · 2 EXT, DEL | tres arriba que esperan la contra y presionan tu salida; medio más corto |
| 3-5-2 | Kamikaze | 3 · 5 · 2 | 3 DFC · 2 carrileros, MCD, volante, MCO · 2 DEL | domina el medio pero deja 3 atrás: partidos locos; los carrileros gastan más estamina |
- Carrilero = un LAT o un EXT; volante = un MCD, MCO o EXT. La línea la da el puesto en la formación, no
  el rol del jugador (en el 4-3-3 los extremos juegan arriba).
- Por qué el rombo para Tiki-Taka: el clásico es el 4-3-3, pero con 3 volantes perdería el medio contra
  un 4-4-2; el rombo le da 4 por adentro y pone a M14 de enganche.

**Cómo se usan:** en cada jugada se compara tu línea con la de ellos que te espera.
| Jugada | Tu línea | Su línea | Duelo |
|---|---|---|---|
| 1 · Salida | atrás (sales jugando) | arriba (te presionan) | contra uno de sus delanteros |
| 2 · Medio | medio | medio | contra uno de sus volantes |
| 3 · Definición | arriba | atrás | contra su arquero (remate) o un defensa (regate, pase) |
- **Números:** la diferencia es una línea del desglose; **1 jugador = 6 pts** para las pruebas (lo que
  vale hoy una Presión). Como en el fútbol, salir jugando suele ser con ventaja y definir, en inferioridad.
- **Postura:** en HIGH un volante sube (medio −1, arriba +1); en LOW uno baja (medio −1, atrás +1). La
  formación pone el tope: el 5-3-2 nunca tiene más de 3 arriba.
- **Azar, como los encuentros de Slay the Spire:** en cada jugada la línea rival puede tener uno más o uno
  menos (alguien llegó o quedó mal parado). Con el nivel de tu DT lo ves antes de elegir la carta (I-41).
- **Quién juega tu carta:** el que tiene el balón; al pasar eliges a quién se la das (D-31).
  **A quién enfrentas:** lo más probable, a uno de la línea que cruzas (D-31).
- **Las cartas de defensa se leen como jugadores:** Presión = uno más en todas tus líneas (6); Bloqueo = dos
  más atrás contra su remate (12, lo que vale hoy); Línea de cinco = dos más atrás.
- **Transición** = el rival quedó desordenado: una de sus líneas con uno menos en tu próximo Momento.

**Ejemplo** (valores de prueba; los jugadores de Palestino, inventados): Colo-Colo (4-1-2-1-2) ataca a
Palestino (5-3-2), los dos en NORMAL. % = 39 + carta + duelo + números.
| Jugada | Tu carta (quién) | Te enfrenta | Duelo | Números | % | Hoy* |
|---|---|---|---|---|---|---|
| 1 · Salida | Pase corto (Aceval, Pase 66) | un DEL (Lectura 50) | +8 | 4 contra 2: +12 | 65% | 45% |
| 2 · Medio | Amague (M14, Regate 90) | un MCD (Quite 75) | +7,5 | 4 contra 3: +6 | 71% | 57% |
| 3 · Definición | Remate de primera (Suazo, Remate 95) | su arquero (Atajada 72) | +11,5 | 2 contra 5: −18 | 73% | 79% |
\* con la dificultad base de hoy. Contra el Catenaccio se llega fácil, pero en el área esperan cinco. Al
revés, Palestino (2 jugadas) sale con 5 contra tus 2 de arriba (+18) y define con 2 contra tus 4 de atrás
(−12). Ojo: con estos valores Colo-Colo arma mucho más fácil que hoy; es la jerarquía buscada (D-18), pero
hay que medir cuánto con `balance-lab`.

**Por decidir o medir:**
- 1 jugador = 6 pts y el azar de ±1: valores de prueba.
- La postura no puede contar dos veces: si en LOW un volante baja (−6 arriba), el −15 de LOW en los
  remates de hoy sobra o se achica.

## Partido por zonas (D-36; T-10 el motor, T-11 la pantalla; 2026-10-28)
Las 3 jugadas del Momento pasan a ser 3 zonas de la cancha: **Salida**, **Medio** y **Área** (I-48).
Cada zona tiene su personalidad: en la Salida los números suelen estar a tu favor pero perderla es lo
peor; en el Área te esperan más y ahí se remata.

**Acuerdos del usuario (2026-10-28):**
1. **Los remates se juegan en el Área.** Desde fuera solo con cartas especiales específicas de tiro
   lejano (hoy, el Tiro de lejos), con su castigo por la distancia. Precisa la regla 3 de D-31.
2. **Qué pasa al fallar:** "fallar no corta, el límite es la mano", en el espíritu de Slay the Spire
   (el riesgo se ve antes, los errores desgastan): robo 1/4 en la Salida y 1/6 en el Medio con
   contragolpe rival, fallar cuesta la mitad del desgaste de la carta, remate fallado 1/2 atajada y 1/2
   rebote, sin cartas se puede Aguantar. Queda en D-36; la cuenta que lo apoyó, abajo.
3. **Los números de cada zona salen de dos fuentes, con valores chicos y medidos:** la formación de cada
   estilo (D-30: "4 contra 2", 6 pts por jugador de diferencia, valor de prueba) y la fuerza de la línea
   (promedio de `skill_rating` de los titulares de esa línea, tuya contra la suya; el factor se mide con
   `balance-lab`). La fuerza de línea es la que trae la jerarquía entre clubes (D-18).
4. **La postura mueve un jugador entre líneas** (HIGH: uno del medio sube; LOW: uno baja) **sin contar
   dos veces:** si la postura ya cambia los números de una zona, sobra el castigo plano que hoy pone LOW a
   los remates; se decide midiendo.

**Fallos, cuenta de servilleta** (no es el motor: una mano de 6 cartas, 4 de avance y 2 remates, 65% en
la Salida, 55% en el Medio y 45% el remate; cada intento gasta una carta; 200 000 Momentos):
| Regla | Gol | Robo (contra rival) | Perdido | Sin cartas |
|---|---|---|---|---|
| A · hoy: 2 fallos y se pierde | 38% | 0% | 62% | 0% |
| B · fallar no corta (D-31) + robo 1/3 Salida, 1/5 Medio | 38% | 26% | 23% | 13% |
| B con robo 1/4 y 1/6 | 40% | 21% | 24% | 14% |
| C · 2 fallos + robo según la zona | 35% | 24% | 42% | 0% |
| E · fallar te hace retroceder una zona + robo | 31% | 28% | 19% | 22% |
Con mano de 4 (cansado: 3 de avance, 1 remate) la regla B baja a 26% de gol y 34-38% sin cartas.
Lo que muestra:
- **El límite real de "fallar no corta" es la mano**, no los PA: cada intento gasta una carta, así que
  los pases de 0 PA no dan intentos infinitos. Con la regla B se marca casi lo mismo que hoy.
- Lo que cambia es **qué pasa con la pelota**: con robo 1/3 y 1/5, uno de cada cuatro Momentos tuyos
  termina en contragolpe rival (cerca de uno por partido por equipo). Es mucho; con 1/4 y 1/6, uno de
  cada cinco.
- **El cansancio pesa más:** con la mano chica te quedas sin cartas a menudo. Calza con D-04 (el
  cansancio cambia el robo de cartas, no el %) y le da más valor a Aguantar (mano nueva).
- Retroceder una zona (E) se ve futbolero pero marca mucho menos y deja a muchos sin cartas: descartada.

## Pantalla de duelos (borrador, 2026-10-27)
Maqueta en el lienzo "Pantalla de duelos" (privado del usuario):
https://claude.ai/artifact/AeeGQGHLiq8XzefCjZ1nFW. Ejemplo: Colo-Colo (4-1-2-1-2) contra U. de Chile
(4-3-3), con los valores de prueba (duelo ×0,5, 1 jugador = 6 pts). Mismo tamaño que el juego (1280×720).

**Ataque (de arriba abajo):**
- **Marcador y postura**, como hoy, más el nivel del DT.
- **Camino del Momento:** una franja con las 3 jugadas (salida, medio, definición). Cada una muestra
  cuántos hay ("4 contra 3", con puntos de los dos colores), el + o − que da y a quién enfrentas. La
  jugada actual va marcada; la hecha, con su resultado.
- **Duelo al centro:** tu lámina contra la suya, con la habilidad en juego resaltada (Regate de M14
  contra Quite de Iturra), la cuenta del duelo y los números de esa línea.
- **Desglose** (al pasar sobre una carta): base, carta, duelo y números, y el total que se tira.
- **Transmisión:** lo que pasó, lo que pasa y lo que viene, en texto de relato.
- **Mano:** arriba dice quién tiene el balón (él juega las cartas). Cada carta muestra PA, tipo, nombre,
  verbo y contra qué habilidad va, el % con el robo al lado ("71% · robo 6%"), su efecto o los
  modificadores, y el desgaste. Las de pase muestran a quién pueden ir, con un punto naranja si ese
  jugador está cansado. El Tiro de lejos se juega desde el medio con su castigo; los demás remates
  aparecen apagados fuera de la definición.

**Defensa:** la franja pasa a ser la **intención del rival** (su camino por tus líneas, con lo que le
suma o le resta cada línea). Al pasar sobre una carta defensiva se ve cómo cambian los números
("antes 4 contra 2"). Al centro, su remate contra tu arquero.

**Nivel del DT:** 1 = ves la jugada que tiras; 2 = los números de todo el camino y del ataque rival;
3 = a quién vas a enfrentar y quién remata. **Lo que tiras siempre se ve completo** (pilar 2): el nivel
solo muestra lo que viene.

**Láminas:** la media (el nivel) con estrellas, puesto, club, edad, las 5 habilidades con barras y el
Físico en celeste. La élite lleva marco dorado y su perfil ("Gambeteador: +6 a Regate"); los demás, "sin
perfil". El arquero muestra Atajada y Físico (Bravo, élite: Atajador). En el partido, las láminas
chicas muestran además la carga del jugador.

**Reglas de los duelos (D-31; respuestas del usuario del 2026-10-27, con propuestas para probar):**
1. **A quién enfrentas:** se decide al empezar el Momento. Cualquier rival te puede salir, pero es más
   probable el más cercano. Propuesta: 70% uno de la línea que cruzas, 25% uno de una línea vecina, 5%
   cualquiera. El arquero solo aparece contra los remates.
2. **Fallar no corta el Momento:** sigues contra el mismo rival hasta que se te acaben los PA (o las
   cartas) o te la roben. Reemplaza "2 fallos lo pierden" (GDD 2.1) en el modelo de duelos. **Robo
   según la línea (D-32):** en la salida 1 de cada 3 fallos, en el medio 1 de cada 5; la carta lo
   muestra ("71% · robo 6%"). Propuesta para la definición: 1 de cada 5 en las jugadas y, si un remate
   falla, 1 de cada 2 veces el arquero se queda con la pelota (se acaba el Momento). Si te la roban en
   la salida o en el medio, el rival queda con contragolpe; en la definición, no.
3. **Los remates solo se juegan en la definición**, salvo las cartas de tiro lejano, que se juegan desde
   más atrás con castigo por la distancia. Propuesta: desde el medio −15 y desde la salida −35; no
   cuentan los números del área (el tiro pasa por encima), solo el arquero.
4. **Duelos de las cartas de defensa**, como en la maqueta: Presión y Bloqueo con tu Quite, Despeje con
   tu Lectura.
5. **La carta la juega el que tiene el balón**, y al pasar eliges a quién se la das (es una segunda
   decisión). Los rechazos (despejes) caen al azar. Propuesta para el arranque: en un Momento normal
   eliges quién sale de tu línea de atrás; tras una intercepción arranca el que la cortó; tras un
   despeje, uno al azar.
6. **Cada jugador se cansa por separado**, para obligar a rotar (si juegas todo con M14, se funde). Cada
   jugador suma carga con el desgaste de las cartas que juega y la recupera entre Momentos. **Idea del
   usuario (D-32, a probar): el cansancio quita PA.** Propuesta: pasado su Físico, el jugador queda
   cansado y sus cartas cuestan +1 PA (en naranja, como el reuso en Flow). No toca el % de acierto
   (D-04). Valor de prueba: cansado cuando su carga pasa la mitad de su Físico.

**Revisión del punto 6 (D-32):**
- Fórmula más corta (puesto hasta +3, perfil +6, tope 95) y Bravo con perfil Atajador: Alcázar 89 de
  Remate, Suazo 95, M14 90 de Regate, Bravo 86 de Atajada.
- El Ejecutor Natural se mantiene, más chico (+5 de prueba): es la carta del jugador, pero +15 era mucho.
- Propuestas sin objeción (por confirmar): escala 1-100 en el partido y estrellas como resumen de la media
  en los menús (★ por tramo: 60-69 dos, 70-79 tres, 80-89 cuatro, 90 o más cinco); y el **mano a mano**:
  si antes superas la última línea con un regate o un pase en la definición, el remate solo cuenta al
  arquero.
- **El remate sigue alto, y por qué** (Arremetida de Alcázar contra Bravo, 3 contra 4 en el área):
  | Parte | Antes | Con D-32 | Con el bono de remate −10 |
  |---|---|---|---|
  | Base | 39 | 39 | 39 |
  | Carta (Arremetida) | +40 | +40 | +30 |
  | Duelo, Remate contra Atajada (×0,5) | 95 contra 80: +7,5 | 89 contra 86: +1,5 | +1,5 |
  | Números (3 contra 4) | −6 | −6 | −6 |
  | Ejecutor Natural | +15 | +5 | +5 |
  | **Total** | 95 (tope) | **80%** | **70%** |
  | Mano a mano | 95 (tope) | 86% | 76% |
  Lo que más pesa es el bono de la carta: los +40 de los remates se calibraron sin duelos, cuando el bono
  tenía que hacer todo el trabajo. Propuesta para `balance-lab`: bajar los remates unos 10 puntos en el
  modelo de duelos y comprobar que la matriz siga en 2.3-2.6 goles.

## Intención del rival y superioridad numérica (I-41, I-44)
- **Qué ves depende del nivel de tu DT frente al del rival** (usuario). El tuyo sube con la experiencia;
  cada DT rival tiene un nivel estimado para la IA (I-46).
  - Tu DT por debajo: "Ataca Colo-Colo · atacan 4-5".
  - Parejo: "atacan 5 · jugada de 3".
  - Por encima: "atacan 5 · jugada de 3 · remata Suazo con el Zapatazo".
- **Cuántos atacan contra cuántos defienden:** se cuenta por línea, en cada jugada, con la formación,
  la postura y algo de azar (ver "Formaciones"). La diferencia es una línea del desglose ("4 contra 2:
  +12"), visible en cada carta (pilar 2).
- El largo de la jugada ya depende del estilo en parte (Catenaccio 2, D-16); la intención lo muestra.
  Cartas que den más jugadas o PA: más adelante.

## Duelos por línea (borrador, I-45) y nivel del DT (I-46)
Idea del usuario (2026-10-27): los enfrentamientos son como en Slay the Spire, pero en cada jugada te
enfrentas a un defensa central, a un volante o a un delantero rival. Así importan las valoraciones de
los jugadores.

**Estructura propuesta:** las 3 jugadas del Momento son las 3 líneas del rival.
| Jugada | Cruzas | Te enfrenta | Duelo típico |
|---|---|---|---|
| 1 · Salida | sus delanteros (presionan) | uno de sus delanteros | pase contra lectura |
| 2 · Medio | sus volantes | uno de sus volantes | regate contra quite, pase contra lectura |
| 3 · Definición | sus defensas y el arquero | su arquero o un defensa | remate contra atajada |
- Catenaccio (2 jugadas, D-16) = salida y definición: se salta el medio, juega directo.
- La **formación del estilo** dice cuántos hay en cada línea (ver "Formaciones", D-30).
- **Transición** = el rival quedó desordenado: una de sus líneas con uno menos en tu próximo Momento.
- **Pase largo / Pelotazo** = te saltas una línea (avanza 2), sin duelo en ella.

**Ejemplo:** ver "Habilidades de los jugadores" más abajo (M14 contra Kalule, con la fórmula propuesta).

**Qué hace falta (por qué es un cambio grande):** hoy cada jugador tiene un solo número
(`skill_rating`: Matías Fernández 84, Rodrigo Meléndez 72) y el partido usa un único `PlayerStats`:
todos los clubes tienen la misma técnica (60) y las diferencias salen de las instalaciones. Hacen falta
habilidades por jugador (propuesta abajo), un desglose nuevo y bots que elijan carta según el duelo.
Se recalibra todo el balance.

**Pasos propuestos (básico primero, como D-28):**
1. Duelo contra la **línea**: un número por línea (promedio del plantel). Prueba si la estructura de 3
   líneas es divertida.
2. Duelo contra un **jugador** de la línea, con atributos y figuras que destacan (Kalule, M14).
3. **Verbos que interactúan** (regate contra quite, pase largo que salta), superioridad numérica e
   intención según el nivel del DT.

**Nivel del DT (I-46):** el tuyo sube con la experiencia; cada nivel muestra más de la intención del
rival y suma cartas más complejas a las ofertas del entrenamiento (D-28). Cada DT rival tiene un nivel
estimado para la IA, asignado en los datos como el arquetipo.

## Transición: reglas por decidir (I-40)
Cálculo simplificado de la escala (Momento de 3 jugadas al 60%, un fallo de margen, sin contar PA):
sin bono ~48% de gol · +10 solo en la primera ~52% · +6 en todas ("uno más") ~58% · +10 en todas ~65%.
| Pregunta | Opciones | Recomendación |
|---|---|---|
| ¿A qué jugadas? | la primera / todas | todas, como "+1 atacante" (~58%): un solo concepto con la superioridad numérica |
| ¿Se suma al contragolpe? | sí / no | sí, es el combo del Contragolpe (Anticipo 1 PA + Salida limpia 1 PA); máximo una transición por Momento |
| ¿Se pierde si te hacen gol? | sí / no | sí: saque del medio. Es la apuesta de dejar atacar al rival |
| ¿Cuánto dura? | próximo Momento / se guarda | solo tu próximo Momento, con aviso "TRANSICIÓN LISTA" como el del contragolpe |

## Cartas de estilo por arquetipo (primer boceto, I-42; lo reemplaza «Cartas v2», D-38)
La personalidad del DT vive en las cartas que le ofrece su entrenamiento (las "2 de tu estilo" de
T-05), como las clases de Slay the Spire. Hoy las listas de crecimiento de T-04 son las mismas cartas
genéricas en otro orden: lo único propio de cada estilo es su rasgo. Cada carta usa un verbo del idioma
con el toque del estilo. Sin números (✓ = se arma con campos que ya existen y se puede medir hoy).

| Estilo | Ataque | Control / transición | Defensa |
|---|---|---|---|
| Tiki-Taka | **Paredita** (pase): cuenta doble para el Flow | **Salida limpia**: no frena; si sale, +1 atacante en tu próximo Momento y robas 1 | **Presión tras pérdida**: +1 defensor; si sale, transición |
| Directo | **Cabezazo** (remate barato): solo después de un Centro o un Pelotazo | **Bajarla de pecho** (control): la siguiente jugada +X | **Segunda pelota** (bloqueo): si sale, contragolpe ✓ |
| Catenaccio | **Pelota parada** (remate): la Presión rival no le afecta, solo el Bloqueo | — (su identidad es cortar) | **Marcaje al hombre**: la firma rival pierde el Ejecutor Natural · **Línea de cinco**: +2 defensores |
| Kamikaze | **Todos al área** (centro): +1 atacante en este Momento, desgaste muy alto | **Recuperar arriba** (presión): si sale, contragolpe ✓ | **Presión asfixiante** (I-08): el rival gasta más estamina |
| Contragolpe | **Pase en profundidad**: avanza 2 si el Momento es un contragolpe | **Salida en velocidad**: no frena; si sale, contragolpe ✓ | **Contra letal** (intercepción): si sale, contragolpe y +X al remate |

## Cartas v2: estilo del DT y jugadas de crack (propuesta, 2026-10-28, D-38)
Inspiración: Slay the Spire (cada carta con su "+", rarezas, poderes, cartas temporales) y NUTMEG
(mejoras con nombre de folclore, cartas que salen de la táctica y del plantel; sus críticas —pocas
decisiones reales, secuencias repetidas, azar opaco— son lo que hay que evitar). Todo sin números
medidos: son **valores de partida**, dentro del rango de las cartas actuales, que se miden con
`balance-lab` al implementarlas (la mayoría necesita el partido por zonas, T-10).

**Estructura (D-38):**
- **8 cartas por estilo** (40): 3 básicas, 3 tácticas, 1 élite (jugada de laboratorio, UNA VEZ) y 1
  instrucción táctica. Las ofrece el entrenamiento táctico de ese estilo; las élite salen poco.
- **Cada carta tiene su "+"**, como en Slay the Spire: la sesión de video convierte una carta en su "+"
  (reemplaza la mejora genérica de +10 o −1 PA de D-21). Las cartas genéricas que ya existen también
  necesitan su "+" (por definir).
- **Jugadas de crack:** cartas de lujo (caño, bicicleta, chilena...) que solo aparecen si en tu plantel hay
  un jugador con ese perfil (D-29), y que juega ese jugador (Ejecutor Natural).
- **Complejidad progresiva (D-28):** las básicas usan solo efectos simples; tácticas, élite e
  instrucciones se desbloquean con el nivel del DT (I-46). Sin nivel del DT implementado, se ofrecen
  desde la mitad de la temporada.

### Palabras clave (glosario; el usuario aprobó todas)
| Palabra | Qué significa en la carta |
|---|---|
| **AVANZA 2** | Si sale, cuenta como 2 jugadas (salta una zona). Ya existe (`steps`) |
| **ROBA N** | Si sale, robas N cartas. Ya existe (`draw`) |
| **CONTRAGOLPE** | Si sale, tu próximo Momento arranca en el Medio. Ya existe (`counter`) |
| **SIN ROBO** | Si fallas, no te la quitan |
| **+1 ATACANTE / +N DEFENSORES** | Cambia los números de una zona ("4 contra 2") por este Momento o este ataque |
| **UNA VEZ** | Se juega una vez por partido; después sale del mazo hasta el próximo partido |
| **GUARDAR** | Puedes dejarla para tu próximo Momento en vez de perderla |
| **TITULAR** | Siempre está en tu primera mano del partido |
| **AL TOQUE** | Si no la juegas en este Momento, se descarta |
| **LEER N** | Miras tus próximas N cartas y descartas las que quieras |
| **+PA** | Suma PA a este Momento |
| **TODO O NADA** | Gasta todos tus PA; el efecto crece con cada PA |
| **INSTRUCCIÓN** | Se juega una vez y queda activa el resto del partido |
| **DESORDENADO** | Una línea rival juega con un jugador menos durante 2 jugadas |
| **ASFIXIA N** | El rival gasta +N de estamina por cada carta que juega; se acumula |
| **TEMPORAL** | Carta creada en el partido; desaparece al terminar el Momento |
| **AMARILLA** | Te amonestan; con 2 en el partido, una de tus líneas juega con uno menos (por decidir) |

### Tiki-Taka · brilla en el Medio: cadenas baratas, posesión, nunca perder la pelota
| Carta | Rareza | Tipo | PA | Desg. | Bono | Efecto | "+" |
|---|---|---|---|---|---|---|---|
| **Salida limpia** | básica | control | 0 | 2 | +10 | SIN ROBO (en la Salida) | +16 |
| **Paredita** | básica | pase | 0 | 3 | +12 | Cuenta doble para el Flow | +18 |
| **Posesión** | básica | control | 1 | 2 | +14 | Si sale, tu próxima carta cuesta −1 PA | Cuesta 0 PA |
| **Rondo** | táctica | control | 1 | 3 | +10 | Crea 2 Toquecitos (pase, 0 PA, +8, TEMPORAL) | Crea 3 |
| **Leer el medio** | táctica | control | 1 | 2 | +12 | LEER 3 | LEER 3 y ROBA 1 |
| **Presión tras pérdida** | táctica | presión (def.) | 1 | 5 | +6 | Si el rival falla en su Salida, se la robas seguro (CONTRAGOLPE) | +10 |
| **La pelota es nuestra** | élite | control | 2 | 4 | — | UNA VEZ: en este Momento tus fallos no cuentan ni hay robo | Cuesta 1 PA |
| **Juego de posición** | instrucción | — | 2 | 0 | — | INSTRUCCIÓN: tus pases +4 en el Medio | +6 |

### Directo · se salta el Medio y vive de centros y llegadas al Área
| Carta | Rareza | Tipo | PA | Desg. | Bono | Efecto | "+" |
|---|---|---|---|---|---|---|---|
| **Bajarla de pecho** | básica | control | 0 | 3 | +10 | Si sale, tu siguiente jugada +10 | Siguiente +15 |
| **Segunda pelota** | básica | bloqueo (def.) | 1 | 3 | +8 | CONTRAGOLPE | +14 |
| **Saque largo del arquero** | básica | pase | 0 | 2 | +0 | Desde la Salida, AVANZA 2 | +12 |
| **Llegada de segunda línea** | táctica | pase | 1 | 4 | +12 | +1 ATACANTE en el Área este Momento | +18 |
| **Cabezazo** | táctica | remate | 1 | 5 | +30 | Solo después de un Centro o un Pelotazo | +38 |
| **Desborde por la banda** | táctica | regate | 1 | 5 | +16 | Si sale, tu próximo Centro +12 | Próximo Centro +18 |
| **Lluvia de centros** | élite | centro | 2 | 8 | +20 | UNA VEZ: los remates de este Momento ignoran los números del Área | Cuesta 1 PA |
| **Fútbol directo** | instrucción | — | 1 | 0 | — | INSTRUCCIÓN: tus Pelotazos y saques largos +8 | +12 |

### Catenaccio · cierra su Área, gasta poco y marca de pelota parada
| Carta | Rareza | Tipo | PA | Desg. | Bono | Efecto | "+" |
|---|---|---|---|---|---|---|---|
| **Línea de cinco** | básica | bloqueo (def.) | 1 | 2 | +8 | +2 DEFENSORES en tu Área | Cuesta 0 PA |
| **Hacer tiempo** | básica | pausa | 1 | 0 | +25 | Variante de la Pausa: si sale, recupera estamina | Recupera más |
| **Doble pivote** | básica | presión (def.) | 1 | 2 | +6 | +1 DEFENSOR en tu Medio | También +1 en tu Área |
| **Pelota parada** | táctica | remate | 2 | 5 | +28 | Ignora los números del Área | +36 |
| **Marcaje al hombre** | táctica | presión (def.) | 1 | 3 | +4 | La figura rival pierde su Ejecutor Natural en este ataque | Y su carta propia −6 |
| **Falta táctica** | táctica | presión (def.) | 0 | 2 | +10 | Corta su ataque en el Medio, pero AMARILLA | +16 |
| **El muro** | élite | bloqueo (def.) | 2 | 3 | — | UNA VEZ: el próximo ataque rival no puede rematar | Cuesta 1 PA |
| **Bloque bajo** | instrucción | — | 1 | 0 | — | INSTRUCCIÓN: tus cartas de defensa +4 | +6 |

### Kamikaze · todos arriba, mucho desgaste, nunca se rinde
| Carta | Rareza | Tipo | PA | Desg. | Bono | Efecto | "+" |
|---|---|---|---|---|---|---|---|
| **Recuperar arriba** | básica | presión (def.) | 1 | 6 | +6 | CONTRAGOLPE | +12 |
| **Todos al área** | básica | centro | 1 | 8 | +18 | +1 ATACANTE en el Área este Momento | +24 |
| **A lo que salga** | básica | remate | 1 | 9 | +32 | Si falla, rebote seguro: sigues en el Área | +38 |
| **Presión asfixiante** | táctica | presión (def.) | 2 | 8 | +8 | ASFIXIA 1 (I-08) | ASFIXIA 2 |
| **Todo o nada** | táctica | remate | todos | 10 | — | TODO O NADA: +14 por cada PA | +18 por cada PA |
| **Carrilero desbocado** | táctica | regate | 0 | 7 | +14 | AL TOQUE; si sale, +1 PA | +20 |
| **Último minuto** | élite | control | 1 | 5 | — | UNA VEZ, solo en el 2T: robas hasta llenar la mano y +2 PA | Cuesta 0 PA |
| **Presión total** | instrucción | — | 1 | 0 | — | INSTRUCCIÓN: tus Presiones +4, pero todas tus cartas desgastan +1 | Sin el desgaste extra |

### Contragolpe · espera, roba y sale rápido
| Carta | Rareza | Tipo | PA | Desg. | Bono | Efecto | "+" |
|---|---|---|---|---|---|---|---|
| **Salida en velocidad** | básica | defensa | 0 | 4 | +12 | No frena; si sale, CONTRAGOLPE (la transición, I-40) | +18 |
| **Repliegue** | básica | bloqueo (def.) | 1 | 2 | +6 | +1 DEFENSOR en tu Área; si su remate falla, CONTRAGOLPE | +10 |
| **Pase en profundidad** | básica | pase | 1 | 4 | +14 | En un contragolpe, AVANZA 2 | +20 |
| **Leer el pase** | táctica | intercepción (def.) | 1 | 3 | — | Corta; tu contragolpe arranca en el Medio | Arranca en el Área |
| **Contra letal** | táctica | intercepción (def.) | 2 | 4 | — | Corta, CONTRAGOLPE y tu próximo remate +10 | +16 |
| **Esperar atrás** | táctica | control | 0 | 0 | — | GUARDAR hasta 2 cartas para tu próximo Momento | Hasta 3 |
| **Contra de manual** | élite | pase | 1 | 6 | — | UNA VEZ, en un contragolpe: vas directo al Área y tu remate +15 | +25 |
| **Transiciones** | instrucción | — | 1 | 0 | — | INSTRUCCIÓN: tus contragolpes arrancan con +1 PA | Y robas 1 |

### Jugadas de crack · dependen del perfil del jugador (D-29)
Solo se ofrecen si en tu plantel hay un jugador con ese perfil, y las juega él (Ejecutor Natural). Son
lo vistoso del juego: el usuario pidió cartas más llamativas, como el caño y la bicicleta.
| Perfil | Carta | Tipo | PA | Desg. | Bono | Efecto | "+" |
|---|---|---|---|---|---|---|---|
| Gambeteador | **Caño** | regate | 1 | 4 | +18 | Ignora la Presión rival | Y DESORDENADO su línea |
| Gambeteador | **Bicicleta** | regate | 0 | 5 | +12 | Si sale, tu siguiente jugada +8 | +18 |
| Gambeteador | **Sombrerito** | regate | 1 | 5 | +16 | Si sale, un defensor menos en esta zona | +22 |
| Enganche | **Taco** | pase | 0 | 3 | +14 | AL TOQUE; ROBA 1 | ROBA 2 |
| Enganche | **Pase de la muerte** | centro | 1 | 4 | +20 | Tu siguiente remate +12 | +18 |
| Enganche | **Rabona** | pase | 1 | 5 | +24 | Si sale, +1 de popularidad en la semana | +30 |
| Goleador | **Chilena** | remate | 3 | 8 | +45 | Ya existe; pasaría a ser del Goleador | Cuesta 2 PA |
| Goleador | **Palomita** | remate | 1 | 6 | +28 | Solo después de un Centro | +36 |
| Goleador | **Vaselina** | remate | 2 | 5 | +30 | Mano a mano: solo cuenta el arquero | +38 |
| Perro de presa | **Barrida** | bloqueo (def.) | 1 | 5 | +12 | Corta su jugada; 1 de cada 4, AMARILLA | +18 |
| Perro de presa | **Pierna fuerte** | presión (def.) | 1 | 4 | +8 | DESORDENADO su Medio | +12 |
| Recuperador | **Corte y salida** | intercepción (def.) | 1 | 3 | — | Corta y CONTRAGOLPE | Cuesta 0 PA |
| Atleta | **Pique largo** | pase | 1 | 8 | +10 | AVANZA 2 | +16 |
| Atajador | **Achique** | defensa | 1 | 3 | +10 | Su remate en mano a mano −10 | −16 |
| Atajador | **Atajada imposible** | defensa | 2 | 4 | — | UNA VEZ: anula un remate que iba a ser gol | Cuesta 1 PA |

### Por revisar (instrucciones y lo nuevo)
- **Instrucciones:** son poderes de todo el partido y pueden escalar demasiado. Propuesta: **una sola
  instrucción activa a la vez** (la nueva reemplaza a la anterior), como la indicación principal del DT.
- **AMARILLA:** mecánica nueva (dos = un jugador menos en una línea). Decidir si entra o si la Falta
  táctica y la Barrida cuestan otra cosa.
- **Las "+" de las cartas genéricas** que ya existen (Pase corto, Remate de primera, etc.).
- **Qué se puede probar ya** (sin zonas ni efectos nuevos): Segunda pelota, Hacer tiempo, Recuperar
  arriba y Salida en velocidad (`counter`), Saque largo y Pique largo (`steps`), Taco (`draw`).
- **Balance:** las de "+1 atacante", ignorar números, la Pelota parada y las élite suben los goles; la
  curva de la temporada ya está sobre el rango, así que se miden junto con T-10.

## Cartas especiales con efecto propio (en espera)
Se diseñan después de cerrar el bucle del mazo (T-04 y T-05) y de los primeros playtests (I-39). Aquí
van solo ideas sueltas, sin números.

- Cartas que dan más jugadas o PA en el Momento (usuario, 2026-10-27): más adelante, sin complicarnos aún.

## Jugadas anotadas
Secuencias que salgan jugando, para ver qué se repite y qué falta. Formato:
`fecha · club vs rival · postura · carta → carta → carta · resultado · nota`.
Los playtests completos siguen yendo a `docs/playtests/`.

_Sin entradas todavía._
