# Cómo funciona el notetaker

Las notas de reuniones están disponibles desde v0.2.0 y se transcriben en tu Mac.

Speak Away transcribe la reunión en tu Mac mientras hablan y guarda una nota en Markdown al detener la grabación. La nota no tiene resumen hasta que pulses «Resumir».

## El recorrido

```
 Zoom / Teams / FaceTime / Webex / Slack / WhatsApp
            │
   ┌────────┴────────┐
   │                 │
 Tu micrófono    Audio del sistema        1. Captura en dos pistas
  («Yo»)          («Ellos»)
   │                 │
   └──── trozos de ~20 s, buscando pausas ───────────┐   2. Trozos
                                                    │
                     Whisper local en tu Mac  ◄─────┘   3. Transcribe (sin internet tras descargar el modelo)
                              │
              live.ndjson (línea por trozo transcrito)  4. Transcripción en vivo
                              │
              <fecha> <título>.md y .json al detener    5. Nota
                              │
                 «Resumir» con Apple Intelligence       6. Resumen (opcional)
```

### 1. Empezar

Dos formas:

- **Sola:** Speak Away detecta posibles reuniones a partir de las apps abiertas y el uso del micrófono, y pregunta una vez: «¿Tomo notas?». Reconoce Zoom, Microsoft Teams, FaceTime y Webex. Slack y WhatsApp cuentan solo en macOS 14.2 o posterior, cuando macOS indica que están usando el micrófono. La detección de Google Meet no está conectada.
- **Botón** en la barra de menú.

### 2. Captura en dos pistas

- **Tu voz:** el micrófono.
- **Audio del sistema:** todo lo que reproduce tu Mac excepto los sonidos de Speak Away, así que la música o los videos pueden aparecer en la transcripción. En macOS 14.4 o posterior intenta usar Core Audio, que necesita permiso para grabar el audio del sistema. ScreenCaptureKit es la alternativa: se usa en macOS 14.0 a 14.3 y cuando la captura con Core Audio no puede arrancar. Con ScreenCaptureKit, macOS pide en su lugar el permiso de grabación de pantalla, y Speak Away usa solo el sonido: descarta los fotogramas de video. No hace falta instalar BlackHole ni drivers raros.

Las dos pistas separan la entrada del micrófono del audio del sistema, no a cada persona.

### 3. Transcribir en trozos

El audio se corta en trozos de unos 20 segundos, buscando pausas; si no hay una pausa, corta a los 30 segundos. Cada trozo pasa por el mismo Whisper del dictado, con WhisperKit.

### 4. Transcripción en vivo

Cada trozo transcrito se agrega como una línea a `live.ndjson`:

```json
{"speaker":"them","start":754.2,"text":"Entonces el martes mandamos la cotización."}
```

La página de reuniones muestra la transcripción en vivo. El diario no garantiza recuperar una reunión si la app se cierra inesperadamente.

### 5. La nota

Al detener la grabación (la detienes tú, o se detiene sola poco después de que termina una llamada que detectó), Speak Away guarda `<fecha> <título>.md` y un `.json` al lado para la app en `~/Library/Application Support/Speak Away/Meetings/`:

```markdown
---
title: "Reunión de ventas"
app: Zoom
date: 2026-11-01 15:30
duration: 00:42:00
---

# Reunión de ventas

**Yo** 00:00:00 Buenas, ¿me escuchan?

**Ellos** 00:00:04 Sí, perfecto...
```

El audio nunca se escribe en almacenamiento. El diario temporal se borra cuando se guarda la nota. Si la nota no se puede guardar, o la app se interrumpe, el diario se queda en esa carpeta hasta que la próxima reunión lo reemplace. Los archivos son planos, sin cifrado de Speak Away.

### 6. El resumen (opcional)

Pulsa «Resumir» para generar el resumen con el modelo de Apple en tu Mac. Requiere macOS 26 con Apple Intelligence. «Resumir otra vez» vuelve a generar el resumen. «Copiar para ChatGPT» copia las notas como un prompt que puedes pegar tú en ChatGPT o Claude.

El resumen puede tener hasta cuatro secciones; las vacías se omiten:

- **Resumen.**
- **Decisiones.**
- **Tareas.**
- **Preguntas abiertas.**

En el archivo Markdown, el resumen se agrega después de la transcripción.

Grabar a otros puede requerir su permiso según el país. La página de reuniones muestra un indicador mientras graba.

## Qué ya existe y qué falta

- Ya existe (app 0.2.0): micrófono, audio del sistema, transcripción local en trozos, `live.ndjson`, notas, detección de posibles reuniones y resúmenes con Apple Intelligence.
- La detección de Google Meet no está conectada.
