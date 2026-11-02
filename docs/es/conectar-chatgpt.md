# Conectar ChatGPT o Claude

Para quien no quiere sacar una API key pero ya paga ChatGPT o Claude.

## Lo importante primero

No existe una forma oficial de que otra app use tu suscripción de ChatGPT como motor. Así que lo hacemos al revés: **ChatGPT o Claude se conectan a Speak Away** y leen tus notas. El trabajo de pensar lo hace tu suscripción, dentro de su propia app.

Esto se hace con **MCP**, el estándar de conectores que usan ChatGPT, Claude, Cursor y otros. Speak Away trae un servidor MCP con estas herramientas:

| Herramienta | Qué hace |
|---|---|
| `list_notes` | Lista tus reuniones y dictados recientes |
| `get_note` | Trae una nota completa |
| `search_notes` | Busca en todas tus notas |
| `get_live_transcript` | La transcripción de la reunión que está pasando ahora |
| `save_summary` | Guarda el resumen dentro de la nota (apagada por defecto) |

Entonces en ChatGPT escribes «resume mi reunión de ventas de hoy y dame las tareas» y él busca, lee y responde.

## Tres niveles, del más fácil al más técnico

### Nivel 1: Copiar y pegar (cualquier plan, cero configuración)

En cada nota hay un botón **Copiar para ChatGPT**. Copia la transcripción junto con las instrucciones del resumen. Abres ChatGPT, pegas, listo. Sirve hasta con el plan gratis.

### Nivel 2: Claude Desktop (fácil, todo local)

Claude Desktop se conecta a servidores que corren en tu propia Mac, sin exponer nada a internet.

1. Abre Claude Desktop → **Ajustes → Desarrollador → Editar configuración**.
2. Agrega esto y guarda:

```json
{
  "mcpServers": {
    "speak-away": { "command": "speakaway", "args": ["mcp"] }
  }
}
```

3. Reinicia Claude Desktop. Aparece «speak-away» en las herramientas.

Speak Away también puede hacer esto con un botón: **Ajustes → Conectores → Conectar Claude**.

### Nivel 3: ChatGPT (más pasos, planes de pago)

ChatGPT solo se conecta a servidores en internet (HTTPS), no a tu Mac directamente. Por eso hace falta un túnel.

1. En Speak Away, **Ajustes → Conectores → ChatGPT → Encender**. Esto arranca el servidor en tu Mac y abre un túnel seguro con una dirección como `https://algo.trycloudflare.com/mcp` y un código de acceso.
2. En ChatGPT (web), **Ajustes → Apps y conectores → Avanzado → Modo desarrollador**: actívalo.
3. **Crear conector**: pega la dirección (debe terminar en `/mcp`) y el código.
4. En un chat nuevo, elige el conector «Speak Away» y pregúntale por tus notas.

Ojo con ChatGPT:
- El modo desarrollador depende del plan y OpenAI ha movido ese botón varias veces. Si no lo ves, revisa la guía oficial de OpenAI.
- En cuentas Business o Enterprise puede que un admin tenga que permitirlo.
- Mientras el túnel está abierto, quien tenga la dirección y el código puede leer tus notas. Speak Away lo cierra al apagar el conector y cambia el código cada vez.
- Por defecto ChatGPT solo puede leer. Para que guarde los resúmenes en tus notas, activa `save_summary` en ajustes.
