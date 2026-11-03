# Eventos de la semana (I-57, borrador 2026-11-02)

Hoy el juego tiene un solo evento (Bautizazo en Bellavista) y el código solo sabe hacer "fiesta con riesgo
de funa". Este documento es el catálogo a programar. El usuario aprobó el tono, con dos pedidos:

- **Humor que se entienda fuera de Chile:** la ambientación es chilena (clubes, ciudades, 2006), pero el
  chiste no depende de modismos locales. Nada de jerga que haya que explicar.
- **Más diarios y más tipos de preguntas, y que las historias se ramifiquen.**

Los nombres entre corchetes (`[tu 9]`, `[el capitán]`, `[el rival]`) los llena el juego con el plantel real,
como hoy pasa con el funado. Las marcas y los medios son siempre parodias (D-01).

## 1. Cómo funciona
- **Mazo de eventos:** se baraja al empezar la temporada y no se repite hasta que salgan todos. Algunos
  solo entran si se cumple una condición (por ejemplo, "después de una derrota" o "antes de un clásico").
- **2 o 3 opciones por evento,** cada una con sus efectos a la vista antes de elegir (pilar 2).
- **Ramas:** una opción puede dejar una marca que hace volver la historia N semanas después, con otro
  evento. Las ramas son las que dan memoria a la temporada: lo que prometes se cobra.

**Efectos posibles** (lista corta; casi todos ya existen en la carrera):
| Efecto | Qué hace | ¿Existe hoy? |
|---|---|---|
| Popularidad ± | La relación con los hinchas | Sí |
| Disciplina ± | El orden del plantel | Sí |
| Presupuesto ± | Plata del club | Sí |
| Fatiga ± | Cansancio que arrastra el plantel al partido | Sí |
| Arranque ± | ± % en los primeros Momentos del próximo partido (hoy `opening_bonus`) | Sí, solo positivo |
| Rival motivado | El rival arranca con + % en sus primeros Momentos | No |
| Funa (riesgo) | Un jugador gasta más estamina el próximo partido | Sí |
| Carta temporal | Una carta buena o mala ("Nervios") en tu mazo por una semana | Parcial |
| Promesa | Se cumple o no según el resultado del próximo partido, con premio o castigo | No |
| Vuelve en N semanas | Deja una marca y dispara otro evento de la rama | No |

## 2. Los medios (todos parodia)
Cada medio tiene su personalidad y su tipo de pregunta, así se reconoce quién pregunta.
| Medio | Tipo | Qué le importa | Lo que más mueve |
|---|---|---|---|
| **Diario El Chisme** | Prensa rosa | Fiestas, parejas, escándalos | Disciplina, funas |
| **La Pizarra** | Diario deportivo serio | Táctica, números, tu sistema | Arranque, rival motivado |
| **El Hincha Fiel** | Diario popular de los hinchas | Pasión, rivalidades, "poner huevos" | Popularidad |
| **El Mensajero** | Diario serio y conservador | Dirigencia, plata, escándalos de gestión | Presupuesto, disciplina |
| **Radio Galáctica** | Radio deportiva en vivo | Lo inmediato: la previa, la polémica de hoy | Arranque, popularidad |
| **Televisora Nacional (TN)** | La TV del partido | Entrevistas, matinales, comerciales | Popularidad, presupuesto |

## 3. Tipos de pregunta en conferencia
1. **Provocación al rival** ("¿El rival es un equipo chico?").
2. **Defender o criticar a un jugador tuyo** ("¿[tu 9] está para jugar?").
3. **Táctica:** revelar o esconder tu plan.
4. **Arbitraje:** quejarte o no.
5. **Promesa:** "¿ganan el domingo?".
6. **Dirigencia y plata:** refuerzos, sueldos, el presidente.
7. **Farándula:** la vida privada del plantel.

## 4. Catálogo
**C** = conferencia (una pregunta de un medio). **V** = vestuario. **D** = dirigencia. **H** = hinchas.
**S** = sponsor y TV. Los números son de prueba y se ajustan al medir.

