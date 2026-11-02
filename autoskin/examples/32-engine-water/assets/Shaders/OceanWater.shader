// Ocean water on engine waves. The FFTWaterSurface or GerstnerWaterSurface on the water node owns the waves: the
// same waves displace this mesh and answer the CPU queries behind buoyancy, swimming and camera immersion, so the
// material writes neither occlude_camera() nor waterline(). Refraction, absorption and scattering, reflections and
// the underwater effect come from the renderer; the material adds surface detail on top of the waves:
//   normal    - per-pixel wave normal tilted by two layers of the engine detail normal map
//   roughness - widened by the slope variance that mip filtering removes, from the waves and the detail map
//   foam      - whitecaps and shore foam: crest compression, its memory and the water thickness set a coverage that
//               thresholds the foam pattern stored in the detail map, combining current breaking and foam memory
// Foam uses the engine's wrapped diffuse response and receives the scene lights, atmosphere attenuation and shadows.
// A material that calls water_wave_*() declares at most 2 samplers: the engine binds the FFT texture to the third.
shader_type spatial;
render_mode shading_model_water, diffuse_lambert_wrap, cull_disabled, world_vertex_coords;
#include "OceanWater.shaderinc"
