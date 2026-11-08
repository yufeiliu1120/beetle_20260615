shader_type canvas_item;

// 1. 目标蓝色 RGB (9, 30, 65) 对应的归一化数值
uniform vec4 target_color : source_color = vec4(0.03529, 0.11765, 0.25490, 1.0);
// 颜色判定容差（蓝色可能带有阴影或渐变，增大容差可包含更多蓝色阶）
uniform float color_tolerance : hint_range(0.01, 0.5) = 0.18;

// 2. 描边设置
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int outline_width : hint_range(1, 10) = 2;
uniform bool pixel_style = true; // 开启为像素风格菱形描边，关闭为方形描边

// 3. 空间圆圈遮罩（用于排除周围散落的蓝色水晶）
uniform vec2 center_uv = vec2(0.5, 0.5); // 中心点位置（UV坐标）
uniform float mask_radius : hint_range(0.0, 1.0) = 0.35; // 允许检测的最大半径

// 辅助函数：判定某点 UV 是否属于中心目标水域
bool is_target_blue(sampler2D tex, vec2 uv) {
    // 步骤 A：空间距离限制（超出中心半径直接归零，强行排除周围水晶）
    if (distance(uv, center_uv) > mask_radius) {
        return false;
    }
    
    // 步骤 B：采样颜色
    vec4 col = texture(tex, uv);
    if (col.a < 0.01) {
        return false;
    }
    
    // 步骤 C：颜色匹配距离判定
    return distance(col.rgb, target_color.rgb) < color_tolerance;
}

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    bool current_is_target = is_target_blue(TEXTURE, UV);
    
    bool is_border = false;
    
    // 采样四周邻域像素进行边缘比较
    for (int x = -outline_width; x <= outline_width; x++) {
        for (int y = -outline_width; y <= outline_width; y++) {
            if (x == 0 && y == 0) continue;
            
            // 菱形曼哈顿距离过滤，防止 45 度角过厚
            if (pixel_style && (abs(x) + abs(y) > outline_width)) {
                continue;
            }
            
            vec2 sample_uv = UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE;
            bool neighbor_is_target = is_target_blue(TEXTURE, sample_uv);
            
            // 边缘检测核心逻辑：当前像素与邻接像素的目标状态不一致，说明正处于边缘交界处
            if (current_is_target != neighbor_is_target) {
                is_border = true;
                break;
            }
        }
        if (is_border) break;
    }
    
    // 输出最终颜色
    if (is_border) {
        COLOR = outline_color;
    } else {
        COLOR = original_color;
    }
}