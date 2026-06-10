# 🎮 Cel-Shading System - Start Here

## What You Now Have

A **professional cel-shading system** with:
- ✨ **Hard shadow edges** for clear, comic book-style shadows
- 🎨 **Discrete light bands** for stylized lighting
- 🔧 **Full real-time adjustability** from the Inspector
- 🎬 **Distance-based light falloff** that keeps rooms well-lit
- 📱 **Ready to use** - no setup needed!

## The Problem This Solves

You said: *"I want clear cel shading instead of just no shadows"*

**Solution**: Hard-edged shadows with distinct light bands create that classic anime/comic book look where shadows are clearly visible with sharp boundaries.

## See It In Action (30 seconds)

1. **Open the scene**: `res://maps/test_play_world.tscn`
2. **Press Play** to see the new lighting
3. **Look at the walls** - notice the hard shadow edges and light bands!

## Tweak It Your Way (60 seconds)

1. **In Inspector**, select any mesh (walls, ground, blocks)
2. **Expand** "Material" → "Shader Material" → "Shader Parameters"
3. **Drag a slider** to adjust `cel_bands` or `shadow_darkness`
4. **See the change instantly** - no need to rebuild!

### Try These Quick Tweaks:

**Make shadows MORE dramatic:**
- Set `cel_bands` = 2
- Set `shadow_darkness` = 0.15

**Make shadows LIGHTER (less harsh):**
- Set `shadow_darkness` = 0.35
- Set `ambient_multiplier` = 1.0

**Try pure CARTOON STYLE:**
- Set `cel_bands` = 3
- Set `shadow_darkness` = 0.25
- Set `ambient_multiplier` = 0.8

## What Actually Changed

### Before
- Semi-transparent shadows that fade smoothly
- Less distinct visual style
- Soft, blurred shadow edges

### After
- **Hard-edged shadows** - clean boundary between light/dark
- **Discrete light levels** - distinct bands of color
- **Clear visual style** - unmistakably cel-shaded
- **Well-lit rooms** - ambient light keeps shadows visible

## The Shader Explained (Simple Version)

For each pixel, the shader asks:
1. **Is this pixel in light or shadow?** (uses hard cutoff)
2. **If in light**: Quantize to a discrete band (create banding effect)
3. **If in shadow**: Make it a darkened version of the texture
4. **Result**: Clear cel-shaded appearance!

## Key Parameters

| Slider | What It Does | Try This |
|--------|-------------|----------|
| `cel_bands` | How many distinct light levels (2-8) | Start at 3 |
| `shadow_darkness` | How dark are shadows (0.0-0.5) | Start at 0.25 |
| `shadow_threshold` | Where shadows appear (-0.3 to 0.3) | Usually 0 |
| `ambient_multiplier` | Overall brightness (0.0-2.0) | Start at 0.8 |

**Pro tip**: Start with `cel_bands` and `shadow_darkness` - those give the biggest visual impact!

## Three Different Styles (Copy-Paste)

### Style 1: Dark & Dramatic
```
cel_bands: 2
shadow_darkness: 0.15
ambient_multiplier: 0.7
```

### Style 2: Balanced & Clean (Default)
```
cel_bands: 3
shadow_darkness: 0.25
ambient_multiplier: 0.8
```

### Style 3: Bright & Smooth
```
cel_bands: 5
shadow_darkness: 0.35
ambient_multiplier: 1.0
```

## Files You Need to Know About

```
Shader:
  res://shaders/cel_shading.gdshader

Materials (adjust parameters here):
  res://materials/wall_cel.tres
  res://materials/ground_cel.tres
```

## Documentation

- **This file**: Quick start guide
- **CEL_SHADING_UPDATED.md**: Feature overview and how it works
- **TROUBLESHOOTING_CELSHADING.md**: Problem-solving guide
- **CEL_SHADING_QUICK_REFERENCE.md**: Parameter reference card

## Testing Checklist

Play the scene and verify:
- [ ] Can you see **clear shadow edges** on the walls?
- [ ] Do shadows have **distinct light bands** inside them?
- [ ] Are shadows **visible but not pitch black**?
- [ ] Is the **overall room brightness good**?
- [ ] Does it **look like cel-shading** to you?

If all ✓, you're good to go!

## Common First-Time Adjustments

**"Shadows look too dark"**
→ Increase `shadow_darkness` to 0.35

**"Not enough visual banding"**
→ Decrease `cel_bands` to 2

**"Scene looks too dim"**
→ Increase `ambient_multiplier` to 0.9-1.0

**"Shadows don't look sharp enough"**
→ That's correct! They should have soft edges on the surface but hard boundaries from light direction

## Next: Make It Your Own

Each material can have **different settings**:
- Create a copy of `wall_cel.tres` for special rooms
- Adjust shadows per-area to match your mood
- Experiment with extreme values to see what looks good!

---

## TL;DR (Super Quick Version)

1. Play the scene
2. Look at the walls - notice the hard shadow edges!
3. Open Inspector and adjust the sliders
4. That's it - you have professional cel-shading now!

**You're all set. Go make some cool cel-shaded levels!** 🎨✨
