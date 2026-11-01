# T-13 · Motor de D-40: portador, marcas y habilidades

Brief para una sesión autónoma (skill `tarea-autonoma`). No necesita ver la pantalla: puede correr sin
ventana. La pantalla es T-11.

- **Hito:** M2
- **Rama:** `tarea/t-13-motor-portador-marcas`
- **Decisiones / ideas:** **D-40** (las reglas de esta tarea), D-29 y D-32 (habilidades y fórmula), D-30
  (formaciones), D-31 (duelos), D-36 (zonas), I-45, I-61. Detalle: `docs/cartas.md`, secciones "Pase con
  marcas" y "Habilidades de los jugadores". Ejemplos con números: la tabla de "Pase con marcas".
- **Requisitos:** T-10 mezclada (modo de zonas). La escena `scenes/prueba_3d/` trae los mismos % de muestra
  a mano: sirve para comparar, pero no se toca.

## Objetivo
Que el motor tenga un **modo de duelos**, encima del modo de zonas y apagado por defecto: las cartas las
juega el que tiene la pelota, el pase elige receptor, la IA del rival reparte marcas y se enfrentan las
habilidades. Los bots lo juegan y `balance-lab` lo mide. **Con el modo apagado, nada cambia.**

## Alcance
1. **Habilidades por jugador** (`SquadManager` o un script nuevo en `scripts/`): Pase, Regate, Remate, Quite,
   Lectura y Atajada = `skill_rating` + ajuste del puesto + perfil (+6), tope 95, con la tabla de D-32. Los
   perfiles van en un archivo chico nuevo, `data/perfiles_2006.json`, solo con los de `cartas.md` (Fernández
   Gambeteador, Suazo Goleador, Bravo Atajador); los demás quedan sin perfil. El resto es decisión del usuario.
2. **Modo de duelos en `MatchEngine`** (un campo, por ejemplo `duel_mode`, que exige `zone_mode`). Los
   jugadores entran como datos simples, sin que `core/` dependa de `scripts/`.
   - **Portador:** el Momento arranca con el de la Salida que elija quien juega; el contragolpe, en el Medio.
     Se expone quién es, sus habilidades y sus marcadores.
   - **Pase con receptor:** `play_card` recibe un receptor (parámetro opcional). Un pase exige un compañero de
     la zona siguiente; si sale, él es el nuevo portador. `can_play` y `success_chance` aceptan el receptor,
     para que el % de cada opción se pueda mostrar antes de jugar.
   - **Marcas:** `CoachBot` las reparte según el estilo del rival, sobre los jugadores de cada zona de su
     formación (D-30): la mejor de tus figuras recibe más marca, y cada estilo reparte a su manera. Se
     reparten al entrar a una zona y al volver atrás. Es determinista dado el RNG y se puede leer antes de jugar.
   - **Duelos en `chance_breakdown`** (nunca directo en la tirada), con la línea escrita para el desglose:
     - Base fija 39 + carta + 0,5 × (habilidad tuya − la suya) + marcas. Reemplaza técnica, dificultad rival y
       fuerza de línea. Apertura, Entrenamiento y el resto de los modificadores siguen.
     - Pase: Pase del portador contra la Lectura del mejor marcador del receptor.
     - Regate y control: Regate del portador contra el Quite de su mejor marcador. Si sale, sigue con la pelota.
     - Remate: Remate del portador contra la Atajada del arquero.
     - Marcas: libre +12, 1 contra 1 = 0, 1 contra 2 = −12 (cada marcador extra, −12).
     - Ejecutor Natural: solo si la carta es del portador, +5 (D-32).
   - **Volver atrás solo con cartas:** campo de carta nuevo (por ejemplo `"atras": true`): la pelota vuelve a la
     zona anterior y el rival reparte de nuevo. Se prueba con una carta en `engine_rules` y en
     `tests/lab/`, **sin agregarla a los mazos** (eso es la revisión de mazos, D-39 regla 8).
3. **Bots (`CoachBot`):** eligen carta y receptor con su % y su riesgo de robo. Sin esto la medición no sirve.
4. **`DuelRunner`, `SimRunner`, `sim.gd`:** pasan el modo y los datos. `match_view` no cambia.
5. **Medición (`balance-lab`, `tests/lab/duelos.json`):** zonas contra duelos y, dentro de duelos: 0,5 contra
   0,25 por punto; 12 contra 6 pts por marca; remates con −10 de bono (propuesta de `cartas.md`); las dos
   reglas del Pelotazo (ver preguntas). Por variante: goles (inicio, mitad, final), lesiones, cansancio 1T/2T,
   robos y contragolpes, Momentos sin cartas, constructibilidad, jerarquía entre clubes y **cuánto se reparte el
   balón** (toques por jugador). Corre también `tests/lab/medir_rival.gd`.
6. **Ajuste:** si queda fuera de 2,3-2,6 goles al inicio, se ajustan solo los valores nuevos de este modo. Si no
   se llega, se reporta y no se fuerza.
7. **Pruebas en `engine_rules.gd`** para cada regla, incluida la tabla de "Pase con marcas" como ejemplo exacto
   (Aceval a Fernández con Pase corto = 29%, a Vidal = 57%, a Sánchez = 45%), y que el % mostrado sea el que se tira.

## Fuera de alcance
- La pantalla, el arrastre y la 3D (T-11). La forma de la trayectoria no cambia el % (I-63).
- Cansancio por jugador (D-31 regla 6, I-59): sigue la estamina del equipo. Cartas v2, cambios (I-62).
- La defensa sigue como en T-10: sus cartas no usan aún Quite ni Lectura. Anótalo en el informe.
- Cambiar el modo actual, el de zonas o sus constantes.

## Definición de terminado
- [ ] `godot-check -Balance` en verde; con el modo apagado, la matriz igual a la línea base (2.50 / 2.75 / 2.68).
- [ ] Tabla de `balance-lab` con todas las variantes del punto 5.
- [ ] Pruebas nuevas en `engine_rules.gd`.
- [ ] `docs/arquitectura.md` y `docs/gdd.md` (modo en prueba) actualizados.
- [ ] Rama subida e informe con recomendación de valores y lo que quedó sin verificar.

## Preguntas abiertas (para el usuario; se mide con la opción conservadora y se anota)
- **Pelotazo y marcas:** sin duelo. T-12 usó "libre no suma, doble marca resta". Alternativa: las marcas no
  cuentan, porque salta la línea. Medir las dos.
- **Regate al entrar a otra zona:** el portador llega sin un lugar en esa línea. Conservadora: el rival vuelve a
  repartir contándolo a él.
- **Carta firma de otro jugador:** la juega el portador, sin Ejecutor Natural. ¿O solo se puede jugar si la tiene
  su dueño? Conservadora: se juega sin bono.
- Cualquier otra duda de diseño: no se inventa; opción conservadora y nota en el informe.
