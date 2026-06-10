# Cel-Shading Troubleshooting Guide

## Problem: Shadows are too dark/too light

**Solution**: Adjust `shadow_darkness` parameter
- Too dark? Increase the value (0.3 - 0.4)
- Too light? Decrease the value (0.1 - 0.2)

## Problem: Not enough contrast between lit/shadow areas

**Solution**: Check your `cel_bands` setting
- Increase `cel_bands` to 4-5 for more gradual transitions
- Decrease to 2-3 for more dramatic bands

## Problem: Entire scene is too dark

**Solution**: Adjust ambient lighting
- Increase `ambient_multiplier` (try 1.0 - 1.2)
- This brightens the base color before light is applied

## Problem: Shadows appear in the wrong places

**Solution**: Use `shadow_threshold` parameter
- Negative values (-0.1 to -0.3): More surface in shadow
- Positive values (0.1 to 0.3): More surface is lit
- Default (0.0): Shadows where light is perpendicular

## Problem: Material looks too realistic/not stylized enough

**Solution**: Try these settings for more cartoon look:
```
cel_bands: 2 or 3
shadow_darkness: 0.2
ambient_multiplier: 0.8-1.0
shadow_threshold: 0.0
```

## Problem: I don't see any change when I adjust parameters

**Solution**:
1. Make sure you're editing the material resource, not a different material
2. Check that the material is actually assigned to your mesh in the scene
3. Try play the scene to see live updates

## Quick Parameter Reset

If you mess up the parameters, here are the defaults:

```
cel_bands: 3
shadow_darkness: 0.25
shadow_threshold: 0.0
light_falloff_distance: 150.0
ambient_multiplier: 0.8
```

## Shader Parameters Explained

| Parameter | What It Does |
|-----------|-------------|
| `cel_bands` | More bands = smoother gradation, fewer bands = harder steps |
| `shadow_darkness` | How much color remains in shadows (0 = black, 0.5 = very bright) |
| `shadow_threshold` | Where the shadow line appears relative to normal direction |
| `light_falloff_distance` | How far light spreads (kept for API, uses ATTENUATION in-engine) |
| `ambient_multiplier` | Base brightness of unlit surfaces |

## Advanced: Custom Look

### Manga/Comic Style
```
cel_bands: 2
shadow_darkness: 0.15
ambient_multiplier: 1.0
shadow_threshold: 0.05
```

### Disney/Pixar Style
```
cel_bands: 5
shadow_darkness: 0.35
ambient_multiplier: 1.1
shadow_threshold: -0.05
```

### Dark Fantasy Style
```
cel_bands: 3
shadow_darkness: 0.1
ambient_multiplier: 0.6
shadow_threshold: 0.1
```

## Material Files

- **Wall material**: `res://materials/wall_cel.tres`
- **Ground material**: `res://materials/ground_cel.tres`
- **Shader file**: `res://shaders/cel_shading.gdshader`

Edit the `.tres` files in the Inspector to adjust parameters in real-time!
