# Informe T-15 · La defensa nueva: el ataque al revés (D-44)

Rama `tarea/t-15-defensa-nueva` (subida, sin PR ni mezcla a `main`). Parte de `main` 0716d82.

## Qué cambió (lo que ve el jugador)
- **Cuando ataca el rival, ya no solo miras.** Antes de cada jugada suya aparece arriba lo que va a hacer:
  "VA A JUGAR UCH · SARTORI: PASE CORTO a DROGUETT · 38%". Junto al que recibe (o al que va a rematar) hay
  una placa con su %, y se ve la línea de su pase.
- **Defiendes arrastrando una lámina sobre un rival**, como el pase:
  - **Presión (o Marca)** sobre el que tiene la pelota: tu Quite contra su Regate. Si sale, su jugada pierde 12.
  - **Intercepción** sobre la línea de su pase (o el que recibe): tu Lectura contra su Pase. Si sale, cortas y sales de contragolpe.
  - **Bloqueo** sobre el que va a rematar: tu Quite contra su Remate. Si sale, su remate pierde 12.
  - **Despeje**, **Despeje de emergencia** y **DEJAR PASAR** siguen; DEJAR PASAR ahora deja pasar **solo esa jugada**.
- **La juega tu defensor más cercano**: el que marca a ese rival (el mejor de ellos para esa carta). Mientras
  arrastras, tu defensor se ve con un anillo del color de tu % y la placa pasa a tu %: "MARCA · RIFFO 43%".
  La tirada dice quién y sobre quién: "MARCA · SUAZO sobre SARTORI".
- Las láminas que no sirven contra la jugada anunciada dicen **NO SIRVE AHORA** y no muestran %.
- **El rival también te defiende así**: cuando sueltas una lámina, puede presionarte o cortarte; ves su
  tirada y después la tuya, con el % ya restado.
- Tus marcas sobre los rivales se ven en la cancha (los puntos de cada etiqueta), igual que las del rival.
- Con el modo de duelos apagado (zonas o actual) **no cambia nada**.

## Medición (balance-lab, 400 partidos por cruce, modo de duelos)
"Cortes" = ataques cortados por partido, sumando los dos equipos.

| Etapa | Goles antes | Goles después | Lesiones antes → después | Cortes antes → después | Robos | Contragolpes |
|---|---|---|---|---|---|---|
| Inicio | 2,36 | **2,38** | 3,7% → 2,8% | ~1,9 → 2,14 | 1,33 → 1,36 | 1,28 → 1,37 |
| Mitad (+4) | 2,68 | **2,63** | 4,5% → 3,6% | ~1,6 → 2,00 | 1,22 → 1,20 | 1,23 → 1,26 |
| Final (+8) | 2,60 | **2,61** | 3,6% → 3,9% | ~1,7 → 1,77 | 1,18 → 1,21 | 1,26 → 1,28 |

(Los cortes de "antes" salen de sumar los cortes por club; el laboratorio viejo no daba el total.)

**Jerarquía por estilo (inicio, goles a favor-en contra):**

| Club | Antes | Después |
|---|---|---|
| Colo-Colo (Tiki-Taka) | 1,54-0,76 | 1,50-0,89 |
| Palestino (Catenaccio) | 0,70-1,17 | 0,71-1,21 |
| U. Católica (Contragolpe) | 1,37-1,03 | 1,45-1,01 |
| Cobreloa (Directo) | 1,01-1,00 | 1,06-0,94 |
| La Serena (Kamikaze) | 1,29-1,94 | 1,23-1,90 |
| U. de Chile contra la matriz | 1,31-1,07 | 1,31-1,05 |

El orden no cambia. Palestino sigue último.

**`medir_rival.gd --duelos` (Colo-Colo contra cada club de Primera A, 100 partidos por rival):**

| | Antes | Después |
|---|---|---|
| Tus cortes al rival por partido | 0,01 | 0,08 |
| Cortes del rival a ti por partido | 0,86 | 0,96 |
| Acierto de tu defensa (mostrado / real) | 43% / 42% | 51% / 49% |
| Goles tú - él | 1,58-0,76 | 1,54-0,89 |
| Tus robos con contragolpe | 1,67 | 1,47 |

Ojo: en `medir_rival` tu equipo lo juega un bot, no tú. El bot casi nunca corta porque su mazo de inicio solo
tiene Marca y Despeje, y elige la Marca. Tú, con la pantalla nueva, decides cuándo usar el Despeje.

