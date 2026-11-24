class_name Ghost
extends MeshInstance3D
## Canica fantasma: repite tu mejor vuelta a un nivel para que puedas correr contra ella.
## También sirve de grabadora: Ghost.Recorder apunta la vuelta actual mientras juegas.

## Muestras por segundo (entre una y otra se interpola).
const RATE := 20.0
## Floats por muestra: posición (3), rotación (4) y visible (1, el gusano la esconde).
const STRIDE := 8

var _samples := PackedFloat32Array()


## Carga el fantasma guardado del nivel. Devuelve null si no hay ninguno.
static func load_for(level_index: int, mesh: Mesh) -> Ghost:
	return from_samples(GameState.load_ghost(level_index), mesh)


## Fantasma a partir de unas muestras (también lo usan las capturas de la tienda).
static func from_samples(samples: PackedFloat32Array, mesh: Mesh) -> Ghost:
	if samples.size() < STRIDE * 2:
		return null
	var ghost := Ghost.new()
	ghost._samples = samples
	ghost.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.55, 0.85, 1.0, 0.3)
	material.emission_enabled = true
	material.emission = Color(0.3, 0.7, 1.0)
	material.emission_energy_multiplier = 0.25
	material.rim_enabled = true
	material.rim = 1.0
	material.rim_tint = 0.0
	material.roughness = 0.1
	ghost.material_override = material
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.visible = false
	return ghost


## Coloca el fantasma donde estaba `seconds` después de la salida.
func seek(seconds: float) -> void:
	var count := _samples.size() / STRIDE
	var f := clampf(seconds * RATE, 0.0, count - 1.0)
	var i := mini(int(f), count - 2)
	var t := f - i
	var a := i * STRIDE
	var b := a + STRIDE
	position = Vector3(_samples[a], _samples[a + 1], _samples[a + 2]).lerp(
		Vector3(_samples[b], _samples[b + 1], _samples[b + 2]), t)
	quaternion = Quaternion(_samples[a + 3], _samples[a + 4], _samples[a + 5], _samples[a + 6]).normalized().slerp(
		Quaternion(_samples[b + 3], _samples[b + 4], _samples[b + 5], _samples[b + 6]).normalized(), t)
	visible = _samples[a + 7] > 0.5


class Recorder:
	var samples := PackedFloat32Array()

	## Apunta las muestras que faltan hasta `seconds` con la posición actual de la canica.
	func record(seconds: float, body: Node3D) -> void:
		var q := body.quaternion
		var pos := body.global_position
		while samples.size() / STRIDE <= int(seconds * RATE):
			samples.append_array([pos.x, pos.y, pos.z, q.x, q.y, q.z, q.w, 1.0 if body.visible else 0.0])