### Conferencias de prensa
| # | Medio · tipo | Evento | Opciones → efectos |
|---|---|---|---|
| C1 | El Hincha Fiel · provocación | "¿[el rival] es un equipo chico?" | Respetarlo (disciplina +2) · Picarlo (popularidad +5, rival motivado +5%) · "Sin comentarios" (popularidad −2) |
| C2 | Radio Galáctica · promesa | "¿Ganan el domingo?" | "Ganamos seguro" (**promesa**: si ganas, popularidad +8; si no, −8) · "Vamos partido a partido" (nada) · "Firmo el empate" (popularidad −3, arranque +3%) |
| C3 | La Pizarra · táctica | "¿Van a salir a presionar o a esperar?" | Contar el plan (popularidad +2, rival motivado +3%) · Mentir con cara seria (disciplina −1, arranque +3%) · "Eso lo ven el domingo" (nada) |
| C4 | El Chisme · jugador | "¿Es cierto que [tu 9] llegó tarde al entrenamiento?" | Defenderlo (disciplina −2, él arranca con +5%) · Reconocerlo (disciplina +3, él con Nervios) · Cambiar de tema hablando del clima (popularidad −1) |
| C5 | Radio Galáctica · arbitraje | "¿Qué opina del árbitro del domingo?" | Quejarse antes (popularidad +3; **rama**: 30% de multa → presupuesto −) · Elogiarlo (nada) · "Lo conozco, es buena persona" (popularidad −2, disciplina +1) |
| C6 | El Mensajero · plata | "¿Le pidió refuerzos al presidente?" | "Sí, y los necesitamos" (popularidad +3; **rama D2**) · "Con este plantel me alcanza" (disciplina +3, popularidad −1) · Mirar al vocero hasta que corte la conferencia (nada) |
| C7 | El Chisme · farándula | "¿Cuál es su relación con la actriz de la teleserie de las 8?" | Desmentir (nada) · No desmentir (popularidad +6, disciplina −3) · Abandonar la sala (popularidad −2; **rama**: El Chisme vuelve en 2 semanas con fotos) |
| C8 | La Pizarra · jugador | "¿Por qué no juega el juvenil?" | "Todavía no está listo" (disciplina +1) · "Este domingo juega" (**carta temporal**: la carta del canterano entra una semana) · "Pregúntele al presidente" (popularidad +2; **rama D3**) |

### Vestuario
| # | Evento | Opciones → efectos |
|---|---|---|
| V1 | **Bautizazo en Bellavista** (el actual): el plantel quiere celebrar el cumpleaños del capitán | Dar permiso (arranque +5%, riesgo de funa 30%) · Concentración en el hotel (disciplina +2, popularidad −2) |
| V2 | **[tu 9] quiere un aumento.** Llega su representante con un maletín y lentes de sol | Pagar (presupuesto −) · Negarse (él juega con Nervios) · Prometer para fin de mes (**rama**: vuelve en 4 semanas; si no pagas, él pide salir) |
| V3 | **Asado en la casa del capitán** | Ir (arranque +3%, fatiga +5) · Mandar saludos (disciplina +1, arranque −2%) |
| V4 | **Lesión misteriosa:** a un titular "le duele algo"; el kinesiólogo levanta una ceja | Creerle (fatiga −10) · Obligarlo a jugar (disciplina +3, riesgo de lesión) · Mandarlo a exámenes (presupuesto −) |
| V5 | **Pelea en el entrenamiento** entre [el capitán] y un recién llegado | Castigar a los dos (disciplina +4, arranque −2%) · Apoyar al capitán (disciplina +2; el nuevo con Nervios) · "Que lo arreglen en la cancha" (riesgo 40%: El Chisme lo publica) |
| V6 | **Cumpleaños de la abuela del arquero**, a 800 km | Dar permiso (popularidad +2, el arquero llega cansado) · Negarlo (disciplina +2; **rama**: la abuela llama a la radio en vivo) |
| V7 | **El plantel pide cambiar la música del camarín** | Dejar que elijan (arranque +2%) · Imponer tu música (disciplina +2, arranque −2%) |

