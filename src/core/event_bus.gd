extends Node
## Señales globales entre sistemas que no se conocen entre sí.
## Regla: los sistemas emiten aquí y escuchan aquí; nunca leen el estado interno de otro.

signal stamina_changed(value: float, max_value: float, exhausted: bool)
signal player_state_changed(state_name: StringName)
signal pause_changed(paused: bool)
signal mouse_capture_changed(captured: bool)

# --- Policía, interacción y misión (prototipo de la Fase 2.5) ---
signal player_caught(by: Node)
signal police_radio(position: Vector3, from: Node)
signal interaction_prompt_changed(text: String)
signal hidden_changed(hidden: bool)
signal evidence_collected(id: String, label: String)
signal notify(text: String)
signal mission_completed

# --- Aventura (capítulos, sigilo y progresión) ---
## Un ruido que la policía y los vigilantes pueden ir a revisar (lata, alarma).
signal noise(position: Vector3, radius: float, source: String)
## El jugador escaló algo (para pruebas y efectos).
signal player_vaulted(height: float)

# --- Gran huida (v0.6): cámara, zonas y efectos ---
## El jugador entró por primera vez a una zona con nombre (título en pantalla).
signal zone_entered(title: String, subtitle: String)
## Sacudida de cámara (0..1). La suma la cámara y se desvanece sola.
signal camera_shake(amount: float)
## Empieza o termina una cinemática (franjas negras, HUD oculto).
signal cinematic_changed(active: bool, caption: String)
