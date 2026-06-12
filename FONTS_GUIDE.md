# 🎨 Font Configuration Guide

## How to Change Fonts in Your Game

### Quick Start
1. **Drop your font files** into `res://fonts/` folder (supports .ttf and .otf)
2. **Open the Main Menu scene** in the Godot Editor
3. **Select the MainMenu node** in the Scene tree
4. **In the Inspector**, look for the `Font Config` property
5. **Click "Make Unique"** if needed, then adjust the paths and sizes

### Font Configuration System

The game uses a centralized `FontConfig` resource that controls all fonts across the UI.

#### Available Font Properties:
- `title_font_path` - Font for "INERTIA" title (default: 72px)
- `title_font_size` - Title text size
- `subtitle_font_path` - Font for "A VELOCITY-BASED EXPERIENCE" (default: 16px)
- `subtitle_font_size` - Subtitle text size
- `button_font_path` - Font for PLAY/SETTINGS/QUIT buttons (default: 24px)
- `button_font_size` - Button text size
- `status_font_path` - Font for "Game Ready" status (default: 14px)
- `status_font_size` - Status text size
- `version_font_path` - Font for version info (default: 10px)
- `version_font_size` - Version text size

### Step-by-Step Font Replacement

#### Option 1: Using the Inspector (Easiest)
1. Open `res://Scenes/main_menu.tscn`
2. Select the "MainMenu" node in the Scene tree
3. Look at the Inspector on the right side
4. Find the "Font Config" field
5. Click the folder icon next to each font path
6. Navigate to your font file in `res://fonts/` and select it
7. Adjust the font size sliders as needed
8. Changes apply immediately!

#### Option 2: Direct File Editing
1. Copy your font files to `res://fonts/` folder
2. Open `res://Scripts/FontConfig.gd`
3. Edit the `@export` paths in the `_init()` function:
   ```gdscript
   @export var title_font_path: String = "res://fonts/YourFont.ttf"
   ```
4. Save and reload the scene

### Font File Organization

```
res://fonts/
├── BebasNeue-Regular.ttf  (included)
├── YourCustomFont1.ttf    (drop here)
├── YourCustomFont2.otf    (drop here)
└── AnotherFont.ttf        (drop here)
```

### Supported Font Formats
- `.ttf` - TrueType Font (most common)
- `.otf` - OpenType Font
- Both formats are fully supported by Godot 4

### Tips & Tricks

**Different fonts for different elements:**
- You can use different fonts for title, buttons, and status text
- For example: elegant font for title, geometric font for buttons

**Font sizing:**
- Title: 60-80px looks good
- Subtitle: 14-18px works well
- Buttons: 20-28px is readable
- Status/Version: 10-14px for smaller text

**Performance:**
- Each unique font file is loaded once and cached
- Using the same font for multiple elements is efficient

### Troubleshooting

**Font not showing?**
- Check the file path is correct: `res://fonts/FontName.ttf`
- Ensure the font file is actually in the `res://fonts/` folder
- Look at the Output console for error messages
- Try using a different font file to test

**Text looks blurry?**
- Increase the font size
- Check if you're using a very small size for large text

**Font won't load?**
- Make sure the file extension is lowercase (.ttf not .TTF)
- Try moving the font to the fonts folder and refreshing (F5)

### Reverting to Default
If you want to reset all fonts to the original:
1. Edit `res://Scripts/FontConfig.gd`
2. Change all paths back to: `"res://fonts/BebasNeue-Regular.ttf"`
3. Reset sizes to defaults (title: 72, subtitle: 16, buttons: 24, status: 14, version: 10)
