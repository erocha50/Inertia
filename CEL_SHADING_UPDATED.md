# Clear Cel-Shading System - Updated

## What's New ✨

The cel-shading system has been completely updated to create **clear, distinct shadows** with hard edges instead of semi-transparent fading. This creates the classic **comic book/anime look** you wanted.

## Key Features

### 🎨 Hard Shadow Edges
- Shadows have a **clear cutoff** between lit and shadow areas
- No blurry transitions - sharp, defined boundaries
- Uses `step()` function for pixel-perfect shadow determination

### 📊 Discrete Light Bands
- Light areas are quantized into distinct color bands (2-8 bands)
- Each band is clearly visible and distinct from the others
- Creates that classic cel-shaded, stylized appearance

### 🕯️ Configurable Shadow Darkness
- `shadow_darkness`: How dark the shadows are (0.0 = black, 0.5 = lighter shadows)
  - Default: 0.25 (darker but not pitch black)
  - Lower values = darker shadows, higher values = lighter shadows

### ⚙️ Shadow Threshold Control
- `shadow_threshold`: Determines where shadows begin relative to light direction
  - Default: 0.0 (shadows appear where light is perpendicular)
  - Negative values: Shadows appear sooner (larger shadow areas)
  - Positive values: More surfaces lit before shadow appears

## Material Parameters

Both wall and ground materials have these adjustable parameters:

| Parameter | Range | Default | Effect |
|-----------|-------|---------|--------|
| `cel_bands` | 2-8 | 3 | Number of distinct light bands |
| `shadow_darkness` | 0.0-0.5 | 0.25 | Shadow darkness intensity |
| `shadow_threshold` | -0.3 to 0.3 | 0.0 | Where shadows appear |
| `ambient_multiplier` | 0.0-2.0 | 0.8 | Overall ambient brightness |

## How to Adjust

### In the Godot Inspector:

1. Open `res://materials/wall_cel.tres` or `res://materials/ground_cel.tres`
2. Look for "Shader Parameters" section
3. Adjust any of the parameters in real-time!

### Popular Presets:

**Dark & Dramatic:**
- `cel_bands`: 2
- `shadow_darkness`: 0.1
- `ambient_multiplier`: 0.6

**Bright & Cartoon:**
- `cel_bands`: 5
- `shadow_darkness`: 0.35
- `ambient_multiplier`: 1.0

**Subtle Cell Shading:**
- `cel_bands`: 4
- `shadow_darkness`: 0.4
- `ambient_multiplier`: 0.9

## Light Setup

### DirectionalLight3D (from above)
- Direction: Pointing down and slightly angled
- Energy: 1.5 (bright for cel-shading style)
- Color: Warm white (1.0, 0.98, 0.95)

This creates clear shadows that are visible but not too dark, giving the room good lighting with the cel-shaded appearance.

## Technical Details

### How It Works

1. **Fragment Shader** (`fragment()`):
   - Samples texture and applies ambient light
   - Creates the base color for the material

2. **Light Shader** (`light()`):
   - Calculates diffuse lighting from each light source
   - Uses `step()` function to create hard shadow edges
   - Quantizes lit areas into discrete bands using `floor()`
   - Applies shadow color to unlit areas

### Files Involved

- **Shader**: `res://shaders/cel_shading.gdshader`
- **Materials**: 
  - `res://materials/wall_cel.tres`
  - `res://materials/ground_cel.tres`

## Why Hard Shadows Work Better

The hard shadow edges create several advantages for cel-shading:

✅ **More Readable**: Clear distinction between lit/shadow areas
✅ **More Stylized**: Classic cartoon/comic book look
✅ **Better Performance**: No expensive smoothstep calculations
✅ **More Control**: Fine-tune shadow threshold per material

## Tips for Best Results

1. **Adjust ambient_multiplier** to control how bright shadows are
2. **Use cel_bands 2-4** for dramatic effect, 5-8 for subtle shading
3. **Fine-tune shadow_threshold** if you want shadows on different parts of surfaces
4. **Adjust shadow_darkness** based on your art style and mood

---

**All changes are in real-time!** Select a material in the Inspector and tweak the shader parameters to see results immediately. 🎨
