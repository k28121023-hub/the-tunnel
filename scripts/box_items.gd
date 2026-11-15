extends RefCounted
## Add item definitions here, then implement their effect in Player.
const DATA := {
	"sword": {"texture": preload("res://assets/items/sword.png"), "region": Rect2(415, 20, 425, 1200)},
	"cannon": {"texture": preload("res://assets/items/cannon.png"), "region": Rect2(35, 260, 1195, 725)},
	"armor": {"texture": preload("res://assets/items/armor.png"), "region": Rect2(48, 145, 1165, 970)},
	"potion": {"texture": preload("res://assets/items/potion.png"), "region": Rect2(265, 125, 720, 1008)},
}
static var fitted_textures: Dictionary = {}

static func texture_for(item_id: String) -> Texture2D:
	if not fitted_textures.has(item_id):
		var original: Texture2D = DATA[item_id].texture
		var atlas := AtlasTexture.new()
		atlas.atlas = original
		# Sprite regions exclude transparent margins/noise; source PNGs stay intact.
		atlas.region = DATA[item_id].region
		fitted_textures[item_id] = atlas
	return fitted_textures[item_id]

static func sprite_for(item_id: String, size: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture = texture_for(item_id)
	var dimensions := sprite.texture.get_size()
	sprite.scale = Vector2.ONE * size / maxf(dimensions.x, dimensions.y)
	return sprite
