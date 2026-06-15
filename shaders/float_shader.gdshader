shader_type canvas_item;

// ====== 沙子浮出功能变量 ======
// 显现进度：-0.1 到 1.1
uniform float progress : hint_range(-0.1, 1.1) = -0.1;
// 平滑遮罩图与噪波图
uniform sampler2D mask_tex : filter_nearest, hint_default_white;
uniform sampler2D noise_tex : repeat_enable, filter_nearest;
// 边缘颗粒感厚度
uniform float smoothness_level : hint_range(0.0, 0.5) = 0.15;

// ====== 受击闪白功能变量 (新增) ======
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // 1. 获取原图颜色与遮罩数据
    vec4 tex_color = texture(TEXTURE, UV);
    float mask_val = texture(mask_tex, UV).r;
    float noise_offset = texture(noise_tex, UV * 4.0).r;
    
    float final_mask = mask_val + (noise_offset - 0.5) * smoothness_level;
    vec4 final_color = tex_color;
    
    // 2. 沙子显现逻辑 (控制 Alpha 透明度)
    if (tex_color.a > 0.0) {
        if (final_mask > progress) {
            // 核心修改：不再染成沙子，而是直接将其变为透明
            final_color.a = 0.0;
        } 
    }
    
    // 3. 受击闪白逻辑 (控制 RGB 色彩)
    // 核心原理：只改变色彩，保留上方沙子逻辑计算出的 final_color.a
    // 这样被沙子隐藏的部分依然是透明的，不会变成突兀的白色方块
    final_color.rgb = mix(final_color.rgb, flash_color.rgb, flash_modifier);
    
    // 4. 输出最终颜色
    COLOR = final_color;
}