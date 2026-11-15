# Custom 2D web export template for The Tunnel (Godot 4.5.1, single-thread).
# Audited against scenes/scripts: 2D physics, GL Compatibility, WebP textures,
# CJK via a subset of NotoSansTC instanced at wght 500, GPUParticles2D, canvas
# shaders, JavaScriptBridge, and basic GUI (Label/Panel/Button). No audio
# files, 3D, navigation, networking, or advanced text features are used.
# text_server_fb is used instead of text_server_adv to shrink the wasm;
# tools/subset-ui-font.py injects a zero-width U+200B glyph because Godot
# Labels append ZWSP and the fallback server would otherwise draw tofu.
#
# Headless "Engine compilation configuration" detection is not available,
# so this profile is hand-written. Pass it as Godot's custom.py in the
# engine source root, and also pass target=template_release on the CLI.

platform = "web"
threads = "no"
optimize = "size_extra"
lto = "full"  # also passed on the scons CLI; production=yes otherwise resets lto to auto (thin on web)
production = "yes"
debug_symbols = "no"
deprecated = "no"
javascript_eval = "yes"

disable_3d = "yes"
disable_advanced_gui = "yes"
disable_navigation_2d = "yes"
disable_navigation_3d = "yes"
disable_physics_3d = "yes"
disable_xr = "yes"

vulkan = "no"
use_volk = "no"
openxr = "no"
accesskit = "no"
graphite = "no"

# Keep minizip: safer for packed data paths. Disable unused modules.
module_text_server_adv_enabled = "no"
module_text_server_fb_enabled = "yes"
module_freetype_enabled = "yes"
module_gdscript_enabled = "yes"
module_webp_enabled = "yes"
module_godot_physics_2d_enabled = "yes"

module_astcenc_enabled = "no"
module_basis_universal_enabled = "no"
module_bcdec_enabled = "no"
module_betsy_enabled = "no"
module_bmp_enabled = "no"
module_camera_enabled = "no"
module_csg_enabled = "no"
module_cvtt_enabled = "no"
module_dds_enabled = "no"
module_enet_enabled = "no"
module_etcpak_enabled = "no"
module_fbx_enabled = "no"
module_glslang_enabled = "no"
module_gltf_enabled = "no"
module_godot_physics_3d_enabled = "no"
module_gridmap_enabled = "no"
module_hdr_enabled = "no"
module_interactive_music_enabled = "no"
module_jolt_physics_enabled = "no"
module_jpg_enabled = "no"
module_jsonrpc_enabled = "no"
module_ktx_enabled = "no"
module_lightmapper_rd_enabled = "no"
module_mbedtls_enabled = "no"
module_meshoptimizer_enabled = "no"
module_minimp3_enabled = "no"
module_mobile_vr_enabled = "no"
module_mono_enabled = "no"
module_msdfgen_enabled = "no"
module_multiplayer_enabled = "no"
module_navigation_2d_enabled = "no"
module_navigation_3d_enabled = "no"
module_noise_enabled = "no"
module_ogg_enabled = "no"
module_openxr_enabled = "no"
module_raycast_enabled = "no"
module_regex_enabled = "no"
module_svg_enabled = "no"
module_tga_enabled = "no"
module_theora_enabled = "no"
module_tinyexr_enabled = "no"
module_upnp_enabled = "no"
module_vhacd_enabled = "no"
module_vorbis_enabled = "no"
module_webrtc_enabled = "no"
module_websocket_enabled = "no"
module_webxr_enabled = "no"
module_xatlas_unwrap_enabled = "no"
module_zip_enabled = "no"
