# T-15 · La defensa nueva: el ataque al revés (D-44)

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario**: necesita pantalla para
las capturas y la prueba con mouse simulado.

- **Hito:** M2
- **Rama:** `tarea/t-15-defensa-nueva`
- **Decisiones / ideas:** **D-44** (las reglas de esta tarea), D-40 a D-43 y D-46 (el modo de duelos), D-36
  (zonas, robo), I-41 (intención del rival), I-60 (su ataque se mira). Playtest: `docs/playtests/2026-11-04-partido-duelos.md`
  ("se hace largo, pero es porque solo vemos sus acciones").
- **Requisitos:** T-11 mezclada (`match_view` de duelos, cancha 3D, `tests/mouse_duelos.gd`).

## Objetivo
En el modo de duelos, el ataque del rival deja de ser algo que miras: ves su intención antes de cada jugada y
lo frenas arrastrando una carta de defensa sobre un rival, como el pase. Con el modo apagado, nada cambia.

## Alcance
1. **Tus marcas.** Tu equipo reparte marcas sobre los rivales de cada zona, igual que el rival lo hace
   contigo (por tu estilo, con la misma lógica de `CoachBot`). Se ven en la cancha.
2. **Intención del rival (D-44 regla 3).** Antes de cada jugada del rival se ve qué va a hacer: quién tiene la
   pelota, a quién pasa o si regatea o remata, y su %. El bot decide su jugada primero, la anuncia y espera tu
   respuesta.
3. **Defender arrastrando (D-44 reglas 1 y 2).** Con tus PA de defensa, arrastras una carta sobre un rival y la
   juega **tu defensor más cercano** a él (el que lo marca; si nadie, el más cercano de esa zona):
   - **Presión** sobre el portador: tu Quite contra su Regate. Si sale, su jugada anunciada pierde %.
   - **Intercepción** sobre la línea de su pase: tu Lectura contra su Pase. Si sale, cortas y recuperas.
   - **Bloqueo** sobre el que va a rematar: tu Quite contra su Remate. Si sale, su remate pierde %.
   - **Despeje** y **Despeje de emergencia**: como hoy. **Dejar pasar** también.
   Todo en `chance_breakdown` con su línea; lo que muestra la placa junto al rival es lo que se tira.
   Los valores (cuánto resta la Presión o el Bloqueo) son de prueba, cerca de los de hoy.
4. **Los bots defienden igual** (`CoachBot`, `DuelRunner`) para que la medición represente el juego.
5. **Pantalla:** la placa de % junto al rival apuntado, la línea de su pase visible para interceptar, tu
   defensor resaltado y la tirada como en el ataque. Lo demás del ataque rival sigue rápido (T-11).
6. **Medición (`balance-lab`):** duelos antes y después. Goles (inicio, mitad, final), cortes por partido de
   cada lado (hoy el rival te corta ~0,95 y tú ~0,02), robos y contragolpes, jerarquía por estilo y
   `medir_rival.gd --duelos`. Si los goles salen de 2,3-2,6, se ajustan solo los valores nuevos.
7. **Pruebas:** reglas en `engine_rules`; `mouse_duelos` defiende arrastrando (presión, intercepción y
   bloqueo) y compara lo mostrado con el motor.

## Fuera de alcance
- El mazo nuevo y las cartas v2 (D-45, D-47): otra tarea. Usa las cartas de defensa que ya existen.
- El modo actual y el de zonas, y su línea base.
- Cansancio por jugador.

## Definición de terminado
- [ ] `godot-check -Balance` en verde; con el modo apagado, igual a la línea base.
- [ ] Tabla de medición antes y después.
- [ ] Capturas en `C:\Users\vicen\Desktop\bonvalet\capturas-t15\`: intención del rival, presión, intercepción,
      bloqueo y una tirada de defensa.
- [ ] `docs/arquitectura.md` actualizado.
- [ ] Rama subida e informe con lo que quedó sin verificar.

## Preguntas abiertas
- Si una jugada del rival no tiene un defensor tuyo cerca, toma la opción más simple (el de esa zona con
  mejor habilidad para esa carta) y anótalo.
- Cualquier otra duda de diseño: opción conservadora y nota en el informe.
