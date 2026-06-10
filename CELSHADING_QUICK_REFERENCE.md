# 🎨 Cel-Shading Quick Reference Card

## Shader File
```
res://shaders/cel_shading.gdshader
```

## Material Files
```
res://materials/wall_cel.tres
res://materials/ground_cel.tres
```

## Parameters at a Glance

| Parameter | Range | Default | Quick Adjust |
|-----------|-------|---------|--------------|
| `cel_bands` | 2-8 | 3 | Want more/less banding? Adjust this |
| `shadow_darkness` | 0.0-0.5 | 0.25 | Shadows too dark? Increase to 0.35 |
| `shadow_threshold` | -0.3 to 0.3 | 0.0 | Want more shadows? Lower to -0.1 |
| `ambient_multiplier` | 0.0-2.0 | 0.8 | Scene too dark? Increase to 0.9-1.0 |

## One-Click Styles

### Dramatic
```
cel_bands: 2
shadow_darkness: 0.15
```

### Balanced (Default)
```
cel_bands: 3
shadow_darkness: 0.25
```

### Smooth
```
cel_bands: 5
shadow_darkness: 0.35
```

### Bright
```
ambient_multiplier: 1.1
shadow_darkness: 0.3
```

## How Shadow Works Now

```
Dark surface area:
  ╔════════════════════════════════════╗
  ║ Shadow color = texture * darkness  ║
  ║ (Hard edge when light < threshold) ║
  ╚════════════════════════════════════╝

Lit surface area:
  ╔════════════════════════════════════╗
  ║ Color = quantized light bands      ║
  ║ (Discrete steps, no blending)      ║
  ╚════════════════════════════════════╝
```

## Troubleshooting in 10 Seconds

| Problem | Fix |
|---------|-----|
| Too dark | ↑ `ambient_multiplier` to 0.9-1.0 |
| Too bright | ↓ `ambient_multiplier` to 0.6-0.7 |
| Not enough shadow | ↓ `shadow_darkness` to 0.15 |
| Too banded/blocky | ↑ `cel_bands` to 5-6 |
| Not stylized enough | ↓ `cel_bands` to 2 |
| Wrong shadow location | Adjust `shadow_threshold` |

## Testing Checklist

- [ ] Does it have clear shadow edges?
- [ ] Can you see distinct light bands?
- [ ] Are shadows visible but not too dark?
- [ ] Is the overall room brightness good?
- [ ] Does the style match your game?

## Material Inspector Path

1. Open Inspector
2. Select a mesh with the material
3. Material → Shader Material → Shader Parameters
4. Adjust any parameter
5. See changes in real-time!

## Pro Tips

💡 **Tip 1**: Lower `cel_bands` to 2 for maximum stylization
💡 **Tip 2**: Increase `ambient_multiplier` if shadows are too harsh
💡 **Tip 3**: Use `shadow_threshold` for creative shadow placement
💡 **Tip 4**: Each material can have different settings!
💡 **Tip 5**: Test with actual light sources in your scene

## Default All Parameters

Copy-paste these values to reset:
```
cel_bands = 3
shadow_darkness = 0.25
shadow_threshold = 0.0
light_falloff_distance = 150.0
ambient_multiplier = 0.8
```

## Key Difference: Before vs After

**Before**: Smooth fading shadows (semi-transparent)
**After**: Hard-edged shadows with discrete light bands ✨

This gives you that **classic comic book/anime look** you wanted!

---

**Need help?** Check CEL_SHADING_UPDATED.md or TROUBLESHOOTING_CELSHADING.md
