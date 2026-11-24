#pragma once

// Extras nativos de iOS para el juego (singleton "IosExtras"):
//  - Ventana de valoración de la App Store (SKStoreReviewController).
//  - Progreso en iCloud (almacén clave-valor, NSUbiquitousKeyValueStore).
//
// No se compila por separado: el workflow de iOS copia este archivo y el .mm al código del
// plugin GameCenterKit antes de compilarlo, y lo registra junto a él (dos GDExtension con
// godot-cpp enlazadas en el mismo binario chocarían entre sí).

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class IosExtras : public Object {
	GDCLASS(IosExtras, Object)

	void *observer = nullptr;

protected:
	static void _bind_methods();

public:
	IosExtras();
	~IosExtras();

	// Pide a iOS que muestre la ventana de valoración. iOS decide si la muestra
	// (como mucho 3 veces al año; en TestFlight nunca).
	void request_review();

	// iCloud: texto guardado con esa clave ("" si no hay) y guardarlo.
	String cloud_get(const String &key) const;
	void cloud_set(const String &key, const String &value);
	// Pide a iOS que sincronice ya con iCloud. false si iCloud no está disponible.
	bool cloud_sync();
};

} // namespace godot
