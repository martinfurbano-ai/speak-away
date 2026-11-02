# Speak Away

Dictado por voz y notas de reuniones, de código abierto, que corren en tu propia computadora.

Una alternativa gratis y de código abierto a apps de dictado pagas como Wispr Flow. Mantienes Fn, hablas, sueltas, y el texto aparece donde tengas el cursor. Prendes el notetaker y cada reunión queda como una nota con resumen. Sin cuenta, sin suscripción y sin API key. Haz un fork y cámbiala a tu gusto.

Creado por **Martín Urbano** para [Open Source Everything](https://www.instagram.com/opensourceeverything/): versiones gratis y abiertas de las apps por las que la gente paga suscripción.

**[Descargar para Mac](https://github.com/martinfurbano-ai/speak-away/releases/latest/download/SpeakAway.dmg)** · [Sitio](https://speakaway.heliospanama.com)

> La versión 0.2 trae dictado, modo comando, notas de reuniones, diccionario, atajos de voz, estilo por app, historial y bloc de notas. La versión de la Mac App Store está en revisión. Lo que sigue: [docs/roadmap.md](docs/roadmap.md).

## Instalar

1. Descarga el .dmg y arrastra Speak Away a Aplicaciones.
2. Ábrela. Está firmada y notarizada por Apple, así que abre sin avisos.
3. Da los permisos de Micrófono, Monitoreo de entrada (tecla Fn) y Accesibilidad (pegar). El modelo de voz (unos 630 MB) se descarga una sola vez.
4. Mientras corre, Speak Away pone «Pulsar la tecla 🌐 para» en No hacer nada para que Fn nunca abra los emojis, y devuelve tu ajuste al salir.

## Qué hace

- **Dictado:** mantén Fn para hablar, o Fn dos veces para dictar sin manos. Whisper corre en tu Mac y pega el texto donde estabas escribiendo.
- **Modo comando:** selecciona un texto, mantén Control + Fn y di «hazlo más corto» o «tradúcelo al inglés». Usa el modelo de Apple en tu Mac.
- **Notetaker:** graba tu micrófono y el audio de la llamada en dos pistas (Yo y Ellos), sin bots, transcribe en vivo y escribe un resumen con pendientes al terminar.
- **Tu voz:** diccionario, atajos de voz («mi dirección» escribe la dirección completa), estilo por app, historial y bloc de notas.
- **Cerebro:** limpieza y resúmenes con Apple Intelligence en tu Mac, o con tu propia llave si prefieres.
- **Conectores (próximamente):** ChatGPT, Claude y otros clientes MCP leen tus notas y las resumen con tu propia suscripción.

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
