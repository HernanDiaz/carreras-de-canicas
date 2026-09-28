extends SceneTree
## Convierte los SVG de icon/ a los PNG que piden Android e iOS.
## Uso: godot --headless --path . -s res://tools/render_icons.gd
## (Antes: python tools/make_icon.py para regenerar los SVG.)

const OUTPUTS := [
	# [svg de origen, png de destino, tamaño]
	["icon/icon_full.svg", "icon/icon_1024.png", 1024],          # App Store (sin transparencias)
	["icon/icon_full.svg", "icon/android_main_192.png", 192],    # Android: icono clásico
	["icon/icon_background.svg", "icon/android_background_432.png", 432],
	["icon/icon_foreground.svg", "icon/android_foreground_432.png", 432],
	["icon/icon_monochrome.svg", "icon/android_monochrome_432.png", 432],
]


func _initialize() -> void:
	for entry in OUTPUTS:
		var svg := FileAccess.get_file_as_string("res://" + entry[0])
		var image := Image.new()
		var err := image.load_svg_from_string(svg, float(entry[2]) / 1024.0)
		if err != OK:
			push_error("No se pudo convertir " + entry[0])
			continue
		image.save_png("res://" + entry[1])
		print("%s → %s (%dx%d)" % [entry[0], entry[1], image.get_width(), image.get_height()])
	quit()
