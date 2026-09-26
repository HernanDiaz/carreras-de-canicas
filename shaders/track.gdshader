shader_type spatial;
// Material de las piezas de la pista. Dibuja un patrón en la cara superior,
// franjas en los laterales y un borde luminoso en todas las aristas.

// 0 = damero, 1 = flechas (rampas), 2 = franjas de peligro
uniform int pattern = 0;
uniform vec3 color_a : source_color = vec3(0.78, 0.76, 0.9);
uniform vec3 color_b : source_color = vec3(0.64, 0.6, 0.82);
uniform vec3 side_color : source_color = vec3(0.32, 0.27, 0.52);
uniform vec3 edge_color : source_color = vec3(0.85, 0.9, 1.0);
// Tamaño de la caja (en espacio local), para saber dónde están las aristas.
uniform vec3 box_size = vec3(1.0);
uniform float tile_size = 1.0;
uniform float edge_width = 0.06;
uniform float edge_glow = 0.8;
// Si está activo, el patrón también se pinta en los laterales.
uniform bool pattern_on_sides = false;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

// Damero filtrado (sin parpadeo a distancia).
float checker(vec2 p) {
	vec2 w = max(fwidth(p), vec2(0.0001));
	vec2 i = 2.0 * (abs(fract((p - 0.5 * w) * 0.5) - 0.5) - abs(fract((p + 0.5 * w) * 0.5) - 0.5)) / w;
	return 0.5 - 0.5 * i.x * i.y;
}

float stripes(float v) {
	float w = max(fwidth(v), 0.0001);
	return smoothstep(0.5 - w, 0.5 + w, fract(v)) - smoothstep(1.0 - w, 1.0, fract(v));
}

vec3 pattern_color(vec2 p) {
	float t;
	if (pattern == 1) {
		// Flechas apuntando hacia -z local (la bajada de la rampa).
		t = stripes((p.y - abs(p.x - box_size.x * 0.5) * 0.9) / (tile_size * 1.5));
	} else if (pattern == 2) {
		t = stripes((p.x + p.y) / (tile_size * 0.6));
	} else {
		t = checker(p / tile_size);
	}
	return mix(color_a, color_b, t);
}

void fragment() {
	vec3 hs = box_size * 0.5;
	vec3 d = hs - abs(local_pos);
	vec3 n = abs(local_normal);
	vec3 p = local_pos + hs;

	float edge;
	vec2 face_uv;
	if (n.y > 0.5) {
		edge = min(d.x, d.z);
		face_uv = p.xz;
	} else if (n.x > 0.5) {
		edge = min(d.y, d.z);
		face_uv = p.zy;
	} else {
		edge = min(d.x, d.y);
		face_uv = p.xy;
	}

	vec3 base;
	if (local_normal.y > 0.5 || pattern_on_sides) {
		base = pattern_color(face_uv);
	} else if (local_normal.y < -0.5) {
		base = side_color * 0.5;
	} else {
		// Laterales: franjas horizontales suaves que se oscurecen hacia abajo.
		float band = stripes(p.y * 2.0);
		float depth = clamp(p.y / max(box_size.y, 0.001), 0.0, 1.0);
		base = side_color * mix(0.8, 1.0, band) * mix(0.55, 1.0, depth);
	}

	float line = 1.0 - smoothstep(edge_width * 0.5, edge_width, edge);
	ALBEDO = mix(base, edge_color, line);
	EMISSION = edge_color * line * edge_glow;
	ROUGHNESS = 0.55;
	SPECULAR = 0.4;
}
