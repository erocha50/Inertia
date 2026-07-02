# How to Customize the Tutorial UI Colors & Styling

## Easy Color Changes

### Option 1: Edit in the Inspector (Easiest)
1. Open `res://Scenes/ObjectMessageUI.tscn`
2. Select the **Panel** node
3. In the right panel (Inspector), look for **Theme Overrides** → **Styles**
4. Click on the **panel** style (PanelStyle_6dbe8)
5. Expand it and modify:
   - **bg_color**: Background color
   - **border_color**: Border color
   - **border_width_left/top/right/bottom**: Border thickness
   - **corner_radius_***: Roundness of corners

### Option 2: Edit the .tscn File Directly
Open `res://Scenes/ObjectMessageUI.tscn` and find the StyleBoxFlat section:

```gdscript
[sub_resource type="StyleBoxFlat" id="PanelStyle_6dbe8"]
bg_color = Color(0, 0, 0, 0.6)              # <-- Background
border_width_left = 3
border_width_top = 3
border_width_right = 3
border_width_bottom = 3
border_color = Color(0.2, 0.6, 1.0, 0.8)   # <-- Border
corner_radius_top_left = 8
corner_radius_top_right = 8
corner_radius_bottom_right = 8
corner_radius_bottom_left = 8
```

## Color Formats

All colors use `Color(R, G, B, A)` where:
- **R, G, B** = Red, Green, Blue (0.0 to 1.0)
- **A** = Alpha / Transparency (0.0 = invisible, 1.0 = opaque)

## Popular Color Combinations

### 🔵 Blue Theme (Current)
```gdscript
bg_color = Color(0, 0, 0, 0.6)              # Dark semi-transparent
border_color = Color(0.2, 0.6, 1.0, 0.8)    # Bright blue
```

### 🟢 Green Theme (Minimalist)
```gdscript
bg_color = Color(0, 0, 0, 0.5)              # Dark semi-transparent
border_color = Color(0.2, 1.0, 0.2, 0.8)    # Bright green
```

### 🟠 Orange/Warm Theme
```gdscript
bg_color = Color(0, 0, 0, 0.6)              # Dark semi-transparent
border_color = Color(1.0, 0.6, 0.2, 0.8)    # Warm orange
```

### 🟣 Purple Theme (Magical)
```gdscript
bg_color = Color(0, 0, 0, 0.6)              # Dark semi-transparent
border_color = Color(0.8, 0.2, 1.0, 0.8)    # Vibrant purple
```

### ⚪ Clean White Theme
```gdscript
bg_color = Color(0.1, 0.1, 0.1, 0.7)        # Dark gray
border_color = Color(1.0, 1.0, 1.0, 0.9)    # White
```

### 🔴 Red Warning Theme
```gdscript
bg_color = Color(0, 0, 0, 0.6)              # Dark semi-transparent
border_color = Color(1.0, 0.2, 0.2, 0.8)    # Bright red
```

## Text Color Changes

Select the **MessageLabel** node and modify:

```gdscript
theme_override_colors/font_color = Color(1, 1, 1, 1)           # Main text color
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)   # Outline color
theme_override_constants/outline_size = 2                       # Outline thickness
```

### Text Color Examples

**White on Dark** (Current - High Contrast)
```gdscript
theme_override_colors/font_color = Color(1, 1, 1, 1)           # White
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)   # Black outline
```

**Yellow on Dark** (Warm)
```gdscript
theme_override_colors/font_color = Color(1, 1, 0, 1)           # Yellow
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)   # Black outline
```

**Cyan on Dark** (Cool)
```gdscript
theme_override_colors/font_color = Color(0, 1, 1, 1)           # Cyan
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)   # Black outline
```

**Light Green on Dark** (Natural)
```gdscript
theme_override_colors/font_color = Color(0.7, 1, 0.7, 1)       # Light green
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)   # Black outline
```

## Size Changes

Select the **Panel** node and modify:

```gdscript
custom_minimum_size = Vector2(600, 120)    # Width x Height
```

### Size Examples

**Small Box** (Mobile-friendly)
```gdscript
custom_minimum_size = Vector2(400, 80)
```

**Large Box** (More prominent)
```gdscript
custom_minimum_size = Vector2(700, 150)
```

**Wide Box** (For long messages)
```gdscript
custom_minimum_size = Vector2(800, 100)
```

## Border Changes

Modify border properties in the StyleBoxFlat:

```gdscript
border_width_left = 3      # Left edge thickness
border_width_top = 3       # Top edge thickness
border_width_right = 3     # Right edge thickness
border_width_bottom = 3    # Bottom edge thickness
```

### Border Examples

**Thick Border** (Bold)
```gdscript
border_width_left = 5
border_width_top = 5
border_width_right = 5
border_width_bottom = 5
```

**Thin Border** (Subtle)
```gdscript
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
```

**No Border** (Minimal)
```gdscript
border_width_left = 0
border_width_top = 0
border_width_right = 0
border_width_bottom = 0
```

## Transparency Changes

Adjust the `A` (alpha) value in colors:

```gdscript
bg_color = Color(0, 0, 0, 0.6)  # 0.6 = 60% opaque
```

### Transparency Examples

**More Transparent** (Lighter)
```gdscript
bg_color = Color(0, 0, 0, 0.3)  # 30% opaque
```

**Less Transparent** (Darker)
```gdscript
bg_color = Color(0, 0, 0, 0.8)  # 80% opaque
```

**Fully Opaque** (Solid)
```gdscript
bg_color = Color(0, 0, 0, 1.0)  # 100% opaque
```

## Font Size Changes

Select **MessageLabel** and modify:

```gdscript
theme_override_font_sizes/font_size = 28    # Size in pixels
```

### Font Size Examples

**Small** (Mobile)
```gdscript
theme_override_font_sizes/font_size = 20
```

**Medium** (Default)
```gdscript
theme_override_font_sizes/font_size = 28
```

**Large** (Prominent)
```gdscript
theme_override_font_sizes/font_size = 36
```

**Extra Large** (Very prominent)
```gdscript
theme_override_font_sizes/font_size = 48
```

## Complete Customization Example

Here's how to change to a red warning theme with yellow text:

1. Open `res://Scenes/ObjectMessageUI.tscn`
2. Select **Panel**
3. Expand **Theme Overrides** → **Styles** → **panel**
4. Modify:
   - **bg_color**: Change to `Color(0, 0, 0, 0.7)`
   - **border_color**: Change to `Color(1.0, 0.2, 0.2, 0.9)`
   - **border_width_left/top/right/bottom**: Change all to `4`

5. Select **MessageLabel**
6. Modify:
   - **font_color**: Change to `Color(1, 1, 0, 1)`  (Yellow)
   - **font_size**: Change to `32`

Done! Your tutorial messages now have a red warning style with yellow text.

## Quick Reference: RGB to Hex

If you're used to hex colors:

```
Pure Red:    Color(1.0, 0, 0, 1)       = #FF0000
Pure Green:  Color(0, 1.0, 0, 1)       = #00FF00
Pure Blue:   Color(0, 0, 1.0, 1)       = #0000FF
White:       Color(1.0, 1.0, 1.0, 1)   = #FFFFFF
Black:       Color(0, 0, 0, 1)         = #000000
Yellow:      Color(1.0, 1.0, 0, 1)     = #FFFF00
Cyan:        Color(0, 1.0, 1.0, 1)     = #00FFFF
```

Enjoy customizing your tutorial UI! 🎨
