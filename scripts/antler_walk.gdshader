shader_type canvas_item;
uniform float phase = 0.0;
uniform float amount = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	// Animate the legs below the robe; do not bend the blade or antlers.
	float legs = smoothstep(0.70, 0.91, uv.y);
	float left_leg = smoothstep(0.44, 0.49, uv.x) * (1.0 - smoothstep(0.57, 0.63, uv.x));
	float right_leg = smoothstep(0.64, 0.69, uv.x) * (1.0 - smoothstep(0.79, 0.84, uv.x));
	float stride = sin(phase);
	uv.x -= stride * (left_leg - right_leg) * legs * 0.026 * amount;
	// Alternating swing feet lift; the supporting foot stays on the floor.
	uv.y += max(0.0, cos(phase)) * left_leg * legs * 0.024 * amount;
	uv.y += (max(0.0, -cos(phase)) * 0.024 - 0.032) * right_leg * legs * amount;
	float hem = smoothstep(0.56, 0.70, uv.y) * (1.0-smoothstep(0.79, 0.88, uv.y));
	float cloak = smoothstep(0.72, 0.90, uv.x);
	uv.x += sin(phase - 0.5) * hem * cloak * 0.004 * amount;
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0))) * tint;
}
