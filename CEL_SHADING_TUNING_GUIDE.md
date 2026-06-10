# Cel-Shading Tuning Guide

## Quick Parameter Reference

### In-Shader Parameters (Inspector)
Edit these in `res://materials/wall_cel.tres` or `res://materials/ground_cel.tres` to adjust:

#### Lighting Parameters
| Parameter | Range | Default | Effect |
|-----------|-------|---------|--------|
| `shadow_transparency` | 0.0 - 1.0 | 0.35 | How opaque shadows are. 0=pitch black, 1=fully lit |
| `cel_bands` | 2.0 - 8.0 | 3.0 | Number of shading levels. 2=stark cartoon, 8=almost smooth |
| `ambient_multiplier` | 0.0 - 2.0 | 1.2 | Overall brightness of ambient fill light |

#### Material Parameters
| Parameter | Range | Default | Effect |
|-----------|-------|---------|--------|
| `albedo_color` | Any color | White | Tint color for the material |
| `roughness` | 0.0 - 1.0 | 0.5 | Surface roughness (affects light scatter) |
| `metallic` | 0.0 - 1.0 | 0.0 | Metallic appearance |

### Scene-Level Parameters

#### DirectionalLight3D Settings (in test_play_world.tscn)
| Property | Current | Purpose |
|----------|---------|---------|
| Position | (0, 40, 0) | Height above scene |
| Rotation | 0.9, 0, 0, 0, 0.436, 0.9, 0, -1, 0.436 | Direction of light |
| `light_color` | (1.0, 0.98, 0.95) | Color of direct light |
| `light_energy` | 1.5 | Brightness of direct light |
| `light_volumetric_fog_energy` | 0.5 | Fog interaction |
| `shadow_blur` | 0.5 | Shadow softness |

#### Environment Settings (in world_environment.tres)
| Property | Current | Purpose |
|----------|---------|---------|
| `ambient_light_color` | (0.6, 0.6, 0.6) | Color of fill light |
| `ambient_light_energy` | 1.0 | Brightness of fill light |
| `ambient_light_sky_contribution` | 0.4 | How much sky affects ambient light |
| `volumetric_fog_density` | 0.005 | Fog thickness (minimal) |
| `tonemap_exposure` | 1.0 | Overall brightness |

## Common Adjustments

### Make It More Stylized (Cartoon-like)
```
In materials:
- shadow_transparency = 0.5  (lighter shadows)
- cel_bands = 2  (stark divisions)
- ambient_multiplier = 1.5  (brighter overall)
```

### Make It More Realistic
```
In materials:
- shadow_transparency = 0.2  (darker shadows)
- cel_bands = 6-8  (smoother transitions)
- ambient_multiplier = 0.8  (dimmer overall)
```

### Make It Brighter/More Cheerful
```
In DirectionalLight3D:
- light_energy = 2.0-2.5  (stronger direct light)

In Environment:
- ambient_light_energy = 1.5  (brighter fill light)

In materials:
- ambient_multiplier = 1.5+
```

### Make It Darker/More Moody
```
In DirectionalLight3D:
- light_energy = 0.8-1.0

In Environment:
- ambient_light_energy = 0.6-0.8
- ambient_light_color = (0.4, 0.4, 0.4)

In materials:
- shadow_transparency = 0.2  (darker shadows)
- ambient_multiplier = 0.8-1.0
```

### Change Light Direction
Modify the DirectionalLight3D **Rotation** property:
- Currently: angled from front-above
- To make more overhead: decrease X rotation to ~0.5
- To make more from side: adjust X and Z rotations
- To shift direction: modify the transform directly

### Change Light Color (e.g., for different time of day)
In DirectionalLight3D, modify `light_color`:
- Warm (sunset): (1.0, 0.8, 0.5)
- Cool (morning): (0.8, 0.9, 1.0)
- Neutral (noon): (1.0, 1.0, 0.95)

### Change Ambient Light (Fill Light)
In world_environment.tres, modify `ambient_light_color`:
- Warm: (0.7, 0.6, 0.5)
- Cool: (0.5, 0.6, 0.7)
- Neutral: (0.6, 0.6, 0.6)

## Advanced Tweaking

### Per-Surface Customization
Each wall/ground instance can have different material parameters:
1. Select the wall/ground in the scene
2. In the Inspector, find the MeshInstance3D
3. Under "Material Override", you can override specific shader parameters per-instance

### Texture-Based Control
Add textures to control parameters per-pixel:
- Create a control texture
- Sample it in the fragment shader
- Multiply material parameters by the texture values

### Post-Processing Effects
Currently disabled for clean cel-shading, but can be re-enabled:
- In world_environment.tres
- Enable `ssao_enabled`, `ssr_enabled`, `glow_enabled` if desired
- Note: These may look less optimal with cel-shading

## Performance Considerations
The cel-shading system is very efficient:
- Custom light function: ~8 shader instructions per light
- Unshaded render mode: Skips Godot's default PBR
- No expensive post-processing enabled

Performance impact: Negligible compared to standard PBR rendering.

## Troubleshooting

### Scene looks too dark
→ Increase `ambient_light_energy` in environment
→ Increase `ambient_multiplier` in materials
→ Increase `light_energy` on DirectionalLight3D

### Shadows are too black
→ Increase `shadow_transparency` in materials (try 0.4-0.5)

### Lost all detail in shadows
→ Decrease `shadow_transparency` (too transparent)
→ Increase `ambient_light_energy` in environment

### Looks too flat/unrealistic
→ Increase `cel_bands` (6-8) for smoother transitions
→ Increase `roughness` on materials

### Looks too stylized
→ Decrease `cel_bands` (2-3) for more cartoon look
→ Adjust lighting balance between ambient and direct

## Material Inspector Access
To adjust materials in real-time during development:
1. Open test_play_world scene
2. Select any wall or ground (in scene tree)
3. In Inspector, find the MeshInstance3D's material slot
4. Adjust shader parameters live
5. Changes update in real-time in the viewport
