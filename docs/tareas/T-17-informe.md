# T-17 · El mazo se arma semana a semana — informe

Rama `tarea/t-17-mazo-nuevo`. Sin PR ni mezcla. Capturas en `C:\Users\vicen\Desktop\bonvalet\capturas-t17\`.

## Qué cambió (en lenguaje de juego)
- **Mazo de inicio nuevo:** 12 cartas del DT (más la firma de tu figura): Pase corto, Pase al pie, **Pase largo** (avanza 2), Amague, 2 Promesas, 2 Remate simple, Presión, Intercepción, Bloqueo y la carta de rasgo. Ya no hay Marca ni Despeje al inicio.
- **19 cartas nuevas de estilo** (más **Descarga**, genérica: 0 PA, vuelve atrás y roba 1) para Tiki-Taka, Catenaccio y Contragolpe, cada una con su "+" (la sesión de video la convierte con un solo botón "SU +"). Directo y Kamikaze quedan en pausa (D-49).
- **Ofertas con intención:** de las 3 láminas de la semana, **al menos 1 es de tu estilo**; las otras salen de la general y de los otros estilos. Las básicas salen siempre, las tácticas desde la semana 3, y las élite y las instrucciones desde la semana 8 y solo a veces. La carta que no tomaste una semana no vuelve la siguiente.
- **Instrucción:** una carta que se juega una vez y queda activa en el marcador ("INSTRUCCIÓN: JUEGO DE POSICIÓN"); jugar otra la reemplaza. No mueve la pelota ni cuenta como jugada.
- **Pase largo apuntable:** al arrastrar un pase que avanza 2, ahora también se rotulan los compañeros de dos zonas más adelante (antes no se podía apuntar a ellos con el mouse).
- **Dos carreras distintas terminan con mazos distintos** (criterio de M2): prueba nueva en `career_rules` con 3 clubes y 14 semanas; los mazos difieren en 5 cartas o más.

## Regla del 4% (D-39), carta por carta
Cómo se midió: modo de duelos, 100 partidos por cruce, 5 clubes, agregando **1 copia de la carta al mazo de todos**. El tope es 2,70 goles por partido (2,6 + 4%). Mazo nuevo sin ninguna copia extra: **2,27 goles**.

| Carta | Goles | Carta | Goles |
|---|---|---|---|
| Salida limpia | 2,20 | Marcaje al hombre | 2,12 |
| Posesión | 2,16 | El muro | 2,19 |
| Presión tras pérdida | 2,26 | Bloque bajo | 2,29 |
| La pelota es nuestra | 2,04 | Repliegue | 2,19 |
| Juego de posición | **1,82** | Pase en profundidad | 2,05 |
| Línea de cinco | 2,04 | Leer el pase | 2,13 |
| Hacer tiempo | 1,98 | Contra letal | 2,24 |
| Doble pivote | 2,05 | Contra de manual | 2,02 |
| Pelota parada | **2,36** (la más alta) | Transiciones | 1,91 |
| Descarga | 2,01 | | |

**Ninguna carta pasa el 4%: no hubo que encarecer ni condicionar ninguna.** Lo que se ve es lo contrario: casi todas *bajan* los goles respecto del mazo base, porque una copia más diluye la mano y varias cuestan PA sin avanzar. La que más los baja es **Juego de posición** (1,82): gasta 2 PA y su +4 en los pases del Medio casi no compensa. Presión tras pérdida sube el cansancio (25% y 63%). Con 100 partidos por cruce el margen de error es de ±0,05 goles aproximadamente.

## Antes y después (modo de duelos)
El "antes" es el mazo de hoy (400 partidos por cruce); el "después", el mazo nuevo (100 por cruce, la medición liviana que se pidió).

| | Antes (inicio) | Después (inicio) |
|---|---|---|
| Goles por partido | 1,75 | **2,27** |
| Lesiones | 1,8% | 2,8% |
| Cansancio 1T / 2T | 9% / 34% | 16% / 53% |
| Robos por partido | 0,80 | 0,83 |
| Contragolpes por partido | 0,93 | 1,19 |
| Ataques cortados por partido | 2,34 | **0,91** |
| Divididas / laterales / faltas / córners | 2,61 / 0,79 / 0,66 / 0,18 | 2,91 / 0,67 / 0,86 / 0,30 |
| Jerarquía (goles a favor-en contra) | Colo-Colo (Tiki) 1,12-0,59 · Palestino (Catenaccio) 0,55-0,98 · U. Católica (Contragolpe) 1,05-0,75 · Cobreloa (Directo) 0,75-0,68 · La Serena (Kamikaze) 0,90-1,37 | Colo-Colo 1,36-0,72 · Palestino 0,69-1,38 · U. Católica 1,47-1,03 · Cobreloa 0,89-1,07 · La Serena 1,26-1,48 |

El "antes" de la mitad (+4) fue 1,97 goles y 1,9% de lesiones. **Sin medir:** el "antes" del final, y el "después" de la mitad y del final (el usuario pidió no simular de más).
Con el mazo nuevo el inicio queda un poco **bajo** el rango de 2,3-2,6 (2,27) en duelos. Los cortes caen a menos de la mitad: el mazo nuevo ya no trae Despeje ni Marca, y las defensas de D-44 cortan menos.

**Línea base oficial** (`godot-check -Balance`, la matriz clásica de `sim.gd`): inicio **2,91**, mitad **2,86**, final **2,76** goles (antes 2,50 / 2,75 / 2,68), lesiones 3,9% / 3,8% / 3,7%, cansancio 2T 65% / 61% / 62%, constructibilidad 96%. **Quedó sobre el rango en las tres etapas.** No recalibré (el brief pide ajustar solo valores de cartas nuevas y ninguna se pasó del 4%); es una decisión de balance para el usuario, ver abajo. Anotada en `docs/arquitectura.md`.

## El cruce Catenaccio contra Contragolpe (encargo extra)
Con `tests/lab/triangulo.gd --cartas=ofertas` (cada lado con las 7 cartas de su estilo en el mazo; 150 partidos; ventaja de estilo +3):

| Cruce | T-18 (sin cartas nuevas) | Con las cartas nuevas |
|---|---|---|
| Catenaccio contra Contragolpe (puntos de Catenaccio) | 36,9% | **39,8%** (41 victorias, 40 empates, 69 derrotas) |
| Contragolpe contra Catenaccio (inverso, puntos de Contragolpe) | 75,0% | **70,6%** (82, 42, 26) |

Catenaccio mejora unos 3 puntos y Contragolpe baja unos 4, pero **Catenaccio sigue perdiendo aunque tenga la ventaja** (±4 puntos de margen). Las cartas solas no alcanzan: el perfil de juego del bot de Catenaccio sigue siendo la causa (decisión de balance abierta de T-18).

## Cartas que no entraron (insumo de la siguiente tanda)
| Carta | Qué le falta |
|---|---|
| Paredita (Tiki-Taka) | pase de ida y vuelta: el portador no cambia y se saca una marca (regla del portador, D-47 punto 3) |
| Rondo (Tiki-Taka) | cartas temporales que se crean en la mano y desaparecen al terminar el Momento |
| Leer el medio (Tiki-Taka) | mirar las 3 próximas cartas y elegir cuáles descartar (pantalla de elección en pleno Momento) |
| Falta táctica (Catenaccio) | cortar en el Medio y que el próximo Momento rival arranque en tu Área (tiro libre) |
| Esperar atrás (Contragolpe) | elegir cartas de la mano para guardarlas al próximo Momento (pantalla de elección) |

Entraron **simplificadas** (anotado en `docs/cartas.md`): Presión tras pérdida (sin su condición), Línea de cinco, Doble pivote y Repliegue (las marcas extra van sobre el portador rival, no "sobre rivales de la zona"), Hacer tiempo (igual a la Pausa) y Leer el pase (igual a Anticipo). Ni AL TOQUE ni +PA hicieron falta.

## Decisiones pendientes para el usuario
1. **Una Promesa o dos.** D-45 pedía 1 Promesa y 2 Pase corto, pero la liga exige 2 cartas Sub-21 en el mazo y cada Promesa es una; con 1 sola el mazo sería inválido. Dejé **1 Pase corto y 2 Promesas**. Alternativa: bajar la exigencia de la liga a 1.
2. **Pase largo.** Es una carta propia, igual al Pelotazo, porque Pelotazo ya es el rasgo de Directo (si no, Directo habría tenido dos).
3. **Goles de la matriz clásica** sobre el rango (2,91 al inicio) y duelos un poco bajo (2,27): el mazo nuevo cambia el balance más de lo que ninguna carta nueva por sí sola. Hay que decidir si se recalibra (mazo base, Pase largo, Remate simple) y con qué métrica.
4. **Catenaccio contra Contragolpe** sigue en 40%: hace falta tocar el perfil del bot de Catenaccio o sus cartas.
5. **Instrucciones:** Juego de posición baja los goles un 20% al jugarse (1,82); conviene revisar su costo (2 PA).

## Verificación
- `godot-check` en verde (compila, `engine_rules`, `career_rules`, `data_rules`, `smoke_career`, `smoke_match`) y con `-Balance`.
- Pruebas nuevas: cada mecánica en `engine_rules` (instrucción, Posesión, escudo, Salida limpia, UNA VEZ, jugada preparada, ignorar marcas, contragolpe, marcas de más, El muro, bot con remate prohibido); `data_rules` y `career_rules` (mazo de 12, ofertas con estilo propio y rarezas por semana, dos carreras distintas); `smoke_match` (soltar una instrucción y verla en el marcador; apuntar un pase largo).
- Arreglé un bloqueo que descubrió la medición: con El muro el bot planeaba un remate prohibido y repetía la jugada sin terminar nunca el Momento.

## Sin hacer o sin verificar
- No medí la mitad y el final en duelos con el mazo nuevo, ni la prueba con los desenlaces de D-48 apagados que pidió la otra sesión (el usuario pidió no simular más). El 1,75 del "antes" frente al 2,38 de T-15 sigue sin explicar.
- Instrucciones y cartas de defensa en la pantalla de defensa del partido: probadas en el motor y la instrucción de ataque con la pantalla; **no vi con la pantalla** jugar un Bloque bajo ni un El muro mientras defiendo (es la parte del arrastre de D-44).
- El valor de los "+" y las rarezas son iniciales; no jugué partidos a mano.
- La matriz "Arquetipos" de `-Balance` muestra 0,00 goles para Catenaccio sin firma: no verifiqué si ya era así antes de T-17.
- Capturas: oferta de la semana 9, sesión de video (con "SU +"), 6 láminas nuevas (2 por estilo, en dos capturas) y el partido con la instrucción activa. Las láminas de utilidad muestran "+0" grande (no tienen bono); no lo cambié.
