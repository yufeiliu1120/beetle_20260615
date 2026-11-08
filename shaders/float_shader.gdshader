shader_type canvas_item;

// ==========================================
// 1. 动态变色系统变量 (Palette Swapping)[cite: 6]
// ==========================================
uniform vec4 theme_color : source_color = vec4(0.8, 0.3, 0.2, 1.0);
uniform vec4 decorative_color : source_color = vec4(0.9, 0.8, 0.2, 1.0);

uniform float shadow_factor : hint_range(0.1, 1.0) = 0.5;
uniform float decor_shadow_factor : hint_range(0.1, 1.0) = 0.5;
uniform float decor_darkest_factor : hint_range(0.0, 1.0) = 0.25;

uniform vec4 mask_theme_bright : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 mask_theme_shadow : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 mask_decor_bright : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 mask_decor_shadow : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 mask_decor_darkest : source_color = vec4(1.0, 0.0, 1.0, 1.0);

uniform float tolerance : hint_range(0.0, 0.5) = 0.1;

// ==========================================
// 2. 沙子浮出登场特效变量 (Dissolve)[cite: 6]
// ==========================================
uniform float progress : hint_range(-0.1, 1.1) = -0.1;
uniform sampler2D mask_tex : filter_nearest, hint_default_white;
uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform float smoothness_level : hint_range(0.0, 0.5) = 0.15;

// ==========================================
// 3. 战斗受击特效变量 (Hit Flash)[cite: 6]
// ==========================================
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;

// ==========================================
// 4. 【新增】：死亡消散特效变量 (Death Dissolve)
// ==========================================
// 设置最大值为 1.1 确保噪点边缘完全越过 1.0
uniform float death_progress : hint_range(0.0, 1.1) = 0.0; 

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 final_color = tex_color;
    
    if (tex_color.a > 0.0) {
        
        // ------------------------------------------
        // 阶段 A：沙子浮出 / 溶解逻辑[cite: 6]
        // ------------------------------------------
        float mask_val = texture(mask_tex, UV).r;
        float noise_offset = texture(noise_tex, UV * 4.0).r;
        
        float final_mask = mask_val + (noise_offset - 0.5) * smoothness_level;
        
        if (final_mask > progress) {
            final_color.a = 0.0;
        }
        
        // ------------------------------------------
        // 阶段 B：动态变色遮罩替换[cite: 6]
        // ------------------------------------------
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
            // 阶段 C：后期叠加受击闪白效果[cite: 6]
            // ------------------------------------------
            final_color.rgb = mix(final_color.rgb, vec3(1.0), flash_modifier);
            
            // ------------------------------------------
            // 阶段 D：【新增】基于噪声的死亡侵蚀与闪白
            // ------------------------------------------
            // 只要 progress 大于 0，才激活该功能，不会消耗平时运行的性能
            if (death_progress > 0.0) {
                // 复用你的噪波图，乘以 3.0 改变纹理密度，使其和出场时的沙子表现拉开差异
                float death_noise = texture(noise_tex, UV * 3.0).r; 
                
                // 消散边缘“白化层”的厚度
                float edge_thickness = 0.15; 
                
                // 1. 如果噪点值已经被进度吞没，该像素彻底消散
                if (death_noise < death_progress) {
                    final_color.a = 0.0; 
                } 
                // 2. 如果噪点处于“即将被吞没”的边缘范围内，计算一个渐变的纯白叠加
                else if (death_noise < death_progress + edge_thickness) {
                    // 算出当前像素在白边中的比例 (0.0 到 1.0)
                    float white_mix = 1.0 - ((death_noise - death_progress) / edge_thickness);
                    // 越靠近侵蚀边缘，白色越强烈
                    final_color.rgb = mix(final_color.rgb, vec3(1.0), white_mix);
                }
            }
        }
    }
    
    COLOR = final_color;
}