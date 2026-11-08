shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int outline_width : hint_range(0, 10) = 1;
// 开启后为经典像素画的十字/菱形轮廓；关闭则为方形轮廓
uniform bool pixel_style = true; 

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    
    // 1. 如果当前像素已经是完全不透明的主体，直接保留原图
    // (为了防止浮点数精度误差，这里使用 > 0.99 而不是 == 1.0)
    if (original_color.a > 0.99) {
        COLOR = original_color;
    } else {
        // 2. 当前像素为透明或半透明（例如阴影）时，探测其周围的像素
        bool is_outline = false;
        
        for (int x = -outline_width; x <= outline_width; x++) {
            for (int y = -outline_width; y <= outline_width; y++) {
                if (x == 0 && y == 0) continue;
                
                // 像素画菱形轮廓判定
                if (pixel_style && (abs(x) + abs(y) > outline_width)) {
                    continue;
                }
                
                vec2 sample_uv = UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE;
                vec4 sample_color = texture(TEXTURE, sample_uv);
                
                // 【核心逻辑】：只有探测到了透明度严格为 1 的像素，才会被视为碰到了主体
                if (sample_color.a > 0.99) {
                    is_outline = true;
                    break;
                }
            }
            if (is_outline) break;
        }
        
        // 3. 最终输出
        if (is_outline) {
            // 如果挨着主体，将其覆盖为纯色轮廓
            COLOR = outline_color;
        } else {
            // 如果没挨着主体（比如向外延伸的阴影区，或纯透明背景），原样输出
            COLOR = original_color;
        }
    }
}