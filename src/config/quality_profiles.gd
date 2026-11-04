class_name QualityProfiles
extends RefCounted
## Perfiles de calidad gráfica Bajo / Medio / Alto.
##
## Se aplican sobre el Viewport, el Environment, la luz del sol y la cámara.
## Los efectos que solo existen en Forward+ (SSAO, SSR, niebla volumétrica) se
## activan solo si el renderizador actual es Forward+; en Compatibilidad (web)
## quedan apagados aunque el perfil los pida, y renderer_supports() lo informa.

const ORDER := ["bajo", "medio", "alto"]
const LABELS := {"bajo": "Bajo", "medio": "Medio", "alto": "Alto"}

const PROFILES := {
	"bajo": {
		"render_scale": 0.75,
		"msaa": Viewport.MSAA_DISABLED,
		"fxaa": true,
		"shadow_size": 1024,
		"shadow_distance": 30.0,
		"shadow_cascades": 2,
		"draw_distance": 150.0,
		"ssao": false,
		"ssr": false,
		"volumetric_fog": false,
		"ssil": false,
		"glow": false,
	},
	"medio": {
		"render_scale": 1.0,
		"msaa": Viewport.MSAA_2X,
		"fxaa": false,
		"shadow_size": 2048,
		"shadow_distance": 60.0,
		"shadow_cascades": 2,
		"draw_distance": 300.0,
		"ssao": false,
		"ssr": false,
		"volumetric_fog": false,
		"ssil": false,
		"glow": true,
	},
	"alto": {
		"render_scale": 1.0,
		"msaa": Viewport.MSAA_4X,
		"fxaa": false,
		"shadow_size": 4096,
		"shadow_distance": 100.0,
		"shadow_cascades": 4,
		"draw_distance": 500.0,
		"ssao": true,
		"ssr": true,
		"volumetric_fog": true,
		"ssil": true,
		"glow": true,
	},
}


static func is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


static func renderer_name() -> String:
	match RenderingServer.get_current_rendering_method():
		"forward_plus":
			return "Forward+"
		"mobile":
			return "Mobile"
		"gl_compatibility":
			return "Compatibilidad (WebGL 2 / OpenGL 3)"
		"dummy":
			return "Sin renderizado (headless)"
	return RenderingServer.get_current_rendering_method()


## Aplica el perfil. Cualquier argumento puede ser null (por ejemplo en menús).
static func apply(profile_id: String, viewport: Viewport, env: Environment,
		sun: DirectionalLight3D, camera: Camera3D) -> Dictionary:
	var p: Dictionary = PROFILES.get(profile_id, PROFILES["medio"])
	var fp := is_forward_plus()
	if viewport != null:
		viewport.scaling_3d_scale = p["render_scale"]
		# FXAA no existe en Compatibilidad: allí se usa MSAA 2× en su lugar.
		var fxaa_ok := RenderingServer.get_current_rendering_method() != "gl_compatibility"
		var use_fxaa: bool = p["fxaa"] and fxaa_ok
		viewport.msaa_3d = Viewport.MSAA_2X if (p["fxaa"] and not fxaa_ok) else p["msaa"]
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if use_fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	if sun != null:
		sun.directional_shadow_max_distance = p["shadow_distance"]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if p["shadow_cascades"] >= 4 \
				else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if camera != null:
		camera.far = p["draw_distance"]
	if env != null:
		env.ssao_enabled = fp and p["ssao"]
		env.ssr_enabled = fp and p["ssr"]
		env.volumetric_fog_enabled = fp and p["volumetric_fog"]
		env.ssil_enabled = fp and p["ssil"]
		env.glow_enabled = p["glow"]
		# La niebla por distancia se ajusta para ocultar el límite de dibujo.
		env.fog_depth_end = p["draw_distance"]
		env.fog_depth_begin = p["draw_distance"] * 0.35
	return p
