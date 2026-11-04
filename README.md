# Escape de Bucaramanga

Aventura urbana en tercera persona inspirada en Bucaramanga, Santander (Colombia), hecha en **Godot 4.7**. Sebastián y sus tres amigos recorren la ciudad para aclarar un malentendido mientras la policía (ficticia) los busca.

> Estado: **en desarrollo, Fase 2 de 12** (prototipo de cámara y movimiento), con adelantos de gráficos, policía e interacción (versión 0.3.0). Ver [DOCUMENTACION/PLAN_DE_DESARROLLO.md](DOCUMENTACION/PLAN_DE_DESARROLLO.md).
> La versión 2D original está completa y jugable en [`clasico-2d/`](clasico-2d/).

Los lugares están inspirados en Bucaramanga; no son reproducciones exactas.

## Qué hay hoy (0.3.0)

- Manzana de prueba en 3D con luz de atardecer: cruce de dos calles, andenes de baldosa, edificios de revoque y de ladrillo con balcones y locales con letrero, carros parqueados, semáforos, postes con cables, y una plaza con escaleras, rampa, pendiente empinada, túnel bajo y cajas.
- **Misión jugable «Las pruebas del malentendido»**: recoge 5 pruebas y llévaselas a Buitrago, Diaz y Gordo sin que te atrape la policía.
- **Policía ficticia** que patrulla, te ve si no hay nada en medio, te persigue, avisa por radio y te busca donde te perdió. Escóndete agachado en los matorrales.
- Vendedor de granizados (resistencia sin límite un rato), peatones que dan pistas, minimapa y avisos en pantalla.
- Personaje provisional (figura de primitivas con la ropa de Sebastián) que camina, corre, salta y se agacha, con resistencia, subida de escalones y bordillos.
- Cámara en tercera persona con ratón o mando, que no atraviesa paredes.
- Menú, pausa, configuración (calidad Bajo/Medio/Alto, cámara, controles reasignables) y medidor de rendimiento (F3).
- 39 pruebas automáticas.

Todavía **no** están el modelo definitivo de Sebastián, los compañeros que te siguen, la patrulla en vehículo, los vehículos conducibles, la ciudad de Bucaramanga ni el audio: llegan en las fases siguientes.

## Ejecutar

Requiere Godot **4.7** (versión estándar). Ver [DOCUMENTACION/INSTALACION.md](DOCUMENTACION/INSTALACION.md).

```bash
godot --path .            # jugar
godot -e --path .         # abrir el editor
```

## Pruebas

```bash
godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
```

Detalle y resultados en [DOCUMENTACION/PRUEBAS.md](DOCUMENTACION/PRUEBAS.md).

## Documentación

| Documento | Contenido |
|---|---|
| [AUDITORIA_INICIAL.md](DOCUMENTACION/AUDITORIA_INICIAL.md) | Auditoría del juego 2D y elección del motor |
| [ARQUITECTURA.md](DOCUMENTACION/ARQUITECTURA.md) | Sistemas, carpetas, guardado, calidad gráfica, recursos |
| [PLAN_DE_DESARROLLO.md](DOCUMENTACION/PLAN_DE_DESARROLLO.md) | Las 12 fases y la campaña |
| [CONTROLES.md](DOCUMENTACION/CONTROLES.md) | Teclado, ratón, mando y reasignación |
| [INSTALACION.md](DOCUMENTACION/INSTALACION.md) | Preparar el entorno |
| [EXPORTACION_PC.md](DOCUMENTACION/EXPORTACION_PC.md) | Generar el `.exe` de Windows |
| [EXPORTACION_WEB.md](DOCUMENTACION/EXPORTACION_WEB.md) | Versión web y GitHub Pages |
| [PRUEBAS.md](DOCUMENTACION/PRUEBAS.md) | Pruebas y mediciones |
| [CHANGELOG.md](CHANGELOG.md) | Cambios por versión |

## Versión web

- Juego 2D (versión estable): https://sebastianjaimesr.github.io/Escape-Bucaramanga/
- Prototipo 3D: https://sebastianjaimesr.github.io/Escape-Bucaramanga/beta-3d/
