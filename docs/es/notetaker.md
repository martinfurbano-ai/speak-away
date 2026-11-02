# Cómo funciona el notetaker

La idea: entras a una reunión, Speak Away la transcribe en tu Mac mientras hablan, y al colgar tienes una nota en Markdown con la transcripción. El resumen es opcional y lo puede hacer tu Mac, tu propia llave, o tu ChatGPT.

## El recorrido

```
 Zoom / Meet / Teams / WhatsApp
            │
   ┌────────┴────────┐
   │                 │
 Tu micrófono    Audio de la llamada        1. Captura en dos pistas
  («Tú»)          («Ellos»)
   │                 │
   └──── trozos de ~20 s, cortados en silencios ────┐   2. Trozos
                                                    │
                     Whisper local en tu Mac  ◄─────┘   3. Transcribe (sin internet)
                              │
                 live.ndjson (línea por frase)          4. Transcripción en vivo
                              │
                  Al colgar: Nota.md en tu carpeta      5. Nota
                              │
            ┌─────────────────┼──────────────────┐
         Sin cerebro     Ollama / tu llave    ChatGPT o Claude     6. Resumen (opcional)
       (solo la nota)     (resumen solo)      (por conector)
```

### 1. Empezar

Tres formas:
- **Sola:** Speak Away nota que Zoom, Meet, Teams, FaceTime o WhatsApp está usando el micrófono y pregunta una vez: «¿Tomo notas de esta reunión?».
- **Botón** en la barra de menú.
- **Tecla:** un atajo propio, distinto al del dictado.

### 2. Captura en dos pistas

- **Tu voz:** el micrófono.
- **La voz de los demás:** el audio que sale de la app de la reunión. En macOS 14.4 o más nuevo se usa Core Audio (pide el permiso «Grabación de audio del sistema»); en macOS 13 se usa ScreenCaptureKit (pide «Grabación de pantalla», pero solo toma el audio). No hace falta instalar BlackHole ni drivers raros.

Tener dos pistas regala algo: sin ningún modelo extra ya sabes qué dijiste tú y qué dijeron los demás. Separar a «los demás» entre varias personas viene después.

### 3. Transcribir en trozos

El audio se corta cada ~20 segundos, siempre en un silencio para no partir palabras. Cada trozo pasa por el mismo Whisper del dictado (`whisper-large-v3-turbo` con MLX). Una Mac M1 transcribe más rápido de lo que la gente habla, así que la transcripción va casi en vivo.

### 4. Transcripción en vivo

Cada frase se agrega como una línea a `live.ndjson`:

```json
{"t": 754.2, "who": "ellos", "text": "Entonces el martes mandamos la cotización."}
```

Una ventanita (o el HUD) la va mostrando. Si la app se cierra a la mitad, nada se pierde.

### 5. La nota

Al colgar, Speak Away escribe un archivo en `~/Documents/Speak Away/Notes/`:

```markdown
---
fecha: 2026-11-01 15:30
duracion: 42 min
app: Zoom
---

# Reunión de ventas

## Transcripción
**Tú (00:00):** Buenas, ¿me escuchan?
**Ellos (00:04):** Sí, perfecto...
```

El audio se borra apenas está transcrito (se puede cambiar en ajustes). Son archivos normales: los abres en Notas, Obsidian, VS Code o lo que quieras.

### 6. El resumen (opcional)

Aquí está la pregunta de la llave. Hay cuatro caminos y la persona elige:

| Camino | Necesita | Qué pasa |
|---|---|---|
| **Sin cerebro** | Nada | Queda la transcripción. Un botón «Copiar para ChatGPT» copia la transcripción con las instrucciones del resumen; lo pegas en ChatGPT (sirve hasta el plan gratis). |
| **Ollama** | Instalar Ollama | Un modelo local escribe el resumen. Cero internet, cero costo. Más lento y menos fino. |
| **Tu llave** | Una API key | El resumen sale solo y bueno. Pagas centavos por reunión directo al proveedor. Ver [llaves-api.md](llaves-api.md). |
| **Conector** | ChatGPT o Claude | Le dices a ChatGPT «resume mi última reunión» y él lee la nota desde Speak Away. Usa tu suscripción, no una llave. Ver [conectar-chatgpt.md](conectar-chatgpt.md). |

El resumen siempre trae lo mismo:
- **Resumen** en tres a cinco líneas.
- **Decisiones.**
- **Tareas:** quién, qué y para cuándo.
- **Preguntas abiertas.**

Y se agrega arriba de la transcripción en la misma nota.

## Consentimiento

Grabar a otros puede requerir su permiso según el país. Mientras graba, Speak Away muestra un punto rojo visible, y puede escribir en el chat de la reunión «Esta reunión se está transcribiendo con Speak Away» cuando la app lo permite.

## Qué ya existe y qué falta

- Ya existe (en whisper-flow): micrófono, Whisper local con MLX, HUD.
- Falta: audio del sistema, trozos con detección de silencio, `live.ndjson`, la nota, el detector de reuniones, el resumen y el conector.
