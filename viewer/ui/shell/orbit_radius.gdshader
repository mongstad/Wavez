shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

// Opaque annotation surface in its own world. Canvas composition retains a
// little field context, while the rim and world rings define a clear boundary.
void fragment() {
	vec3 normal = normalize(NORMAL);
	if (!FRONT_FACING) normal = -normal;
	vec3 light = normalize(vec3(-0.45, 0.65, 0.65));
	float shade = 0.24 + 0.76 * max(dot(normal, light), 0.0);
	float rim = pow(1.0 - abs(dot(normal, normalize(VIEW))), 4.0);
	ALBEDO = mix(vec3(0.36, 0.20, 0.72) * shade, vec3(0.90, 0.84, 1.0), rim * 0.85);
}
