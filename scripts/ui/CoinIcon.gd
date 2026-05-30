extends RefCounted
class_name CoinIcon
## 运行时生成金币图标，避免依赖缺失的 coin.png 资源。

static var _texture: Texture2D

static func texture() -> Texture2D:
	if _texture == null:
		_texture = _make_coin_texture(32)
	return _texture

static func make_icon(size_px: int) -> TextureRect:
	var coin := TextureRect.new()
	coin.texture = texture()
	coin.custom_minimum_size = Vector2(size_px, size_px)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return coin

static func _make_coin_texture(size_px: int) -> Texture2D:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(float(size_px - 1) * 0.5, float(size_px - 1) * 0.5)
	var radius := float(size_px) * 0.42
	for y in range(size_px):
		for x in range(size_px):
			var p := Vector2(float(x), float(y))
			var dist := p.distance_to(center)
			if dist > radius:
				continue
			var t := clampf(dist / radius, 0.0, 1.0)
			var color := Color("#f6c453").lerp(Color("#b66a1c"), t)
			if dist > radius * 0.82:
				color = Color("#7a3f12")
			elif dist < radius * 0.38:
				color = color.lightened(0.24)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
