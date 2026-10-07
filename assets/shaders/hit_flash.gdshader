shader_type canvas_item;
// Draws the sprite as one flat colour, keeping its shape. Used for hit flashes.

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	COLOR = vec4(flash_color.rgb, COLOR.a);
}
