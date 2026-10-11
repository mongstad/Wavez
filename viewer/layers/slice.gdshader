shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform sampler3D field_texture : filter_linear, repeat_disable;
uniform sampler2D transfer : source_color, filter_linear, repeat_disable;
uniform mat4 world_to_grid;
uniform vec3 grid_size;
uniform vec3 texture_size;
uniform vec3 bounds_min;
uniform vec3 bounds_max;
uniform bool color_log = false;
uniform float lower = 0.0;
uniform float upper = 1.0;
varying vec3 world;
// Match the existing normalized coordinates and clamp-to-edge RF preview.
// Nonfinite neighborhoods retain the hardware sampler's presentation footprint,
// including zero-weight corners; they never enter explicit mix arithmetic.
float slice_value(vec3 uv) {
    ivec3 n=textureSize(field_texture,0);
    vec3 g=clamp(uv*vec3(n)-vec3(0.5),vec3(0.0),vec3(n-ivec3(1)));
    ivec3 lo=ivec3(floor(g)),hi=min(lo+ivec3(1),n-ivec3(1));
    vec3 f=fract(g);
    vec4 a=vec4(texelFetch(field_texture,lo,0).r,
        texelFetch(field_texture,ivec3(hi.x,lo.y,lo.z),0).r,
        texelFetch(field_texture,ivec3(lo.x,hi.y,lo.z),0).r,
        texelFetch(field_texture,ivec3(hi.x,hi.y,lo.z),0).r);
    vec4 b=vec4(texelFetch(field_texture,ivec3(lo.x,lo.y,hi.z),0).r,
        texelFetch(field_texture,ivec3(hi.x,lo.y,hi.z),0).r,
        texelFetch(field_texture,ivec3(lo.x,hi.y,hi.z),0).r,
        texelFetch(field_texture,hi,0).r);
    if(any(isnan(a)) || any(isinf(a)) || any(isnan(b)) || any(isinf(b)))
        return texture(field_texture,uv).r;
    return mix(mix(mix(a.x,a.y,f.x),mix(a.z,a.w,f.x),f.y),
        mix(mix(b.x,b.y,f.x),mix(b.z,b.w,f.x),f.y),f.z);
}
void vertex() { world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec3 g=(world_to_grid*vec4(world,1.0)).xyz;
    if(any(lessThan(g,bounds_min)) || any(greaterThan(g,bounds_max))) discard;
    vec3 uv=(g/(grid_size-vec3(1.0))*(texture_size-vec3(1.0))+vec3(0.5))/texture_size;
    float value=slice_value(uv);
    if(isnan(value) || isinf(value)) discard;
    float u=clamp((value-lower)/max(upper-lower,1e-38),0.0,1.0);
    if(color_log) u=clamp((log(max(value,lower))-log(lower))/(log(upper)-log(lower)),0.0,1.0);
    ALBEDO=texture(transfer,vec2((u*255.0+0.5)/256.0,0.5)).rgb;
}
