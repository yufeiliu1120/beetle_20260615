shader_type canvas_item;

// 闪白控制
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 消散控制
uniform sampler2D noise_tex;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // 1. 闪烁混合：根据 flash_amount 在原图颜色和纯白色之间过渡
    vec3 final_color = mix(tex_color.rgb, flash_color.rgb, flash_amount);
    
    // 2. 像素风消散：读取噪点图，使用 step 函数保持像素的硬边缘裁切
    float noise_val = texture(noise_tex, UV).r;
    float alpha = tex_color.a * step(dissolve_amount, noise_val);
    
    COLOR = vec4(final_color, alpha);
}