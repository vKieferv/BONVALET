# T-17 · El mazo se arma semana a semana (mazo nuevo y cartas de los tres estilos)

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario** (necesita pantalla para las
capturas). **Reescrito el 2026-11-15:** la primera vuelta quedó a medias (mazo nuevo, Pase largo y 8 cartas v2
en el árbol de la rama, sin commit). Esta versión manda.

- **Hito:** M2 (criterio de salida: dos carreras distintas terminan con mazos claramente distintos)
- **Rama:** `tarea/t-17-mazo-nuevo`
- **Decisiones / ideas:** **D-45** (mazo y cartas v2), **D-47** (ajustes a los duelos), **D-49** (solo tres
  estilos: Tiki-Taka, Catenaccio y Contragolpe), D-38 y D-39 (estructura de las cartas v2, regla del 4%), D-20 a
  D-22 (Bloque 2). Diseño carta por carta: `docs/cartas.md`, "Cartas v2" y "Ajustes al partido de duelos (D-47)".
- **Requisitos:** **T-18 mezclada en `main`** (las dos tocan el motor). Si no lo está, detente y avisa. Al
  retomar: guarda lo que hay en un commit y trae `main` a la rama.
- **Origen:** el usuario, tras jugar: "hay pocas cartas, hay que ir armando el mazo semana a semana". El bucle
  semanal ya existe (T-05); lo que falta es contenido que haga que cada elección cambie cómo juegas.

## Objetivo
Cada semana la oferta de cartas te hace elegir de verdad: hay 24 cartas de estilo (8 por cada uno de los tres
estilos) más las genéricas, cada una con su "+", y la oferta favorece tu estilo sin encerrarte en él.

## Alcance
1. **Mazo de inicio de D-45** (ya hecho en la rama; revísalo): 12 cartas con la de rasgo.
2. **Las 24 cartas de estilo** (`data/cards.json`): las 8 de Tiki-Taka, las 8 de Catenaccio y las 8 de
   Contragolpe de `docs/cartas.md`, con los ajustes de D-47, más **Descarga** (genérica: 0 PA, ATRÁS, ROBA 1).
   Las de Directo y Kamikaze que ya estén hechas se quedan en el catálogo pero **fuera de las ofertas**.
3. **Mecánicas que faltan, las mínimas** (`Card`, `MatchEngine`, `CoachBot`, pruebas en `engine_rules`): UNA
   VEZ, AL TOQUE, INSTRUCCIÓN (una sola activa, se ve en el marcador), +PA, "tu próxima carta…" y las
   traducciones de D-47 (un compañero libre más, marcas extra, ignorar marcas). Una carta cuya mecánica sea
   cara o dudosa **no se implementa**: va a una lista en el informe, con el motivo.
4. **Cada carta con su "+"** (D-38): la sesión de video convierte la carta elegida en su "+", en vez de la
   mejora genérica. Las genéricas sin "+" definido conservan la mejora de hoy.
5. **Ofertas con intención** (`data/decks.json`, `Career`): de las 3 cartas de la semana, **al menos 1 es de
   tu estilo**; las otras salen de la general y de los otros dos estilos. Rarezas: básicas siempre, tácticas
   desde la semana 3, élite e instrucciones poco frecuentes y desde la mitad de la temporada. No se repite una
   carta que ya rechazaste la semana anterior.
6. **Los rivales** crecen con las cartas de su estilo (T-06), solo básicas y tácticas.
7. **Medición liviana** (el usuario pidió no simular cruces de más): solo la regla del 4% de D-39, carta por
   carta, a 100 partidos por cruce y no más de 3 procesos a la vez en segundo plano; y **una** medición de
   goles al inicio con el mazo nuevo. Nada de temporada completa ni de todos los cruces.
8. **Prueba del criterio de M2** (`tests/`): dos carreras simuladas con el mismo club y distinta semilla
   terminan con mazos que difieren en al menos 5 cartas.
9. **Láminas:** las cartas nuevas usan los dibujos por tipo que ya existen; capturas de la oferta de una
   semana y de 6 láminas nuevas (2 por estilo), con `director-arte-2006`.

## Fuera de alcance
- Directo y Kamikaze (D-49), jugadas de crack por perfil, quitar cartas del mazo, canteranos.
- Curva de la temporada, cansancio, desenlaces de D-48 y la ventaja de estilo de T-18.
- Pantalla del partido y de la semana, salvo mostrar la instrucción activa y la oferta.

## Definición de terminado
- [ ] `godot-check` en verde; nueva línea base de `-Balance` anotada en `docs/arquitectura.md`.
- [ ] Tabla de la regla del 4% por carta y lista de las cartas que no entraron, con el motivo.
- [ ] Capturas en `C:\Users\vicen\Desktop\bonvalet\capturas-t17\` e `informe.md` con lo que quedó sin verificar.
- [ ] `docs/cartas.md` y `docs/gdd.md` al día con lo que cambió de valor.
- [ ] Rama subida; sin PR ni mezcla.

## Preguntas abiertas
- Si una carta rompe la regla del 4%, se encarece o se le pone condición (D-39) y se anota.
- Cualquier otra duda de diseño: opción conservadora y nota en el informe.
