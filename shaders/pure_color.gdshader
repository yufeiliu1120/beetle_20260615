shader_type canvas_item;

uniform vec4 icon_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    // 获取当前像素
    vec4 current_color = texture(TEXTURE, UV);
    // 只要该像素有内容 (不透明)，就将其替换为我们设定的图标颜色
    if (current_color.a > 0.1) {
        COLOR = vec4(icon_color.rgb, current_color.a);
    } else {
        COLOR = vec4(0.0);
    }
}
