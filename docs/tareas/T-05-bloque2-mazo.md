# T-05 · Bloque 2: carta nueva, sesión de video o kinesiología, con mazo propio guardado

Brief para una sesión autónoma (skill `tarea-autonoma`). **Depende de T-04** (mazo estándar,
catálogo y `decks.json`): no la lances hasta que T-04 esté mezclada.

- **Hito:** M2
- **Rama:** `tarea/t-05-bloque2-mazo`
- **Decisiones:** D-20 (elegir 1 de 3; si el mazo está en su tope, la nueva reemplaza a otra), D-21
  (Bloque 2 = carta, video o kinesiología), D-23 (mazo estándar)

## Objetivo
Que tu mazo sea tuyo y crezca: empieza con el mazo estándar de tu club y cada semana, en el Bloque 2,
eliges UNA de tres opciones: **entrenamiento táctico** (te ofrecen 3 cartas y te quedas con una),
**sesión de video** (mejoras una carta) o **kinesiología** (−25 de fatiga). El mazo se guarda con la
carrera.

## Alcance
1. **`Career` guarda tu mazo:** `deck` = lista de entradas `{"id": String, "mejora": ""|"acierto"|"pa"}`,
   que se inicializa con el mazo de inicio de tu club (constructor de T-04). `build_deck()` arma el mazo
   del partido desde esas entradas y sigue pasando por `SquadManager` (Promesas a Sub-21 y firmas de los
   titulares). Una carta mejorada lleva "+" al final del nombre ("Remate simple+").
2. **Ofertas del entrenamiento táctico** (`decks.json`, clave nueva `"ofertas"`): una lista por
   arquetipo y una `"general"`. Valores iniciales: la lista de cada arquetipo = las cartas de su
   `crecimiento` (sin repetir); `"general"` = `pase_filtrado, amague, centro, tiro_lejano, chilena,
   remate_primera, presion, bloqueo, intercepcion, despeje, pase_al_pie, pausa, movimiento`. Cada oferta
   son 3 cartas distintas: 2 de tu estilo + 1 general, con el `rng` de la carrera (determinista por
   semilla). La carta de rasgo nunca se ofrece. Se puede ofrecer una carta que ya tienes (segunda copia).
   La oferta se genera al abrir el Bloque 2 y **se guarda** (`training_offer`), para que recargar no
   cambie las opciones.
3. **Elegir la carta:** se agrega al mazo. Si el mazo ya tiene 20 cartas (`DeckManager.DECK_MAX`), hay que
   elegir cuál sale (reemplazo). Se puede no tomar ninguna; igual cuenta como el Bloque 2 de la semana.
4. **Sesión de video:** eliges una carta sin mejora y una mejora: **acierto** (+10 pts al bono) o **PA**
   (−1 PA, solo si cuesta 1 o más). Una mejora por carta. El motor no cambia: la mejora se aplica al
   construir la carta (`bonus` + 0.10 o `ap` − 1).
5. **`data/career_2006.json` → `"training"`:** `tactical` deja de dar forma (+3%, D-21) y conserva la
   fatiga +10; agrega `video` (fatiga 0); `physio` igual (−25). Saca el `form_bonus` del flujo de la
   semana (`prepare_match`/`configure_match`) si queda sin uso; el motor puede conservar `form_bonus`.
6. **Interfaz del calendario (Bloque 2):** tres botones (táctico, video, kinesiología) con sus términos
   (fatiga resultante y mano, como hoy). Táctico muestra las 3 cartas ofrecidas (reutiliza `CardUI` o
   una vista simple con nombre, PA, % y efecto) y, si hace falta, la lista para elegir cuál sale. Video
   muestra tu mazo para elegir carta y mejora. Agrega un **"Ver mazo"** con tu mazo actual (cartas,
   mejoras, tamaño).
7. **Guardado:** suma `deck` y `training_offer` a `to_dict`, `SAVE_FIELDS` y `load_saved` (ver CLAUDE.md,
   "Guardado de la carrera"). Sube `SAVE_VERSION` a 2 y **migra** los guardados v1 (mazo = el de inicio
   del club, oferta nueva) en vez de rechazarlos.
8. **Pruebas:** `career_rules`: la oferta es determinista por semilla, tiene 3 cartas distintas de las
   listas correctas y sin el rasgo; elegir agrega; con 20 cartas obliga a reemplazar; las dos mejoras
   cambian la carta construida (+0.10 / −1 PA) y no se puede mejorar dos veces; ida y vuelta del guardado
   con mazo y oferta; un guardado v1 se migra. `smoke_career`: la semana 1 toma una carta y la semana 2
   va a kinesiología, y "Continuar" recupera el mazo con la carta nueva.
9. **Documentación:** `CLAUDE.md` (Modo carrera, Guardado) y GDD 3.4 y 5.1.

## Fuera de alcance
- El crecimiento de los rivales (T-06) y el balance de la matriz (no cambia: los bots no usan el Bloque 2).
- Números de cartas, listas de `crecimiento` y constantes del motor.
- Progresión de canteranos (I-05) y Modo Copa (I-34).

## Definición de terminado
- [ ] `godot-check` en verde. `-Balance` no hace falta (la matriz no cambia); si lo corres, debe dar lo
      mismo que tras T-04.
- [ ] Pruebas del punto 8 en verde.
- [ ] PR con: qué cambia para el jugador, capturas o descripción de la pantalla del Bloque 2 y de "Ver
      mazo", y lo que quedó sin verificar en pantalla.

## Preguntas abiertas
- Fatiga de la sesión de video (0) y del táctico (+10): valores iniciales; anótalo si en las pruebas se
  siente que el video no tiene costo.
- Si al reemplazar una carta conviene impedir sacar la de rasgo o las Promesas (regla de 2 Sub-21),
  propón la regla en el PR; por defecto, `validate_deck` del Bloque 3 ya avisa si el mazo no cumple.
