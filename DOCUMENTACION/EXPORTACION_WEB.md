# Exportación web y GitHub Pages

## Exportar

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

- Plantilla **sin hilos** (`thread_support=false`): funciona en GitHub Pages, que no permite las cabeceras COOP/COEP que necesitan los hilos.
- Renderizador **Compatibilidad (WebGL 2)**.
- Plantilla HTML propia en `web/shell.html` (título, descripción para buscadores y redes, pantalla de carga con la identidad del juego y mensajes en español). Está configurada en `export_presets.cfg` (`html/custom_html_shell`).

## Probar localmente

```bash
python -m http.server 8060 --directory build/web
```

y abre http://localhost:8060. Abrir `index.html` directamente como archivo no funciona.

## Tamaño (Fase 2, medido)

| Archivo | Tamaño | Comprimido (gzip -9) |
|---|---|---|
| `index.wasm` (motor Godot) | 39,5 MB | ≈ 10,1 MB |
| `index.pck` (datos del juego) | 86 KB (0.4.0: 1,1 MB con audio y tipografías) | ≈ 74 KB (0.4.0: ≈ 0,96 MB) |
| `index.js` | 280 KB | — |

El motor es un costo fijo de Godot. En la Fase 11 se evaluará compilar una plantilla web propia sin los módulos que no se usan.

## Publicación en GitHub Pages

El sitio https://sebastianjaimesr.github.io/Escape_Bucaramanga_2/ se sirve desde la raíz de la rama `gh-pages` (Settings → Pages → Deploy from a branch → `gh-pages` / root). No hace falta cambiar esa configuración.

Para publicar una versión nueva:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
git worktree add ../gh-pages gh-pages
cp build/web/* ../gh-pages/
cd ../gh-pages && git add -A && git commit -m "Publicar 0.4.0" && git push origin gh-pages
```

GitHub tarda uno o dos minutos en publicar (acción «pages build and deployment»).

## Limitaciones en el navegador

- El ratón se captura al hacer clic en el juego; Esc lo libera y abre la pausa. Con controles táctiles no se captura.
- El sonido empieza con el primer clic o toque (regla de los navegadores).
- La partida guardada y la configuración viven en el almacenamiento del sitio (IndexedDB).
- La pantalla completa la maneja el navegador (F11), no el juego.
- Sin SSAO, SSR ni niebla volumétrica (no existen en WebGL 2 en Godot). El perfil por defecto en web es **Bajo**.
- La configuración se guarda en el almacenamiento del sitio (IndexedDB): se pierde al borrar los datos del sitio o en ventanas privadas.
