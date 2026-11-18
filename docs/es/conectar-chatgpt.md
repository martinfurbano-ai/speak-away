# Conectar ChatGPT o Claude

**Planeado. Nada de esto está en la app de Speak Away todavía.**

## Lo importante primero

Este diseño propone que **ChatGPT o Claude se conecten a Speak Away** mediante MCP y lean tus notas. Las herramientas y los comandos de abajo son interfaces propuestas, no instrucciones que funcionen hoy.

| Herramienta propuesta | Uso previsto |
|---|---|
| `list_notes` | Lista tus reuniones y dictados recientes |
| `get_note` | Trae una nota completa |
| `search_notes` | Busca en todas tus notas |
| `get_live_transcript` | La transcripción de la reunión que está pasando ahora |
| `save_summary` | Guarda el resumen dentro de la nota (apagada por defecto en este diseño) |

## Conexiones propuestas

### Claude Desktop (local, stdio)

Entrada propuesta para `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "speak-away": { "command": "speakaway", "args": ["mcp"] }
  }
}
```

### ChatGPT (HTTPS)

Comando propuesto: `speakaway mcp --http`, con un túnel y un código de acceso que cambia cada vez.

El diseño plantea acceso de solo lectura por defecto y cerrar el túnel al apagar el conector. Ninguna de estas funciones está implementada en la app de Mac.
