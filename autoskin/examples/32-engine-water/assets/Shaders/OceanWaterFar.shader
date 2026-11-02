// Far water beyond the domain: OceanWater without vertex waves. Fragments still read the engine waves of the water node; at that distance their filtered mips give
// the mean normal and the full slope variance, so the far water matches the roughness of the sea it continues.
shader_type spatial;
render_mode shading_model_water, diffuse_lambert_wrap, cull_disabled, world_vertex_coords;
#define OCEAN_FAR_MESH
#include "OceanWater.shaderinc"
