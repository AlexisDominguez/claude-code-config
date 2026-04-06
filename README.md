# claude-dotfiles

Mi configuracion de Claude Code.

## Que incluye

- **statusline.sh** — Status bar con proyecto, branch, contexto (% + tokens), y rate limits
- **notification-sound.sh** — Sonido (Submarine) y notificacion nativa de macOS al terminar, pedir permiso, o preguntar algo. Toggle con `touch/rm ~/.claude/sound-enabled`
- **settings.json** — Configuracion global: hooks, status line, effort level

## Instalacion

```bash
git clone <url-del-repo> ~/claude-dotfiles
cd ~/claude-dotfiles
bash setup.sh
```

Crea symlinks de los archivos hacia `~/.claude/`.
