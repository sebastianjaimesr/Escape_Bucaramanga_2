shader_type sky;
// Cielo de Bucaramanga: degradado, sol con halo, nubes y estrellas.
//
// Reemplaza al ProceduralSkyMaterial. Todo se calcula en el shader (sin
// texturas). Las nubes son fijas (no usan TIME) para que el mapa de radiancia
// no se recalcule cada cuadro: así el costo en celulares es el de dibujar el
// fondo y nada más. TimeOfDay cambia los uniformes según la hora y la lluvia.
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.24, 0.42, 0.74);
uniform vec3 horizon_color : source_color = vec3(0.92, 0.76, 0.6);
uniform vec3 ground_horizon_color : source_color = vec3(0.72, 0.62, 0.54);
uniform vec3 ground_bottom_color : source_color = vec3(0.2, 0.19, 0.2);
uniform float sky_curve = 0.12;
uniform float sun_size = 1.6;          // Radio del disco en grados.
uniform float sun_halo = 0.6;          // Fuerza del halo alrededor del sol.
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform vec3 cloud_light : source_color = vec3(1.0, 0.95, 0.9);
uniform vec3 cloud_dark : source_color = vec3(0.62, 0.62, 0.7);
uniform float stars : hint_range(0.0, 1.0) = 0.0;
uniform float energy = 1.0;
uniform int cloud_octaves = 4;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= cloud_octaves) {
			break;
		}
		v += vnoise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float y = dir.y;
	vec3 col;
	if (y >= 0.0) {
		// Igual que el cielo procedural de Godot: el color del horizonte se
		// queda en una franja baja y arriba manda el azul.
		float c = 1.0 - acos(clamp(y, 0.0, 1.0)) / (PI * 0.5);
		col = mix(horizon_color, top_color, clamp(1.0 - pow(1.0 - c, 1.0 / max(sky_curve, 0.01)), 0.0, 1.0));
	} else {
		float t = clamp(pow(1.0 + y, 6.0), 0.0, 1.0);
		col = mix(ground_bottom_color, ground_horizon_color, t);
	}

	vec3 sun_dir = vec3(0.0, 1.0, 0.0);
	vec3 sun_col = vec3(0.0);
	if (LIGHT0_ENABLED) {
		sun_dir = LIGHT0_DIRECTION;
		sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	}
	float sun_dot = max(dot(dir, sun_dir), 0.0);
	float ang = degrees(acos(clamp(dot(dir, sun_dir), -1.0, 1.0)));

	// Estrellas (solo de noche y sobre el horizonte).
	if (stars > 0.0 && y > 0.0) {
		vec2 g = dir.xz / (y + 0.35) * 220.0;
		vec2 cell = floor(g);
		float h = hash12(cell);
		if (h > 0.985) {
			vec2 c = fract(g) - 0.5;
			float tw = 0.6 + 0.4 * hash12(cell + 3.7);
			float s = smoothstep(0.32, 0.0, length(c)) * tw;
			col += vec3(s) * stars * smoothstep(0.0, 0.25, y);
		}
	}

	// Halo del sol (también tiñe el horizonte cerca de él).
	col += sun_col * pow(sun_dot, 8.0) * 0.12 * sun_halo;
	col += sun_col * pow(sun_dot, 64.0) * 0.35 * sun_halo;

	// Nubes: capa plana proyectada sobre el cielo.
	float cloud_a = 0.0;
	if (y > 0.0 && cloud_cover > 0.001) {
		vec2 uv = dir.xz / (y + 0.25) * 1.1;
		float n = fbm(uv);
		float cover = 1.0 - cloud_cover;
		cloud_a = smoothstep(cover - 0.08, cover + 0.22, n);
		// Cerca del horizonte las nubes se funden con la bruma.
		cloud_a *= smoothstep(0.02, 0.3, y);
		// Sombra interna: más oscuro donde la nube es más espesa.
		float thick = smoothstep(cover, cover + 0.5, n);
		vec3 cc = mix(cloud_light, cloud_dark, thick * 0.85);
		// Borde iluminado por el sol.
		cc += sun_col * pow(sun_dot, 6.0) * 0.45 * (1.0 - thick);
		col = mix(col, cc, cloud_a * 0.92);
	}

	// Disco del sol (tapado por las nubes).
	if (!AT_CUBEMAP_PASS) {
		float disc = smoothstep(sun_size, sun_size * 0.7, ang);
		col += sun_col * disc * 3.0 * (1.0 - cloud_a);
	}

	COLOR = col * energy;
}
