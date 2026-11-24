"""Añade IosExtras (ios_extras.h/.mm) al código del plugin GameCenterKit antes de compilarlo.

Lo usa el workflow de iOS desde la carpeta del plugin (~/gck), después de copiar ahí los dos
archivos en src/. Registra el singleton "IosExtras" junto a "GameCenterKit" y hace que su
plugin de exportación enlace también StoreKit (ventana de valoración).
"""


def patch(path, replacements):
    with open(path) as f:
        text = f.read()
    for old, new in replacements:
        if old not in text:
            raise SystemExit("No encuentro en %s: %s" % (path, old))
        text = text.replace(old, new, 1)
    with open(path, "w") as f:
        f.write(text)


patch("src/register_types.cpp", [
    ('#include "game_center_kit.h"',
     '#include "game_center_kit.h"\n#include "ios_extras.h"'),
    ("static GameCenterKit *gamecenter_singleton = nullptr;",
     "static GameCenterKit *gamecenter_singleton = nullptr;\n"
     "static IosExtras *extras_singleton = nullptr;"),
    ('Engine::get_singleton()->register_singleton("GameCenterKit", gamecenter_singleton);',
     'Engine::get_singleton()->register_singleton("GameCenterKit", gamecenter_singleton);\n'
     "\tGDREGISTER_CLASS(IosExtras);\n"
     "\textras_singleton = memnew(IosExtras);\n"
     '\tEngine::get_singleton()->register_singleton("IosExtras", extras_singleton);'),
    ('Engine::get_singleton()->unregister_singleton("GameCenterKit");',
     'Engine::get_singleton()->unregister_singleton("IosExtras");\n'
     "\tmemdelete(extras_singleton);\n"
     "\textras_singleton = nullptr;\n"
     '\tEngine::get_singleton()->unregister_singleton("GameCenterKit");'),
])

patch("example/addons/gamecenter/plugin.gd", [
    ('add_apple_embedded_platform_framework("GameKit.framework")',
     'add_apple_embedded_platform_framework("GameKit.framework")\n'
     '\t\t\tadd_apple_embedded_platform_framework("StoreKit.framework")'),
])

print("GameCenterKit + IosExtras listo")
