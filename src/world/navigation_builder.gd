class_name NavigationBuilder
extends RefCounted
## Genera la malla de navegación (navmesh) a partir de las colisiones estáticas
## del mundo y de los carros parqueados. La usan la policía y los peatones
## (NavigationAgent3D). Se hornea una vez al cargar la escena.

const CELL_SIZE := 0.25
const CELL_HEIGHT := 0.1
const AGENT_RADIUS := 0.25       ## Múltiplo de CELL_SIZE (postes y faroles dejan paso en el andén).
const AGENT_HEIGHT := 1.8
const AGENT_MAX_CLIMB := 0.3     ## Múltiplo de CELL_HEIGHT; bordillos y escalones.
const AGENT_MAX_SLOPE := 40.0


static func bake(parent: Node3D, source_root: Node3D, half_size: float) -> NavigationRegion3D:
	var map := parent.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(map, CELL_HEIGHT)
	var nav := NavigationMesh.new()
	nav.cell_size = CELL_SIZE
	nav.cell_height = CELL_HEIGHT
	nav.agent_radius = AGENT_RADIUS
	nav.agent_height = AGENT_HEIGHT
	nav.agent_max_climb = AGENT_MAX_CLIMB
	nav.agent_max_slope = AGENT_MAX_SLOPE
	nav.region_min_size = 4.0
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = PhysicsLayers.WORLD | PhysicsLayers.VEHICLES
	# Se incluye la altura completa: si se recortaran los techos, el interior
	# macizo de los edificios quedaría como suelo caminable.
	nav.filter_baking_aabb = AABB(Vector3(-half_size, -1.0, -half_size), Vector3(half_size * 2.0, 40.0, half_size * 2.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, source_root)
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = nav
	parent.add_child(region)
	return region
