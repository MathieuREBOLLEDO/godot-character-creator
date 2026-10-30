// Contour d'un CcSprite : posé sur le CanvasGroup qui réunit ses calques
// (sauf l'ombre), pour entourer tout le personnage d'un seul trait.
// width : épaisseur en pixels du pack ; pixel : pixels d'écran par pixel du
// pack (échelle globale, mise à jour par CcSprite). Forme en losange : le
// contour classique du pixel art.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.06, 1.0);
uniform int width = 1;
uniform float pixel = 1.0;

void fragment() {
	vec4 color = textureLod(screen_texture, SCREEN_UV, 0.0);
	// Le CanvasGroup rend ses enfants en couleurs prémultipliées.
	if (color.a > 0.0001) {
		color.rgb /= color.a;
	}
	if (color.a < 0.5) {
		float near = 0.0;
		for (int x = -width; x <= width; x++) {
			for (int y = -width; y <= width; y++) {
				if (abs(x) + abs(y) > width || (x == 0 && y == 0)) {
					continue;
				}
				vec2 offset = vec2(float(x), float(y)) * pixel * SCREEN_PIXEL_SIZE;
				near = max(near, textureLod(screen_texture, SCREEN_UV + offset, 0.0).a);
			}
		}
		if (near > 0.5) {
			color = vec4(outline_color.rgb, outline_color.a);
		}
	}
	COLOR = color;
}
