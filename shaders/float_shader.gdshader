shader_type canvas_item;

// ==========================================
// 1. 动态变色系统变量 (Palette Swapping)
// ==========================================
uniform vec4 theme_color : source_color = vec4(0.8, 0.3, 0.2, 1.0);
uniform vec4 decorative_color : source_color = vec4(0.9, 0.8, 0.2, 1.0);

// 阴影衰减系数
uniform float shadow_factor : hint_range(0.1, 1.0) = 0.5;
uniform float decor_shadow_factor : hint_range(0.1, 1.0) = 0.5;
uniform float decor_darkest_factor : hint_range(0.0, 1.0) = 0.25; 

// 纯色美术标记
uniform vec4 mask_theme_bright : source_color = vec4(1.0, 0.0, 0.0, 1.0);  // 纯红
uniform vec4 mask_theme_shadow : source_color = vec4(0.0, 1.0, 0.0, 1.0);  // 纯绿
uniform vec4 mask_decor_bright : source_color = vec4(0.0, 0.0, 1.0, 1.0);  // 纯蓝
uniform vec4 mask_decor_shadow : source_color = vec4(1.0, 1.0, 0.0, 1.0);  // 纯黄
uniform vec4 mask_decor_darkest : source_color = vec4(1.0, 0.0, 1.0, 1.0); // 纯紫

uniform float tolerance : hint_range(0.0, 0.5) = 0.1;

// ==========================================
// 2. 沙子浮出登场特效变量 (Dissolve)
// ==========================================
// 显现进度：-0.1 到 1.1
uniform float progress : hint_range(-0.1, 1.1) = -0.1;
// 平滑遮罩图与噪波图
uniform sampler2D mask_tex : filter_nearest, hint_default_white;
uniform sampler2D noise_tex : repeat_enable, filter_nearest;
// 边缘颗粒感厚度
uniform float smoothness_level : hint_range(0.0, 0.5) = 0.15;

// ==========================================
// 3. 战斗受击特效变量 (Hit Flash)
// ==========================================
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // 获取像素原始颜色
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 final_color = tex_color; 
    
    // 如果像素本来就是完全透明的（比如图片边缘空白处），直接跳过所有计算
    if (tex_color.a > 0.0) {
        
        // ------------------------------------------
        // 阶段 A：沙子浮出 / 溶解逻辑
        // ------------------------------------------
        float mask_val = texture(mask_tex, UV).r;
        float noise_offset = texture(noise_tex, UV * 4.0).r;
        
        float final_mask = mask_val + (noise_offset - 0.5) * smoothness_level;
        
        if (final_mask > progress) {
            // 动画进度还没扫到这里，该像素设置为透明（隐藏）
            final_color.a = 0.0; 
        }
        
        // ------------------------------------------
        // 阶段 B：动态变色遮罩替换
        // ------------------------------------------
        // 只有当该像素度过了溶解阶段（依然可见），才进行变色计算
        if (final_color.a > 0.0) {
            vec3 gen_theme_shadow = theme_color.rgb * shadow_factor;
            vec3 gen_decor_shadow = decorative_color.rgb * decor_shadow_factor;
            vec3 gen_decor_darkest = decorative_color.rgb * decor_darkest_factor;
            
            if (distance(tex_color.rgb, mask_theme_bright.rgb) < tolerance) {
                final_color.rgb = theme_color.rgb;
            } 
            else if (distance(tex_color.rgb, mask_theme_shadow.rgb) < tolerance) {
                final_color.rgb = gen_theme_shadow;
            } 
            else if (distance(tex_color.rgb, mask_decor_bright.rgb) < tolerance) {
                final_color.rgb = decorative_color.rgb;
            } 
            else if (distance(tex_color.rgb, mask_decor_shadow.rgb) < tolerance) {
                final_color.rgb = gen_decor_shadow;
            }
            else if (distance(tex_color.rgb, mask_decor_darkest.rgb) < tolerance) {
                final_color.rgb = gen_decor_darkest; 
            }
            
            // ------------------------------------------
            // 阶段 C：后期叠加受击闪白效果
            // ------------------------------------------
            // 将替换完颜色的像素，与纯白色混合
            final_color.rgb = mix(final_color.rgb, vec3(1.0), flash_modifier);
        }
    }
    
    COLOR = final_color;
}