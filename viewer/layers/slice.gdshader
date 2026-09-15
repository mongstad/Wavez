shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform sampler3D field_texture : filter_linear, repeat_disable;
uniform sampler2D transfer : source_color, filter_linear, repeat_disable;
uniform mat4 world_to_grid;
uniform vec3 grid_size;
uniform vec3 texture_size;
uniform vec3 bounds_min;
uniform vec3 bounds_max;
uniform float lower = 0.0;
uniform float upper = 1.0;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec3 g=(world_to_grid*vec4(world,1.0)).xyz;
    if(any(lessThan(g,bounds_min)) || any(greaterThan(g,bounds_max))) discard;
    vec3 uv=(g/(grid_size-vec3(1.0))*(texture_size-vec3(1.0))+vec3(0.5))/texture_size;
    float value=texture(field_texture,uv).r;
    if(isnan(value) || isinf(value)) discard;
    float u=clamp((value-lower)/max(upper-lower,1e-38),0.0,1.0);
    ALBEDO=texture(transfer,vec2((u*255.0+0.5)/256.0,0.5)).rgb;
}
