# Speak Away

Dictado por voz y notas de reuniones, de código abierto, que corren en tu propia computadora.

Dictado gratis y de código abierto. Mantienes Fn, hablas, sueltas, y el texto aparece donde tengas el cursor. Prendes el notetaker para transcribir una reunión; pulsa «Resumir» para pedir un resumen. Sin cuenta ni suscripción. Haz un fork y cámbiala a tu gusto.

Creado por **Martín Urbano** para [Open Source Everything](https://www.instagram.com/opensourceeverything/).

**[Descargar para Mac](https://github.com/martinfurbano-ai/speak-away/releases/latest/download/SpeakAway.dmg)** · [Sitio](https://speakaway.heliospanama.com)

> La versión 0.2 trae dictado, modo comando, notas de reuniones, diccionario, atajos de voz, estilo por tipo de app, historial y bloc de notas. Lo que sigue: [docs/roadmap.md](docs/roadmap.md).

## Instalar

1. Descarga el .dmg y arrastra Speak Away a Aplicaciones.
2. Ábrela. La descarga contiene una app firmada y notarizada dentro de un .dmg.
3. Da los permisos de Micrófono, Monitoreo de entrada (tecla Fn) y Accesibilidad (pegar). Las notas de reuniones también necesitan el permiso de macOS para capturar el audio del sistema (ver [Cómo funciona el notetaker](docs/es/notetaker.md)). El modelo por defecto se descarga cuando abres la app por primera vez, y el otro la primera vez que lo eliges. Un modelo se descarga de nuevo solo si su carpeta en tu Mac falta o está incompleta. Los tamaños son unos 632 MB (preciso, por defecto) o 216 MB (rápido).
4. Mientras corre, Speak Away pone «Pulsar la tecla 🌐 para» en No hacer nada para que Fn no abra el selector de emojis. Devuelve tu ajuste cuando sales de la app con normalidad; si la app se cierra de forma inesperada, la opción se queda en No hacer nada y puedes cambiarla en Ajustes del Sistema › Teclado.

Requiere una Mac con Apple Silicon (M1 o posterior) y macOS 14 o posterior.

Con Accesibilidad, Speak Away pega por ti y después restaura lo que habías copiado, salvo que hayas copiado otra cosa entre tanto. Sin ese permiso, Speak Away no puede pegar por ti.

## Qué hace

- **Dictado:** mantén Fn para hablar, o Fn dos veces para dictar sin manos. Whisper corre en tu Mac y pega el texto donde estabas escribiendo.
- **Modo comando:** selecciona un texto, mantén Control + Fn y di «hazlo más corto» o «tradúcelo al inglés». Usa el modelo de Apple en tu Mac y requiere macOS 26 con Apple Intelligence.
- **Notetaker:** graba tu micrófono y el audio del sistema en dos pistas («Yo» y «Ellos»), sin bots, y transcribe en vivo. El audio del sistema incluye todo lo que reproduce tu Mac excepto los sonidos de Speak Away, así que la música o los videos pueden aparecer en la transcripción. La nota no tiene resumen hasta que pulses «Resumir».
- **Tu voz:** diccionario, atajos de voz («mi dirección» escribe la dirección completa), estilo por tipo de app (mensajes, correo, trabajo y notas, todo lo demás), historial y bloc de notas.

## Privacidad por diseño

El dictado corre en tu Mac con Whisper. Sin cuenta, sin analítica, sin rastreo, sin anuncios. Las únicas solicitudes de red de la app para Mac van a Hugging Face, para descargar el modelo y, si no están en caché, pequeños archivos del tokenizador. La limpieza de muletillas usa reglas, está activada por defecto y no necesita Apple Intelligence. Los resúmenes, la opción «Pulir con Apple Intelligence» (desactivada por defecto) y el modo comando usan el modelo de Apple en tu Mac y requieren macOS 26 con Apple Intelligence. El dictado no lo requiere.

## Preguntas frecuentes

**¿Qué idiomas reconoce?** Inglés y español, con detección automática. Los menús y pantallas de la app están en español hoy.

## Guías en español

- [Cómo funciona el notetaker](docs/es/notetaker.md)
- [Arquitectura](docs/architecture.md): cómo encajan las piezas (en inglés)
- [Traer tu propia llave](docs/es/llaves-api.md): planeado
- [Conectar ChatGPT o Claude](docs/es/conectar-chatgpt.md): planeado

## Desarrollo

Compilar necesita Xcode 26 o superior.

La app para Mac es Swift + [WhisperKit](https://github.com/argmaxinc/WhisperKit) en [`app/`](app):

```sh
cd app
swift test                      # lógica central
./scripts/build-app.sh          # compila app/dist/SpeakAway.dmg
./.build/arm64-apple-macosx/release/SpeakAway --transcribe audio.wav   # transcribe un archivo, sin teclado
```

El paquete de Python (`speakaway/`) es un prototipo, no forma parte de la app para Mac: `python3 -m unittest discover -s tests`.

## Créditos

Hecho por Martín Urbano. El primer prototipo de dictado se hizo con Sofía ([Sofiache26](https://github.com/Sofiache26)). Reconocimiento de voz de OpenAI Whisper mediante WhisperKit de Argmax.

## Licencia

[MIT](LICENSE). Las contribuciones son bienvenidas, mira [CONTRIBUTING.md](CONTRIBUTING.md).
