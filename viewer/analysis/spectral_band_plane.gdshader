shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never;
// This texture holds normalized presentation values only. The float64 CPU
// measurements, exact units and source identity remain with the controller.
uniform sampler2D display_values : filter_nearest, repeat_disable;
uniform vec2 source_extent = vec2(1.0);
uniform vec2 first_center = vec2(0.0);
uniform vec2 center_hop = vec2(1.0);
uniform vec2 center_count = vec2(1.0);
uniform float opacity : hint_range(0.0,1.0) = 0.8;
uniform int palette = 0;
vec3 color_for(float value) {
    if(palette==1) return vec3(value);
    if(palette==2) return mix(vec3(0.12,0.04,0.25),mix(vec3(0.85,0.22,0.12),vec3(1.0,0.93,0.55),max(0.0,2.0*value-1.0)),min(1.0,2.0*value));
    return mix(vec3(0.12,0.10,0.35),mix(vec3(0.06,0.60,0.57),vec3(0.95,0.94,0.25),max(0.0,2.0*value-1.0)),min(1.0,2.0*value));
}
void fragment() {
    vec2 grid=(UV*source_extent-first_center)/center_hop;
    vec2 address=floor(grid+vec2(0.5));
    bool requested=all(greaterThanEqual(address,vec2(0.0))) && all(lessThan(address,center_count));
    float value=requested ? texture(display_values,(address+vec2(0.5))/center_count).r : -1.0;
    bool measured=requested && value>=0.0;
    vec2 cell=grid-address;
    float hatch=step(0.5,fract((UV.x+UV.y)*45.0));
    vec3 color=measured ? color_for(clamp(value,0.0,1.0)) : mix(vec3(0.18),vec3(0.45),hatch);
    vec2 aa=max(fwidth(grid),vec2(0.001));
    float border=max(smoothstep(0.5-aa.x,0.5,abs(cell.x)),smoothstep(0.5-aa.y,0.5,abs(cell.y)));
    if(requested) color=mix(color,vec3(0.05),border*0.75);
    // A dot is a measured center. Crosses identify requested unavailable centers.
    bool dot=measured && length(cell)<0.055;
    bool cross=requested && !measured && max(abs(cell.x),abs(cell.y))<0.10 && min(abs(cell.x-cell.y),abs(cell.x+cell.y))<0.025;
    if(dot || cross) color=vec3(1.0);
    ALBEDO=color;
    ALPHA=opacity*(measured ? 1.0 : 0.4);
}
