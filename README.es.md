# Speak Away

Dictado por voz y notas de reuniones, de código abierto, que corren en tu propia computadora.

Tocas una tecla dos veces, hablas, y el texto aparece donde tengas el cursor. Prendes el notetaker y cada reunión queda como una nota en Markdown en una carpeta tuya. Sin cuenta, sin suscripción y sin API key.

> Estado: esqueleto. El dictado que ya funciona viene de [whisper-flow](https://github.com/Sofiache26/whisper-flow) de Sofiache26 y se está mudando aquí. Todavía no se instala. Ver [docs/roadmap.md](docs/roadmap.md).

## Qué hace

- **Dictado:** Fn dos veces para empezar, Fn para terminar. Whisper corre en tu Mac y pega el texto donde estabas escribiendo.
- **Notetaker:** graba tu micrófono y el audio de la llamada en dos pistas, transcribe en vivo y guarda la nota al terminar.
- **Cerebro (opcional):** limpia el dictado y escribe resúmenes. Viene apagado.
- **Conectores:** ChatGPT, Claude y otros clientes MCP leen tus notas y las resumen con tu propia suscripción.

## Nunca necesitas una API key

Todo tiene un camino gratis y local. La llave es una mejora, no un requisito.

| Trabajo | Sin llave | Con tu llave |
|---|---|---|
| Voz a texto | Whisper en tu Mac (por defecto) | Groq, OpenAI, ElevenLabs, Deepgram |
| Limpieza y resúmenes | Nada, Ollama (local), o ChatGPT/Claude por conector | Anthropic, OpenAI, Groq, OpenRouter |

Las llaves se guardan en el Llavero de macOS, solo viajan al proveedor dueño de esa llave y nunca quedan en el archivo de ajustes. Paso a paso: [docs/es/llaves-api.md](docs/es/llaves-api.md).

## Guías en español

- [Cómo funciona el notetaker](docs/es/notetaker.md)
- [Cómo sacar tu API key, paso a paso](docs/es/llaves-api.md)
- [Conectar ChatGPT o Claude](docs/es/conectar-chatgpt.md)

## Licencia

[MIT](LICENSE).
