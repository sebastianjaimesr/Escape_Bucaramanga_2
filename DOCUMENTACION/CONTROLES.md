# Controles

Estado: versión 0.3.0. Solo se listan como activos los controles que ya hacen algo.

## Teclado y ratón

| Acción | Tecla por defecto | Estado |
|---|---|---|
| Moverse | W A S D (también flechas) | Activo |
| Correr (gasta resistencia) | Shift | Activo |
| Saltar (mantener = más alto) | Espacio | Activo |
| Agacharse / levantarse (dentro de un matorral: esconderse) | C | Activo |
| Mover la cámara | Ratón (haz clic en el juego para capturarlo) | Activo |
| Pausa | Esc | Activo |
| Medidor de rendimiento | F3 | Activo |
| Interactuar (recoger pruebas, hablar, comprar granizado) | E | Activo |
| Entrar o salir de vehículos | F | Fase 7 |
| Inventario | Tab | Fase 9 |
| Mapa | M | Fase 9 |

En el navegador, Esc libera el ratón y abre la pausa. Para volver a capturarlo, pulsa **Continuar** o haz clic en el juego.

## Mando

| Acción | Botón (diseño Xbox) |
|---|---|
| Moverse | Palanca izquierda (la velocidad depende de cuánto se incline) |
| Cámara | Palanca derecha |
| Correr | Presionar palanca izquierda o LB |
| Saltar | A |
| Agacharse | B |
| Interactuar | X |
| Pausa | Start |

## Reasignar teclas

**Configuración → Controles**: haz clic en la tecla de una acción y pulsa la nueva. Esc cancela.

- Si la tecla ya la usa otra acción, las dos se intercambian, así ninguna queda sin tecla.
- Esc está reservada para la pausa.
- **Restaurar controles** vuelve a los valores por defecto.
- Los cambios se guardan en `user://settings.cfg` (ver `INSTALACION.md` para la ubicación).

## Detalles del movimiento

| Valor | Cantidad |
|---|---|
| Caminar | 2,6 m/s |
| Correr | 5,8 m/s |
| Agachado | 1,5 m/s |
| Altura del salto | ≈ 1,17 m (salto corto si se suelta antes) |
| Escalón máximo sin saltar | 36 cm |
| Pendiente máxima | 46° |
| Resistencia | ≈ 6 s corriendo; si se agota, no se corre hasta recuperar el 30 % |

## Policía y escondites (0.3.0)

| Situación | Qué pasa |
|---|---|
| Un policía te ve de frente (hasta 17 m, cono de 110°) | Sube su alerta («?»); si sigue viéndote, te persigue («!») |
| Vas agachado | Te ven a la mitad de distancia |
| Corres cerca (6 m) | Te oye aunque esté de espaldas |
| Hay un edificio o un carro en medio | No te ve |
| Estás agachado dentro de un matorral | No te ve («ESCONDIDO») |
| Te alcanza | Vuelves con tus amigos; conservas las pruebas |
| Policía persiguiendo | 5,2 m/s (corriendo tú vas a 5,8 m/s, pero la resistencia se acaba) |
| Granizado | Resistencia sin límite durante 25 s (el vendedor tarda 20 s en preparar otro) |