### Dirigencia
| # | Evento | Opciones → efectos |
|---|---|---|
| D1 | **El sobrino del presidente:** quiere que juegue el juvenil | Aceptar (presupuesto +, **carta temporal** mala del juvenil) · Negarse (**rama**: en 3 semanas, recorte de presupuesto) |
| D2 | **Reunión por refuerzos** (sigue a C6) | Pedir un delantero (presupuesto − grande, carta nueva) · Pedir paciencia (disciplina +2) · Amenazar con renunciar (popularidad +5; 50%: el presidente cede, 50%: te recorta) |
| D3 | **El presidente leyó lo que dijiste** (sigue a C8) | Pedir disculpas (popularidad −2) · Sostenerlo (popularidad +3, presupuesto −) |
| D4 | **Amistoso pagado en el norte, a mitad de semana** | Ir (presupuesto ++, fatiga +15) · No ir (nada) |
| D5 | **Auditoría:** El Mensajero pregunta por un gasto raro del club | Colaborar (disciplina +2) · "No sé nada, yo solo entreno" (popularidad −1; **rama**: 25% el escándalo crece) |

### Hinchas
| # | Evento | Opciones → efectos |
|---|---|---|
| H1 | **La barra pide entradas gratis** | Dárselas (popularidad +, presupuesto −) · Negarse (pifias: arranque −3%) |
| H2 | **Banderazo en el entrenamiento** (antes de un clásico) | Salir a saludar (popularidad +5, fatiga +5) · Entrenar a puertas cerradas (arranque +3%, popularidad −3) |
| H3 | **Un hincha te reconoce en el supermercado** y opina de tu táctica en voz alta | Escucharlo (popularidad +2) · Explicarle la táctica con las frutas (popularidad +4, fatiga +2) · Huir por la sección de congelados (nada) |
| H4 | **Tras una derrota: pintan un mural contra ti** | Ir a conversar (popularidad +3, riesgo 20% de que salga mal) · Ignorarlo (popularidad −2) |

### Sponsor y TV
| # | Evento | Opciones → efectos |
|---|---|---|
| S1 | **Cerveza Glaciar quiere un comercial en la playa** con el plantel | Aceptar (presupuesto +, disciplina −3) · Negarse (si el sponsor tiene cláusula, se enoja) |
| S2 | **Te invitan al matinal de TN** | Ir y bailar (popularidad +6, disciplina −2) · Ir serio (popularidad +2) · No ir (nada) |
| S3 | **Telnet regala celulares al plantel** y los jugadores no los sueltan | Prohibirlos en la concentración (disciplina +3, arranque −1%) · Dejarlos (arranque −3%; **rama**: El Chisme publica un mensaje filtrado) |

## 5. Ramas (las historias que vuelven)
| Empieza en | Si eliges | Vuelve | Qué pasa |
|---|---|---|---|
| C2 Promesa | "Ganamos seguro" | Tras el partido | Premio o castigo según el resultado |
| C5 Árbitro | Quejarte | 1 semana | 30%: multa de la federación |
| C6 → D2 → D3 | Pedir refuerzos | 1-2 semanas | Reunión con el presidente y sus consecuencias |
| C7 Farándula | Abandonar la sala | 2 semanas | El Chisme saca fotos: desmentir, posar o demandar |
| V2 El 9 y su aumento | Prometer | 4 semanas | Si no pagas, pide salir: venderlo (presupuesto +, pierdes su carta) o retenerlo con Nervios |
| V6 La abuela | Negar el permiso | 1 semana | La abuela llama a Radio Galáctica en vivo: popularidad −3 o disculpa pública |
| D1 El sobrino | Negarte | 3 semanas | Recorte de presupuesto, o el sobrino aparece en el entrenamiento igual |
| S3 Celulares | Dejarlos | 2 semanas | Se filtra un mensaje del grupo del plantel |

## 6. Qué sigue
- Revisión del usuario: tono, eventos que sobran y eventos propios para llegar a 30.
- Tarea para programarlo: formato de datos de eventos y ramas en `career_2006.json`, los efectos nuevos de la
  tabla 1, el mazo barajado sin repetir y la pantalla (un medio = su portada o su micrófono en la mesa del DT).
- Idea para más adelante: una relación con cada medio (como en New Star Soccer), que cambie qué te preguntan.
