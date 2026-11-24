@tool
extends EditorPlugin
## Al exportar para Android añade la biblioteca de valoraciones de Google Play
## (com.google.android.play:review). El juego la usa desde GDScript con JavaClassWrapper,
## así que no hace falta código Java propio. Necesita la compilación con Gradle.

var _export_plugin: AndroidExport


func _enter_tree() -> void:
	_export_plugin = AndroidExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "MarbleExtras"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["com.google.android.play:review:2.0.2"])
