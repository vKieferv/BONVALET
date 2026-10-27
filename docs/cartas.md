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

## Intención del rival y superioridad numérica (I-41, I-44)
- **Qué ves depende del nivel de tu DT frente al del rival** (idea del usuario). El "nivel del DT" no
  existe todavía: falta decidir si es fijo por club, si sube en la carrera o ambas cosas.
  - Tu DT por debajo: "Ataca Colo-Colo · atacan 4-5".
  - Parejo: "atacan 5 · jugada de 3".
  - Por encima: "atacan 5 · jugada de 3 · remata Suazo con el Zapatazo".
- **Cuántos atacan contra cuántos defienden:** la diferencia es una línea del desglose
  ("Superioridad numérica +X" o "Inferioridad −X"), visible en cada carta (pilar 2). Punto de partida
  para medir: 1 jugador de diferencia = 6 pts, lo que vale hoy una Presión. Así la Presión y la Marca
  se leen como "pongo uno más en defensa".
  - Ejemplo: Colo-Colo ataca en HIGH con 5. Defiendes con 5 y juegas Marca (+1): 5 contra 6, sus
    jugadas −6. Si en vez de eso juegas Salida limpia: 5 contra 5, sin efecto, pero tu próximo ataque
    sale con uno más.
  - Por decidir: de dónde sale la base (postura, estilo) sin contar dos veces lo que la postura ya hace.
- El largo de la jugada ya depende del estilo en parte (Catenaccio 2, D-16); la intención lo muestra.
  Cartas que den más jugadas o PA: más adelante.

## Transición: reglas por decidir (I-40)
Cálculo simplificado de la escala (Momento de 3 jugadas al 60%, un fallo de margen, sin contar PA):
sin bono ~48% de gol · +10 solo en la primera ~52% · +6 en todas ("uno más") ~58% · +10 en todas ~65%.
| Pregunta | Opciones | Recomendación |
|---|---|---|
| ¿A qué jugadas? | la primera / todas | todas, como "+1 atacante" (~58%): un solo concepto con la superioridad numérica |
| ¿Se suma al contragolpe? | sí / no | sí, es el combo del Contragolpe (Anticipo 1 PA + Salida limpia 1 PA); máximo una transición por Momento |
| ¿Se pierde si te hacen gol? | sí / no | sí: saque del medio. Es la apuesta de dejar atacar al rival |
| ¿Cuánto dura? | próximo Momento / se guarda | solo tu próximo Momento, con aviso "TRANSICIÓN LISTA" como el del contragolpe |

## Cartas de estilo por arquetipo (borrador, I-42)
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

## Cartas especiales con efecto propio (en espera)
Se diseñan después de cerrar el bucle del mazo (T-04 y T-05) y de los primeros playtests (I-39). Aquí
van solo ideas sueltas, sin números.

- Cartas que dan más jugadas o PA en el Momento (usuario, 2026-10-27): más adelante, sin complicarnos aún.

## Jugadas anotadas
Secuencias que salgan jugando, para ver qué se repite y qué falta. Formato:
`fecha · club vs rival · postura · carta → carta → carta · resultado · nota`.
Los playtests completos siguen yendo a `docs/playtests/`.

_Sin entradas todavía._
