# T-18 · El triángulo de estilos (piedra-papel-tijera)

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario** (necesita pantalla para las
capturas).

- **Hito:** M2
- **Rama:** `tarea/t-18-triangulo-estilos`
- **Decisiones / ideas:** **D-49** (las reglas de esta tarea), D-23 (estilos y cartas de rasgo), D-40 a D-43
  (duelos), D-44 (defensa). Estilos del motor: `MatchEngine.mark_style`.
- **Requisitos:** T-15 y T-16 mezcladas (ya lo están). **No dependas de T-17**: está a medias y sin commit en su
  rama; arranca desde `main`.

## Objetivo
Elegir el estilo contra el rival importa: **Tiki-Taka vence a Catenaccio, Catenaccio vence a Contragolpe y
Contragolpe vence a Tiki-Taka** (D-49). Se ve en la previa, en la cuenta de cada carta y en el resultado, sin
sumar ningún número nuevo que marée. Directo y Kamikaze quedan fuera.

## Alcance
1. **Tabla de ventajas** (`data/`, no en el código): quién vence a quién, con el valor `N` (de partida 6) y un
   interruptor para apagarlo (`style_edge` en el motor; apagado = el partido de hoy, idéntico).
2. **Motor** (`MatchEngine`): una línea **"Ventaja de estilo"** dentro de `chance_breakdown` (y solo ahí: la
   probabilidad sale únicamente de esa función): +N en las jugadas del equipo con ventaja y −N en las del que
   la sufre, solo cuando el rival es uno de los tres estilos del triángulo. Con cualquier otro estilo, 0.
3. **Bots** (`CoachBot`, `DuelRunner`): la ventaja ya entra por `chance_breakdown`, así que deberían usarla
   solos; comprueba que los planes del bot no la ignoran.
4. **Previa** (`scenes/partido/previa_tv.gd`): al elegir rival se lee "Contragolpe · te conviene Catenaccio" o,
   si no hay ventaja, nada. En la carrera, lo mismo en la semana junto al rival de la fecha.
5. **Cuenta de la carta** (`PantallaDuelos.cuenta_de`): la línea "Ventaja de estilo +6" o "−6" aparece con el
   desglose, como cualquier otra. Sin texto nuevo en la lámina.
6. **Medición liviana** (sin simular todos los cruces): solo los **tres cruces del triángulo** y sus tres
   inversos, con el mazo de hoy y 150 partidos por cruce, en el modo de duelos. Queremos ver que el que tiene
   ventaja gane claramente más (de partida, entre 55% y 65% de los puntos) sin que los goles totales salgan de
   2,3-2,6. Si no, ajusta solo `N`. No midas otros estilos ni la temporada.
7. **Pruebas:** `engine_rules` (la línea aparece solo con ventaja, es simétrica, apagada = igual que hoy) y
   `data_rules` (la tabla es un triángulo cerrado: cada estilo vence a uno y pierde con otro).

## Fuera de alcance
- Directo y Kamikaze, y el mazo nuevo (T-17).
- Cartas nuevas, cambios de balance de las cartas existentes, cansancio y curva de la temporada.
- Mediciones largas de temporada o de todos los cruces: el usuario pidió **no simular cruces** de más.

## Definición de terminado
- [ ] `godot-check` en verde; con la ventaja apagada, `-Balance` igual que `main`.
- [ ] Tabla de los 6 cruces (con y sin ventaja) con el valor final de `N`.
- [ ] Capturas en `C:\Users\vicen\Desktop\bonvalet\capturas-t18\`: la previa con la recomendación y la cuenta de
      una carta con la línea de ventaja.
- [ ] `docs/arquitectura.md` actualizado e `informe.md` con lo que quedó sin verificar.
- [ ] Rama subida; sin PR ni mezcla.

## Preguntas abiertas
- Si la ventaja se nota poco o demasiado con `N` = 6, ajusta solo `N` y anótalo.
- Cualquier otra duda de diseño: opción conservadora y nota en el informe.
