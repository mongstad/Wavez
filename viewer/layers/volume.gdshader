shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;
uniform sampler3D field_texture : filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D transfer : source_color, filter_linear, repeat_disable;
uniform mat4 world_to_grid;
uniform vec3 grid_size;
uniform vec3 texture_size;
uniform vec3 bounds_min;
uniform vec3 bounds_max;
uniform bool color_log = false;
uniform float lower = 0.0;
uniform float upper = 1.0;
uniform float opacity = 0.25;
uniform bool opacity_magnitude = false;
uniform float opacity_lower = 0.0;
uniform float opacity_upper = 1.0;
uniform float step_world = 0.5;
uniform bool clip_enabled = false;
uniform vec4 clip_plane = vec4(1.0,0.0,0.0,0.0);
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
vec3 view_at(vec2 uv, float depth, mat4 inverse_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(uv,depth)*2.0-1.0;
#else
    vec3 ndc = vec3(uv*2.0-1.0,depth);
#endif
    vec4 p = inverse_projection*vec4(ndc,1.0);
    return p.xyz/p.w;
}
vec3 uv_at(vec3 g) { return (g/(grid_size-vec3(1.0))*(texture_size-vec3(1.0))+vec3(0.5))/texture_size; }
void fragment() {
    vec3 near_view = view_at(SCREEN_UV,1.0,INV_PROJECTION_MATRIX);
    vec3 far_view = view_at(SCREEN_UV,0.000001,INV_PROJECTION_MATRIX);
    vec3 ro = (INV_VIEW_MATRIX*vec4(near_view,1.0)).xyz;
    vec3 rd = normalize((INV_VIEW_MATRIX*vec4(far_view-near_view,0.0)).xyz);
    vec3 go = (world_to_grid*vec4(ro,1.0)).xyz;
    vec3 gd = (world_to_grid*vec4(rd,0.0)).xyz;
    vec3 reciprocal = 1.0/(sign(gd+vec3(1e-20))*max(abs(gd),vec3(1e-8)));
    vec3 t0 = (bounds_min-go)*reciprocal;
    vec3 t1 = (bounds_max-go)*reciprocal;
    vec3 low = min(t0,t1), high = max(t0,t1);
    float begin = max(0.0,max(low.x,max(low.y,low.z)));
    float end = min(high.x,min(high.y,high.z));
    float depth = texture(depth_texture,SCREEN_UV).r;
    vec3 surface = (INV_VIEW_MATRIX*vec4(view_at(SCREEN_UV,max(depth,0.000001),INV_PROJECTION_MATRIX),1.0)).xyz;
    end = min(end,dot(surface-ro,rd));
    if(end<=begin) discard;
    // A hard iteration limit increases the effective step explicitly over long rays.
    float step_length = max(step_world,(end-begin)/1024.0);
    vec4 accum = vec4(0.0);
    for(int i=0;i<1024;i++) {
        float t=begin+float(i)*step_length;
        if(t>=end || accum.a>0.995) break;
        float dt=min(step_length,end-t);
        vec3 world=ro+rd*(t+dt*0.5);
        if(clip_enabled && dot(clip_plane.xyz,world)>clip_plane.w) continue;
        float value=texture(field_texture,uv_at(go+gd*(t+dt*0.5))).r;
        if(isnan(value) || isinf(value)) continue;
        float u=clamp((value-lower)/max(upper-lower,1e-38),0.0,1.0);
        if(color_log) u=clamp((log(max(value,lower))-log(lower))/(log(upper)-log(lower)),0.0,1.0);
        // Extinction has its own scalar thresholds; signed color ranges do
        // not give zero-valued space the midpoint's opacity.
        float opacity_value=opacity_magnitude ? abs(value) : value;
        float weight=clamp((opacity_value-opacity_lower)/max(opacity_upper-opacity_lower,1e-38),0.0,1.0);
        float a=1.0-exp(-max(opacity,0.0)*weight*dt);
        vec3 color=texture(transfer,vec2((u*255.0+0.5)/256.0,0.5)).rgb;
        accum.rgb+=(1.0-accum.a)*a*color;
        accum.a+=(1.0-accum.a)*a;
    }
    ALBEDO=accum.rgb/max(accum.a,1e-8);ALPHA=accum.a;
}
