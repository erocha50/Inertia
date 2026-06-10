# Cel-Shading Lighting System for test_play_world

## Overview
The test_play_world scene now features a bright cel-shaded lighting system with:
- **Non-realistic, stylized appearance** using cel-shading with bands
- **Light from above** via DirectionalLight3D positioned overhead
- **Distance-based light falloff** - light intensity decreases with distance
- **Semi-transparent shadows** - shadows aren't pitch black, allowing visibility in dark areas
- **Bright ambient fill light** - the room is well-lit even in shadow areas

## Components

### 1. Custom Cel-Shading Shader (`res://shaders/cel_shading.gdshader`)
The shader implements:
- **Cel-banding**: Diffuse lighting is quantized into discrete bands (default 3 levels)
  - This creates a stylized, cartoon-like appearance
  - Controlled by `cel_bands` uniform (2-8 bands)

- **Semi-transparent shadows**: 
  - Shadows aren't completely black (default 35% opacity)
  - Allows visibility in shadowed areas
  - Controlled by `shadow_transparency` uniform (0-1)

- **Ambient fill light**:
  - Base ambient light fills the scene
  - Default multiplier: 1.2x (120% brightness)
  - Controlled by `ambient_multiplier` uniform

- **Distance attenuation**:
  - Light naturally falls off with distance using the built-in ATTENUATION
  - Works with the light source's configured falloff

### 2. Shader Materials
Two materials use this shader:

#### `res://materials/wall_cel.tres`
- Used on all walls
- Applies wall texture with cel-shading
- Parameters can be adjusted per-material in the inspector

#### `res://materials/ground_cel.tres`
- Used on the ground plate
- Applies ground texture with cel-shading
- Parameters can be adjusted per-material in the inspector

**Adjustable Parameters:**
- `shadow_transparency`: How opaque shadows are (0 = black, 1 = fully lit)
- `cel_bands`: Number of shading bands (2 = stark, 8 = smooth)
- `ambient_multiplier`: Overall brightness of ambient light (0-2)
- `albedo_color`: Tint color for the material
- `roughness`: Surface roughness (affects specular)
- `metallic`: Metallic appearance (0-1)

### 3. DirectionalLight3D Settings
- **Position**: Above the scene at (0, 40, 0)
- **Rotation**: Coming from above-front angle (roughly 45° from above)
- **Light Color**: Warm white (1.0, 0.98, 0.95)
- **Light Energy**: 1.5 (bright for cel-shading)
- **Shadow**: Enabled with blur 0.5 for soft shadows
- **Volumetric Fog**: Reduced effect (0.5 energy)

### 4. Environment Settings (`res://environments/world_environment.tres`)
- **Ambient Light Color**: Light gray (0.6, 0.6, 0.6)
- **Ambient Light Energy**: 1.0 (bright fill light)
- **Ambient Light Sky Contribution**: 0.4 (balanced)
- **Volumetric Fog**: Minimal (0.005 density) - prevents overcast look
- **Post-processing**: 
  - Screen-space reflections: Disabled (not suitable for cel-shading)
  - SSAO: Disabled (not suitable for cel-shading)
  - SSILDisabled (not suitable for cel-shading)
  - Glow: Disabled
  - Tone Mapping: Linear (1.0 exposure)

## How It Works

1. **Fragment Stage**: 
   - Ambient light is calculated as base illumination
   - Texture is sampled and multiplied by ambient light
   - Result: Base lit appearance

2. **Light Function** (called per light):
   - Normal-to-light angle is calculated
   - Diffuse factor is quantized into cel bands (e.g., 0, 0.33, 0.66, 1.0 for 3 bands)
   - Shadow calculation creates smooth transition (30% opacity in shadows)
   - Light contribution is calculated: `LIGHT_COLOR * cel_diffuse * shadow_color * ATTENUATION`
   - Result is added to DIFFUSE_LIGHT

3. **Final Result**: 
   - Bright, well-lit scene
   - Stylized banding effect on lit surfaces
   - Visible detail in shadows
   - Natural distance-based light falloff

## Adjusting the Look

### For More Stylized (Cartoonish) Look:
- Decrease `cel_bands` to 2-3
- Increase `shadow_transparency` to 0.5+ (lighter shadows)
- Increase `ambient_multiplier` to 1.5+

### For More Realistic Look:
- Increase `cel_bands` to 6-8
- Decrease `shadow_transparency` to 0.2-0.3 (darker shadows)
- Decrease `ambient_multiplier` to 0.8-1.0

### For Different Mood:
- Adjust `light_color` on DirectionalLight3D
- Adjust `ambient_light_color` in environment
- Adjust `light_energy` on DirectionalLight3D

## Performance
The cel-shading shader is very efficient:
- Uses `unshaded` render mode (skips Godot's default lighting)
- Custom light function is simple math (no complex calculations)
- No expensive effects (SSAO, SSR, volumetric fog minimized)
- Suitable for all platforms

## Files Modified/Created
- Created: `res://shaders/cel_shading.gdshader`
- Created: `res://materials/wall_cel.tres`
- Created: `res://materials/ground_cel.tres`
- Modified: `res://maps/wall.tscn`
- Modified: `res://maps/test_world_plate.tscn`
- Modified: `res://environments/world_environment.tres`
- Modified: `res://maps/test_play_world.tscn`
