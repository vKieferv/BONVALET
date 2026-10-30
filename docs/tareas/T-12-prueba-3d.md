# T-12 · Prueba técnica: cancha 3D low poly

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario**: necesita ver la
pantalla para sacar capturas y medir los cuadros por segundo.

- **Hito:** antes de T-11
- **Rama:** `tarea/t-12-prueba-3d`
- **Ideas / decisiones relacionadas:** I-54 (3D), D-35 (TV 2006, sin caras), D-37 (concepto visual),
  D-40 (el portador y las marcas). Análisis y motivo: `docs/sts-futbol.md`, sección 3. Maqueta a
  imitar: lienzo "Dirección visual", fila **v5** (https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm).

## Objetivo
Saber, con capturas y números, si la cancha del partido puede ser 3D de pocos polígonos (estilo
Unturned: jugadores poco detallados pero distinguibles) sin que el arte se coma el proyecto. Es una
prueba: no se conecta al partido real.

## Alcance
- **Escena aparte**, por ejemplo `scenes/prueba_3d/prueba_3d.tscn` (+ sus `.gd`), que se abre sola:
  un `Control` de 1280×720 con un `SubViewportContainer` arriba (la cancha 3D, el alto de la señal de TV
  en v5) y, abajo, 3 o 4 láminas de `CardUI` estáticas para ver cómo conviven 3D y 2D.
- **Jugador low poly hecho en código** (prismas y cajas, `ArrayMesh` o `CSG`), sin cara (D-35):
  cabeza, pelo, camiseta, short, medias, botas, con sombreado plano (facetas visibles). Los colores
  salen del club (`LeagueManager.team_colors`) con un material por parte. **No se descargan modelos
  ni texturas de internet** en esta prueba; si el resultado pide un paquete de modelos, se anota como
  propuesta para que el usuario lo elija.
- **Una zona del Medio**, como en v5: Colo-Colo (blanco y negro) contra U. de Chile (azul), 8
  jugadores (Aceval con la pelota en la Salida, Vidal, Sánchez, Fernández y Meléndez en el Medio;
  Salas, Candelo, Iturra y Díaz marcando). Pasto con franjas, líneas, el telestrador amarillo de la
  zona y su nombre pintado, carteles parodia (Cerveza Glaciar, Telnet, Diario El Chisme).
- **Cámara de TV**: alta y de costado, en perspectiva, que se mueve suave siguiendo la pelota.
- **Animación mínima por código**: respirar quieto, correr (piernas que se balancean), y un pase: la
  pelota viaja en arco de Aceval a Fernández y la cámara la sigue. Las marcas se ven como en v5 (puntos
  del color del rival junto al jugador, "LIBRE" en verde), en 2D sobre la cancha o con `Label3D`.
- **Script de captura**, como `tools/capturas.gd`: guarda 3 imágenes (antes del pase, la pelota en el
  aire, Fernández recibiendo) e imprime los cuadros por segundo promedio de 10 segundos de pase en loop,
  con el renderizador del proyecto (Forward+) y, si se puede, con Compatibility.
- Usa la skill `director-arte-2006` para colores y letras.

## Fuera de alcance
- `core/`, `match_view`, `calendar_view`, `data/` y las reglas: no se tocan.
- Modelos de jugadores reales, caras, escudos o marcas reales.
- Animaciones de remate, barrida o celebración (se estiman, no se hacen).

## Definición de terminado
- [ ] `godot-check` en verde (los scripts nuevos compilan).
- [ ] Las 3 capturas en una carpeta fuera del repo, comparadas con la maqueta v5 (qué se ve mejor y
      qué peor: lectura de las marcas, del portador y de las zonas a 1280×720).
- [ ] Cuadros por segundo medidos (y en qué equipo).
- [ ] Rama subida (`git push -u origin tarea/t-12-prueba-3d`). No se mezcla a `main`.
- [ ] Un informe corto con la recomendación: **3D sí o no para T-11**, cuánto costaría el arte que
      falta (remate, barrida, celebración, arquero, uniformes de los 20 clubes) y los riesgos.

## Preguntas abiertas
Si el jugador hecho en código se ve mal, no se fuerza: se dice en el informe y se proponen opciones
(paquete de modelos con licencia libre, otro estilo, quedarse en 2D).
