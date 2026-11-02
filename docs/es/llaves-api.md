# Cómo sacar tu API key, paso a paso

Speak Away funciona sin llave. Una llave sirve para dos cosas: que los resúmenes y la limpieza del dictado salgan solos y mejores, o transcribir en la nube si tu Mac es vieja o Intel.

Una API key es como una contraseña que le da a Speak Away permiso de usar tu cuenta en ese proveedor. Lo que gastes lo pagas tú directo a ellos, normalmente centavos por reunión. Speak Away no cobra nada ni ve tu llave.

> Ojo: la suscripción de ChatGPT Plus y la API de OpenAI se pagan aparte. Tener Plus no te da llave. Si quieres usar tu suscripción, mira [conectar-chatgpt.md](conectar-chatgpt.md).

## ¿Cuál saco?

| Si quieres... | Saca |
|---|---|
| Empezar gratis | **Groq** (tiene capa gratis, transcribe y resume) |
| La mejor calidad en resúmenes | **Anthropic** (Claude) |
| Lo conocido | **OpenAI** |
| Una sola llave para muchos modelos | **OpenRouter** |
| Nada en la nube | Ninguna: **Ollama** |

## Groq (gratis para empezar)

1. Entra a [console.groq.com](https://console.groq.com) y crea una cuenta con Google o tu correo.
2. En el menú, **API Keys**.
3. **Create API Key**, ponle de nombre «Speak Away».
4. Copia la llave (empieza con `gsk_`). Solo se muestra una vez.

## OpenAI

1. Entra a [platform.openai.com](https://platform.openai.com) (no es chatgpt.com) e inicia sesión.
2. **Settings → Billing**, agrega una tarjeta y saldo. Normalmente el mínimo son 5 USD.
3. **API keys → Create new secret key**, nombre «Speak Away».
4. Copia la llave (empieza con `sk-`). Solo se muestra una vez.

## Anthropic (Claude)

1. Entra a [console.anthropic.com](https://console.anthropic.com) y crea la cuenta.
2. **Billing**, agrega tarjeta y saldo.
3. **API Keys → Create Key**, nombre «Speak Away».
4. Copia la llave (empieza con `sk-ant-`).

## OpenRouter

1. Entra a [openrouter.ai](https://openrouter.ai) y crea la cuenta.
2. **Credits**, carga saldo.
3. **Keys → Create Key**.
4. Copia la llave (empieza con `sk-or-`).

## ElevenLabs (solo transcripción)

1. Entra a [elevenlabs.io](https://elevenlabs.io).
2. **Developers → API Keys → Create**.
3. Copia la llave.

## Ollama (sin llave, todo en tu Mac)

1. Descarga Ollama de [ollama.com](https://ollama.com) e instálalo.
2. En Terminal: `ollama pull llama3.2`
3. En Speak Away, **Ajustes → Cerebro → Ollama**.

## Pegarla en Speak Away

1. **Ajustes → Llaves**.
2. Elige el proveedor y pega la llave.
3. Toca **Probar**. Si sale verde, listo.

La llave queda en el Llavero de macOS, no en un archivo. Para borrarla, el mismo botón en Ajustes o el Llavero.

## Si algo falla

- **«Invalid API key»:** se copió con un espacio de más o incompleta. Crea otra y pégala de nuevo.
- **«Insufficient quota» o «billing»:** falta saldo en ese proveedor.
- **Se filtró la llave:** bórrala en la página del proveedor y crea otra. La vieja deja de servir al instante.
