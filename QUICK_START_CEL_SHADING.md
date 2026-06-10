# Cel-Shading Lighting System - Quick Start

## What You Get

Your test_play_world now has:
- ✅ Bright cel-shaded lighting
- ✅ Light coming from above
- ✅ Distance-based light falloff
- ✅ Semi-transparent shadows (not pitch black)
- ✅ Stylized, non-realistic appearance

## No Action Required

The system is **ready to use** - just play the scene!

```
Press F5 or click the Run Scene button to see it in action.
```

## Quick Adjustments

### Make it Brighter
1. Open `test_play_world.tscn` (already open)
2. Select the `DirectionalLight3D` node in the tree
3. In the Inspector, increase `Light > Energy` (try 2.0 or higher)
4. Changes update in real-time!

### Make it More Cartoonish
1. Select any Wall in the scene tree
2. Click the MeshInstance3D child node
3. In Inspector, find "Material Override"
4. Expand it and adjust:
   - `cel_bands`: Change to 2 (stark) to 8 (smooth)
   - `shadow_transparency`: Change to 0.5+ (lighter shadows)
   - `ambient_multiplier`: Change to 1.5+ (brighter)

### Change the Shadow Darkness
1. Select a wall with cel-shading material
2. In Inspector, find `Material Override > Shadow Transparency`
3. Adjust the value:
   - 0.2 = Very dark shadows
   - 0.35 = Default (current)
   - 0.5+ = Very light shadows

### Change Light Direction
1. Select `DirectionalLight3D` in the scene tree
2. Use the 3D gizmo to rotate it or
3. In Inspector, adjust `Transform > Rotation`
4. The arrow direction shows where light comes from

## Full Customization

For detailed adjustments, see **CEL_SHADING_TUNING_GUIDE.md**

## Technical Details

If you're curious how it works: **CEL_SHADING_SETUP.md**

## Files Overview

```
res://
├── shaders/
│   └── cel_shading.gdshader          [Custom shader]
├── materials/
│   ├── wall_cel.tres                 [Wall material]
│   └── ground_cel.tres               [Ground material]
├── maps/
│   ├── test_play_world.tscn          [Main scene - lighting configured]
│   ├── wall.tscn                     [Wall model - uses cel material]
│   └── test_world_plate.tscn         [Ground model - uses cel material]
├── environments/
│   └── world_environment.tres        [Environment - optimized for cel-shading]
├── CEL_SHADING_SETUP.md              [Technical documentation]
├── CEL_SHADING_TUNING_GUIDE.md       [Detailed tuning reference]
├── LIGHTING_SYSTEM_SUMMARY.md        [Overview]
└── QUICK_START_CEL_SHADING.md        [This file]
```

## Common Tasks

### Play the scene
```
Press F5 or click Run Scene (►) button
```

### Adjust light brightness
```
Select DirectionalLight3D > Inspector > Light > Energy
```

### Make shadows less black
```
Select any wall > Inspector > Material Override > Shadow Transparency
Change to 0.4 or 0.5
```

### Change light color
```
Select DirectionalLight3D > Inspector > Light > Color
Change to warm (1.0, 0.8, 0.5) or cool (0.8, 0.9, 1.0)
```

### Make environment brighter
```
Double-click res://environments/world_environment.tres
In Inspector, change Ambient Light > Energy to 1.5
```

## Tips

1. **Real-Time Editing**: All parameters update live in the viewport while the scene is open
2. **Material Instances**: Each wall/floor can have different material settings
3. **Layered Lighting**: You can add more DirectionalLight3D or PointLight3D nodes - same shader works
4. **Performance**: This is very efficient - no expensive post-processing

## If Something Looks Wrong

| Problem | Solution |
|---------|----------|
| Too dark | Increase `light_energy` on DirectionalLight3D |
| Shadows too black | Increase `shadow_transparency` in materials |
| Too stylized | Increase `cel_bands` to 6-8 in materials |
| Too realistic | Decrease `cel_bands` to 2-3 in materials |
| Looks flat | Increase `roughness` in material |
| Washed out | Decrease `ambient_multiplier` in materials |

## Default Values Reference

```
Light:
  energy: 1.5
  color: (1.0, 0.98, 0.95) - warm white
  position: (0, 40, 0) - directly overhead

Material:
  cel_bands: 3.0 - three lighting levels
  shadow_transparency: 0.35 - 35% opaque shadow
  ambient_multiplier: 1.2 - 120% bright base

Environment:
  ambient_light_energy: 1.0
  ambient_light_color: (0.6, 0.6, 0.6)
```

---

**That's it!** Your cel-shaded lighting system is ready to go. 🎨✨

For more control, check the tuning guide. For technical details, see the setup documentation.
