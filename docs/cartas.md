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

## Cartas especiales con efecto propio (en espera)
Se diseñan después de cerrar el bucle del mazo (T-04 y T-05) y de los primeros playtests (I-39). Aquí
van solo ideas sueltas, sin números.

_Sin entradas todavía._

## Jugadas anotadas
Secuencias que salgan jugando, para ver qué se repite y qué falta. Formato:
`fecha · club vs rival · postura · carta → carta → carta · resultado · nota`.
Los playtests completos siguen yendo a `docs/playtests/`.

_Sin entradas todavía._