**Modo apagado:** `core/sim.gd` (la medición oficial de `godot-check -Balance`) da exactamente lo mismo que en
`main` (inicio 2,50, mitad 2,75, final 2,68 goles; mitad y final ya estaban fuera de rango en `main`). Las reglas, la
compilación y las mediciones pasan. En la última corrida (8 de noviembre) `smoke_match` falló una vez con "Nunca se
revisó la línea del partido por zonas": un partido por zonas en que no alcanzaste a jugar ninguna carta (el partido
tiene semilla al azar). Repetida dos veces, pasó sin errores. Ese camino (modo por zonas) no lo toca esta tarea.

## Lo que quedó
- Motor (`MatchEngine`): defensa jugada a jugada, defensor más cercano y los duelos de la defensa dentro de
  `chance_breakdown`. Lo que le restas al rival aparece en su desglose, así que lo que muestra la placa es lo que se tira.
- Bots (`CoachBot`, `DuelRunner`, `medir_rival`): anuncian su jugada y defienden igual que tú (una carta como mucho por jugada).
- Pantalla: intención, placa, línea del pase, defensor resaltado, tirada de defensa y defensa del rival en tu ataque.
- Pruebas: `engine_rules` (reglas nuevas) y `smoke_match`, que defiende **arrastrando** Presión, Intercepción y
  Bloqueo y compara intención, placa y tirada con el motor.
- `docs/arquitectura.md` actualizado. Capturas en esta carpeta: `t15_1_intencion`, `t15_2_presion`,
  `t15_3_intercepcion`, `t15_4_bloqueo` y `t15_5_tirada_defensa` (y las de T-11 retomadas).
- Herramienta: `tools/partido_duelos_captura.gd -- --defensa`.

## Decisiones conservadoras que tomé (para que las revises)
1. **Sin defensor que lo marque:** juega el de tu línea en esa zona con mejor habilidad para esa carta (si no hay
   nadie, el mejor de campo). No le puse castigo por llegar sin marca.
2. **Valores de prueba:** la Presión resta su efecto de hoy ×2 (6 → 12) a una sola jugada; el Bloqueo, su efecto
   ×1 (12) al remate. No los ajusté: los goles quedaron igual que antes.
3. **La defensa no paga la dificultad del ataque rival.** Su calidad ya entra por sus habilidades.
4. **Contra "aguantar el balón"** solo sirve el Despeje.
5. **Si no tienes con qué defender**, la jugada se ve medio segundo y sigue sola. Contra un remate espera,
   por si quieres el Despeje de emergencia.
6. **Los bots** defienden con una carta como mucho por jugada (heurística, no regla). Tú puedes jugar varias si te alcanzan los PA.
7. **Un clic** (sin arrastrar) en una lámina de defensa la juega sobre el único rival al que sirve.

## Lo que no quedó o quedó sin verificar
- **Goles en mitad y final:** 2,63 y 2,61, apenas sobre el tope de 2,6. Ya estaban fuera antes (2,68 y 2,60) y la
  defensa nueva no los empeora. No ajusté nada; decide si quieres subir la Presión para bajarlos.
- **Cortes:** con bots, ahora cortan algo más los dos lados. El desequilibrio del playtest (el rival te corta
  ~0,9 y tú casi nada) sigue en `medir_rival` porque ahí tu equipo es un bot con Marca y Despeje. No hay
  medición de cuánto cortas tú jugando con el mouse.
- **No lo jugó una persona.** Solo hay mouse simulado (smoke_match y capturas). Falta un playtest para saber si
  defender cada jugada se siente bien o se hace largo de otra forma (antes era mirar y ahora es decidir).
- El arte usa las gráficas y placas de T-11. La línea del pase del rival es blanca: un color por equipo queda para después.
- El mazo nuevo y las cartas v2 (D-45, D-47) siguen fuera: las cartas de Presión, Intercepción y Bloqueo
  casi no aparecen en el mazo de inicio de hoy (trae 2 Marca y 1 Despeje).
- El "Momentos por equipo" del laboratorio subió de ~3 a ~3,9 porque ahora un ataque cortado a mitad cuenta como
  Momento jugado (antes el corte llegaba antes de empezarlo). No es un cambio de ritmo.
