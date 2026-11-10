shader_type spatial;
render_mode cull_disabled;
// Shared material for every procedural food model (see scripts/meshgen.gd).
// Vertex colour = raw look; per-instance uniforms drive cooking live:
//   br   browning 0..1 toward `brown` (the ingredient's cooked colour)
//   ch   charring 0..1 toward black crust
//   mud  1 while dirty produce is unwashed

instance uniform float br = 0.0;
instance uniform float ch = 0.0;
instance uniform float mud = 0.0;
instance uniform vec3 brown = vec3(0.62, 0.38, 0.16);

varying vec3 opos;

vec3 to_lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 base = min(to_lin(COLOR.rgb), vec3(0.8));
	float s = COLOR.a;
	float rough = UV.x;
	float bmp = UV.y;
	float n1 = vnoise(opos * 90.0);
	float n2 = vnoise(opos * 260.0 + 11.0);
	float fbm = n1 * 0.6 + n2 * 0.4;
	float big = vnoise(opos * 28.0 + 3.0);
	vec3 c = base * (0.95 + 0.1 * fbm);

	// browning: patchy, keeps the light/dark pattern of the raw surface
	float b = smoothstep(0.0, 0.85, br * s * (0.8 + 0.45 * big));
	float lum = sqrt(dot(base, vec3(0.2126, 0.7152, 0.0722)));
	vec3 bt = to_lin(brown) * clamp(0.5 + 0.9 * lum, 0.55, 1.35) * (0.85 + 0.3 * fbm);
	c = mix(c, bt, b);
	rough = mix(rough, min(rough, 0.42), b * 0.6);

	// charring: black crust that spreads from noisy patches
	float k = clamp(ch * s * (1.0 + (big - 0.5) * 1.4) * 1.3, 0.0, 1.0);
	vec3 charc = vec3(0.018, 0.014, 0.011) + vec3(0.05, 0.028, 0.012) * n2;
	c = mix(c, charc, k);
	rough = mix(rough, 0.92, k);
	bmp += k * 1.2 + b * 0.2;

	// mud on unwashed produce: soft blotches, heavier toward the bottom
	vec3 mp = opos * 24.0 + vec3(opos.y * 9.0, opos.z * 7.0, opos.x * 8.0);
	float mn = vnoise(mp) * 0.6 + vnoise(mp * 2.3 + 5.0) * 0.4;
	float low = smoothstep(0.08, 0.0, opos.y);
	float m = mud * step(0.01, s) * smoothstep(0.45, 0.62, mn + (low - 0.4) * 0.35);
	c = mix(c, to_lin(vec3(0.36, 0.27, 0.17)) * (0.75 + 0.5 * n2), m * 0.85);
	rough = mix(rough, 0.97, m);
	bmp += m * 0.8;

	vec3 N = FRONT_FACING ? NORMAL : -NORMAL;
	if (bmp > 0.001) {
		float h = (fbm * 0.7 + big * 0.3) * bmp * 0.0035;
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		vec3 r1 = cross(dpdy, N);
		vec3 r2 = cross(N, dpdx);
		float det = dot(dpdx, r1);
		if (abs(det) > 1e-14) {
			vec3 g = (dFdx(h) * r1 + dFdy(h) * r2) / det;
			N = normalize(N - g);
		}
	}
	NORMAL = N;
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = UV2.x;
	SPECULAR = 0.5;
}
