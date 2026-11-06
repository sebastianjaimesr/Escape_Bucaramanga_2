shader_type canvas_item;
// Fondo animado de la portada, en una sola pasada y sin texturas:
// cielo de atardecer que se vuelve noche, montañas a lo lejos, una silueta de
// ciudad con ventanas que se encienden y apagan, el destello azul y rojo de una
// patrulla al fondo, polvo flotando, viñeta y grano de película.
// Con reduce_motion = true todo queda quieto.

uniform float reduce_motion = 0.0;
uniform vec2 resolution = vec2(1280.0, 720.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ridge(float x, float freq, float seed) {
	return sin(x * freq + seed) * 0.5 + sin(x * freq * 2.3 + seed * 1.7) * 0.25 + sin(x * freq * 5.1 + seed * 0.3) * 0.1;
}

void fragment() {
	float t = TIME * (1.0 - reduce_motion);
	vec2 uv = UV;
	float aspect = resolution.x / max(resolution.y, 1.0);
	vec2 p = vec2(uv.x * aspect, 1.0 - uv.y);   // y hacia arriba

	// Cielo: índigo arriba, ámbar quemado en el horizonte.
	vec3 top = vec3(0.035, 0.04, 0.085);
	vec3 mid = vec3(0.13, 0.07, 0.12);
	vec3 horizon = vec3(0.62, 0.3, 0.13);
	float h = clamp(p.y, 0.0, 1.0);
	vec3 col = mix(horizon, mid, smoothstep(0.18, 0.42, h));
	col = mix(col, top, smoothstep(0.4, 0.95, h));
	// Resplandor del sol ya puesto, a la derecha.
	float sun = exp(-pow(length((p - vec2(aspect * 0.72, 0.2)) * vec2(0.8, 2.2)), 2.0) * 3.0);
	col += vec3(0.55, 0.25, 0.08) * sun * 0.55;

	// Estrellas tenues arriba.
	vec2 sg = floor(p * vec2(160.0, 160.0));
	float star = step(0.9965, hash(sg)) * smoothstep(0.5, 0.95, h);
	star *= 0.5 + 0.5 * sin(t * 2.0 + hash(sg + 3.1) * 40.0);
	col += vec3(star) * 0.6;

	// Montañas en dos capas.
	float m1 = 0.30 + ridge(p.x, 1.4, 1.0) * 0.06;
	float m2 = 0.24 + ridge(p.x, 2.2, 4.0) * 0.045;
	col = mix(col, vec3(0.09, 0.06, 0.09), smoothstep(0.003, 0.0, p.y - m1) * 0.85);
	col = mix(col, vec3(0.05, 0.04, 0.06), smoothstep(0.003, 0.0, p.y - m2));

	// Ciudad: columnas de edificios de altura pseudoaleatoria.
	float bw = 0.035;
	float bx = floor(p.x / bw);
	float bh = 0.08 + hash(vec2(bx, 7.0)) * 0.13 + step(0.86, hash(vec2(bx, 2.0))) * 0.08;
	float inside = step(p.y, bh);
	vec3 bcol = vec3(0.025, 0.025, 0.035);
	// Ventanas: rejilla dentro de cada edificio, algunas encendidas.
	vec2 wcell = vec2(fract(p.x / bw) * 4.0, p.y / 0.016);
	vec2 wid = vec2(bx * 4.0 + floor(wcell.x), floor(wcell.y));
	float win = step(0.25, fract(wcell.x)) * step(fract(wcell.x), 0.75) * step(0.3, fract(wcell.y)) * step(fract(wcell.y), 0.75);
	float lit = step(0.72, hash(wid + floor(t * 0.08 + hash(wid) * 10.0)));
	float warm = hash(wid + 9.0);
	vec3 wcol = mix(vec3(1.0, 0.72, 0.35), vec3(0.75, 0.85, 1.0), step(0.8, warm));
	// Las ventanas se apagan hacia la izquierda, donde va el texto.
	bcol += wcol * win * lit * step(p.y, bh - 0.012) * 0.75 * mix(0.2, 1.0, smoothstep(0.1, 0.65, uv.x));
	col = mix(col, bcol, inside);

	// Patrulla al fondo de la calle: destellos azul y rojo que se alternan.
	float siren = sin(t * 7.0);
	vec2 sp = vec2(aspect * 0.18, 0.03);
	float glow = exp(-length((p - sp) * vec2(1.2, 3.0)) * 6.0);
	col += mix(vec3(0.1, 0.25, 0.9), vec3(0.95, 0.12, 0.1), step(0.0, siren)) * glow * (0.35 + 0.25 * abs(siren));

	// Bruma baja sobre la ciudad.
	col += vec3(0.35, 0.18, 0.1) * smoothstep(0.2, 0.0, p.y) * 0.18;

	// Polvo flotando.
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 q = uv * (6.0 + fi * 4.0) + vec2(t * 0.02 * (fi + 1.0), -t * 0.035 * (fi + 1.0));
		vec2 cell = floor(q);
		vec2 f = fract(q) - 0.5;
		vec2 o = vec2(hash(cell + fi), hash(cell + fi + 5.0)) - 0.5;
		float d = length(f - o * 0.7);
		col += vec3(1.0, 0.8, 0.55) * smoothstep(0.035, 0.0, d) * step(0.6, hash(cell * 1.3 + fi)) * 0.12;
	}

	// Oscurecer el lado izquierdo para que el texto se lea bien.
	col *= mix(0.42, 1.0, smoothstep(0.05, 0.75, uv.x));
	// Viñeta y grano.
	float vig = smoothstep(1.25, 0.35, length((uv - 0.5) * vec2(1.25, 1.0)));
	col *= mix(0.55, 1.0, vig);
	col += (hash(uv * resolution + fract(t) * 100.0) - 0.5) * 0.035 * (1.0 - reduce_motion);
	COLOR = vec4(col, 1.0);
}
