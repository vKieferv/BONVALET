# T-17 · Mazo de inicio nuevo y primeras cartas v2

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario** (necesita pantalla para las
capturas de las cartas nuevas).

- **Hito:** M2
- **Rama:** `tarea/t-17-mazo-nuevo`
- **Decisiones / ideas:** **D-45** (el mazo y las cartas v2), **D-47** (ajustes a los duelos), D-38 y D-39 (cartas
  v2, regla del 4%), D-44 y D-48 (defensa y desenlaces). Diseño de las cartas: `docs/cartas.md`, secciones
  "Cartas v2" y "Ajustes al partido de duelos (D-47)".
- **Requisitos:** T-15 y T-16 mezcladas (ya lo están).

## Objetivo
El mazo con que arranca cada club pasa a ser el de D-45, y entra la **primera tanda** de cartas v2: las que el
motor de duelos ya puede jugar **sin mecánicas nuevas**. Las que necesitan reglas nuevas quedan para T-18.
Al terminar, hay una medición de goles por etapa con el mazo nuevo (la que espera la curva de la temporada).

## Alcance
1. **Mazo estándar nuevo** (`data/decks.json`): 2 Pase corto, 1 Pase al pie, 1 Pase largo, 1 Amague, 1 Promesa:
   Control, 2 Remate simple, 1 Presión, 1 Intercepción, 1 Bloqueo y la carta de rasgo del DT (12 en total).
   "Pase largo" no existe hoy: usa el **Pelotazo** si calza (avanza 2); si no, créalo y anótalo en el informe.
2. **Cartas v2 de la primera tanda** (`data/cards.json`): de cada estilo, solo las cuyo efecto ya existe
   (`steps`, `draw`, `counter`, `effect`, `back`, `long_range`, marcas del motor) o se traduce con D-47; por
   ejemplo Segunda pelota, Hacer tiempo, Recuperar arriba, Salida en velocidad, Saque largo del arquero,
   Taco, Pique largo y **Descarga** (0 PA, ATRÁS, ROBA 1). Cada una con su "+" cuando sea simple. Si una
   carta necesita una mecánica que no existe, **no la hagas**: anótala en una lista para T-18.
3. **Cómo se ofrecen:** reemplazan el `crecimiento` y las `ofertas` de hoy según su estilo (D-45 regla 2);
   las genéricas que ya existen siguen en la oferta "general".
4. **Regla del 4% (D-39):** cada carta nueva se mide agregando 1 copia al mazo de todos los equipos con
   `balance-lab`; si los goles suben más de 4% sobre el tope (2,6), se encarece o se le pone condición.
5. **Medición** (`balance-lab`, modo de duelos, 400 partidos por cruce): goles al inicio, a mitad y al final de
   la temporada, lesiones, cortes por lado, robos, contragolpes, jerarquía por estilo y los desenlaces de D-48
   (divididas, laterales, faltas, córners). Antes (mazo de hoy) y después (mazo nuevo), en una tabla.
6. **Pruebas:** `data_rules` (mazo de 12, ids existentes, cada carta con su estilo), `engine_rules` para
   cada efecto nuevo, `smoke_career` y `smoke_match` con el mazo nuevo.
7. **Láminas:** captura de 3 cartas nuevas con el estilo de `director-arte-2006` (sin dibujar las que no
   pasaron la regla del 4%, D-39).

## Fuera de alcance
- Mecánicas nuevas del motor (+1 ATACANTE libre, UNA VEZ, AL TOQUE, INSTRUCCIÓN, +PA): T-18.
- Las jugadas de crack por perfil de jugador y su Ejecutor Natural: T-18.
- Cambiar la curva de la temporada o el cansancio: se decide **con** esta medición, después.
- Pantalla del partido y semana (ya pulidas en T-11 y T-16).

## Definición de terminado
- [ ] `godot-check` en verde y `-Balance` con la nueva línea base anotada en `docs/arquitectura.md`.
- [ ] Tabla de medición antes y después, con la regla del 4% por carta.
- [ ] Lista de las cartas v2 que **no** entraron y qué mecánica les falta (insumo de T-18).
- [ ] Capturas de las cartas nuevas en `C:\Users\vicen\Desktop\bonvalet\capturas-t17\` e `informe.md`.
- [ ] Rama subida; sin PR ni mezcla.

## Preguntas abiertas
- Si el mazo nuevo deja los goles fuera de 2,3-2,6, ajusta solo los valores de las cartas nuevas y anota qué
  cambiaste. No toques reglas del motor.
- Cualquier otra duda de diseño: opción conservadora y nota en el informe.
