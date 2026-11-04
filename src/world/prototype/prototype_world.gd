class_name PrototypeWorld
extends Node3D
## Escena del prototipo de la Fase 2: manzana de prueba, luz de día, jugador,
## cámara en tercera persona, HUD, pausa y perfiles de calidad.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const FALL_RESET_Y := -25.0

var points: Dictionary = {}
var player: PlayerController
var camera_rig: ThirdPersonCamera
var environment: Environment
var sun: DirectionalLight3D
var hud: Hud
var pause_menu: PauseMenu
var navigation: NavigationRegion3D
var mission: EscapeMission
var overlay: MissionOverlay
## Las pruebas de movimiento lo apagan para que la policía no interfiera.
var police_enabled := true


func _ready() -> void:
	_build_environment()
	var builder := PrototypeBlockBuilder.new(self)
	points = builder.build()
	navigation = NavigationBuilder.bake(self, builder.root, PrototypeBlockBuilder.HALF_SIZE)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	add_child(player)
	player.teleport(points["spawn"], points["spawn_yaw"])
	camera_rig = ThirdPersonCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.set_target(player)
	camera_rig.camera.make_current()
	mission = EscapeMission.new(self)
	mission.police_enabled = police_enabled
	add_child(mission)
	hud = Hud.new()
	hud.mission = mission
	add_child(hud)
	overlay = MissionOverlay.new(mission)
	add_child(overlay)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.respawn_requested.connect(respawn)
	apply_quality()
	Settings.changed.connect(_on_setting_changed)


## Luz de final de la tarde (hacia las 5 p. m.): sol bajo y cálido, sombras
## largas, cielo con degradado y niebla suave que oculta el límite del área.
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.42, 0.74)
	sky_mat.sky_horizon_color = Color(0.92, 0.76, 0.6)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.72, 0.62, 0.54)
	sky_mat.ground_bottom_color = Color(0.2, 0.19, 0.2)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.ambient_light_sky_contribution = 0.85
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.08
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.86, 0.76, 0.66)
	environment.fog_density = 1.0
	environment.fog_depth_curve = 1.6
	environment.fog_sky_affect = 0.25
	environment.fog_sun_scatter = 0.25
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.8
	environment.ssil_radius = 4.0
	environment.ssil_intensity = 0.8
	environment.volumetric_fog_density = 0.006
	environment.volumetric_fog_albedo = Color(1.0, 0.9, 0.8)
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.06
	environment.glow_hdr_threshold = 0.9
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.05
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-30.0, -58.0, 0.0)
	sun.light_color = Color(1.0, 0.84, 0.66)
	sun.light_energy = 1.45
	sun.light_angular_distance = 0.8
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_blend_splits = true
	add_child(sun)


func apply_quality() -> void:
	var profile := Settings.quality_profile()
	QualityProfiles.apply(profile, get_viewport(), environment, sun, camera_rig.camera)


func respawn() -> void:
	player.teleport(points["spawn"], points["spawn_yaw"])
	camera_rig.yaw = points["spawn_yaw"]
	camera_rig.snap()


var _was_captured := false


func _physics_process(_delta: float) -> void:
	if player.global_position.y < FALL_RESET_Y:
		respawn()


func _process(_delta: float) -> void:
	# En el navegador, Esc suelta el ratón sin que el juego reciba la tecla:
	# si el ratón deja de estar capturado mientras se juega, se abre la pausa.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and not get_tree().paused and not mission.finished:
		pause_menu.open()
	_was_captured = captured


func _unhandled_input(event: InputEvent) -> void:
	# Clic dentro del juego: capturar el ratón para mover la cámara.
	if event is InputEventMouseButton and event.pressed and not get_tree().paused and not mission.finished:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			EventBus.mouse_capture_changed.emit(true)


func _notification(what: int) -> void:
	# Si el navegador o el sistema sueltan el ratón (Esc en web, Alt+Tab), se pausa.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not get_tree().paused and pause_menu != null:
		pause_menu.open()


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == "graphics" and key == "profile":
		apply_quality()
