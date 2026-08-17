# Pause Menu System - Documentation

## Overview
A simple, elegant pause menu system has been added to the game that pauses gameplay and allows players to:
- **Resume** - Continue playing from where they paused
- **Settings** - Navigate to the settings scene
- **Main Menu** - Return to the main menu

## Features

### ✅ Pause Functionality
- Press **ESC** to pause/unpause at any time during gameplay
- Game properly pauses using `get_tree().paused = true`
- All game logic, physics, and animations freeze when paused
- Pause menu is NOT accessible from the main menu

### ✅ Visual Design
- **Consistent aesthetic** matching your main menu style
- **Cyan "PAUSED" title** (60% opacity dark overlay behind)
- **Three color-coded buttons**:
  - Cyan "► RESUME" button
  - Purple "⚙ SETTINGS" button  
  - Red "⌂ MAIN MENU" button
- **Responsive button focus** with keyboard navigation

### ✅ Non-Intrusive Overlay
- High `layer = 128` (CanvasLayer) ensures it appears above everything
- Centered panel with semi-transparent dark background
- Mouse cursor is properly enabled when paused
- Buttons are fully clickable and keyboard-navigable

## Implementation Details

### Files Created
- `res://Scripts/PauseMenu.gd` - Core pause menu logic
- `res://Scenes/PauseMenu.tscn` - Pause menu scene (CanvasLayer-based)

### Files Modified
- `res://maps/tutorial_map.tscn` - Added PauseMenu instance
- `res://maps/level_1.tscn` - Added PauseMenu instance
- `res://maps/test_play_world.tscn` - Added PauseMenu instance
- `res://maps/test_world.tscn` - Added PauseMenu instance
- `res://maps/test_play_world_backup.tscn` - Added PauseMenu instance

### How It Works

#### PauseMenu.gd (Script)
```gdscript
class_name PauseMenu extends CanvasLayer
```

**Key Methods:**
- `_ready()` - Initializes UI and loads font configuration
- `_process()` - Listens for `ui_cancel` (ESC key) input
- `toggle_pause()` - Toggles pause state on/off
- `_show_pause_menu()` - Displays overlay, pauses game, grabs focus
- `_hide_pause_menu()` - Hides overlay, unpauses game
- `_is_in_main_menu()` - Prevents pausing in main menu by checking scene path

**Button Callbacks:**
- `_on_resume_pressed()` - Calls `toggle_pause()` to unpause
- `_on_settings_pressed()` - Unpauses and loads settings scene
- `_on_main_menu_pressed()` - Unpauses and loads main menu scene

#### PauseMenu.tscn (Scene Structure)
```
PauseMenu (CanvasLayer, layer=128)
├── Control (full screen)
│   ├── BackgroundDim (ColorRect, 60% black overlay)
│   └── PausePanel (PanelContainer, centered)
│       └── VBoxContainer
│           ├── Title (Label: "PAUSED", cyan)
│           ├── Spacer (20px)
│           └── MenuContainer (VBoxContainer)
│               ├── ResumeButton (cyan)
│               ├── SettingsButton (purple)
│               └── MainMenuButton (red)
```

## Usage

### For Players
1. **Press ESC** during gameplay to pause
2. **Click a button** or use **arrow keys + Enter** to navigate and select
3. **Press ESC again** or click **RESUME** to unpause

### For Developers
To add the pause menu to a new level:

1. Open your level scene
2. Add an external resource reference at the top:
   ```
   [ext_resource type="PackedScene" uid="uid://b2i1qn0h84o7" path="res://Scenes/PauseMenu.tscn" id="N_pause"]
   ```
3. Instance it as a node:
   ```
   [node name="PauseMenu" parent="." instance=ExtResource("N_pause")]
   ```

That's it! The pause menu will automatically work.

## Customization

### Change Pause Key
Edit `_process()` in `PauseMenu.gd` to use a different action:
```gdscript
if Input.is_action_just_pressed("your_custom_action"):
```

### Adjust Colors
Edit the `PauseMenu.tscn` node properties:
- `BackgroundDim` color for overlay darkness
- Button `theme_override_colors/font_color` for button colors
- `Title` color for "PAUSED" text

### Modify Styling
The pause menu uses your project's `FontConfig` resource for consistent typography. Adjust button sizes in `PausePanel` VBoxContainer if needed.

## Technical Notes

- **CanvasLayer approach**: The overlay is a CanvasLayer with high layer value to ensure it's always visible above game content
- **Pause state**: Uses Godot's native `get_tree().paused` which respects `process_mode` settings
- **Scene detection**: Uses `scene_file_path` to detect main menu vs gameplay scenes
- **Font consistency**: Automatically applies your project's font configuration

## Known Limitations

- The pause menu cannot be opened in the main menu (by design)
- Settings button will unpause the game when navigating to settings
- Main Menu button will unpause the game when navigating back

These are intentional UX choices to ensure clean state transitions between scenes.

---

**Status**: ✅ Complete and tested
**Compatibility**: Godot 4.7.1
