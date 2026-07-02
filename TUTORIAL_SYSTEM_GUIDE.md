# Tutorial System Guide

## Overview
This tutorial system uses Area3D triggers that detect when the player walks through them and display customizable messages on screen using the ObjectMessageUI.

## Components

### 1. **TutorialTrigger.gd** (res://Scripts/TutorialTrigger.gd)
The main script that handles tutorial trigger detection and message display.

**Exported Properties (Edit in Inspector):**
- `message` (String): The tutorial message to display when the player enters the trigger
- `duration` (Float): How long the message stays on screen (in seconds)

**Features:**
- Automatically finds the ObjectMessageUI in the scene
- Only triggers once per trigger zone
- Can be reset via `reset_trigger()` method

### 2. **ObjectiveMessage.gd** (res://Scripts/ObjectiveMessage.gd)
Handles the UI display and fade animations for messages.

**Methods:**
- `show_message(text: String, duration: float = 3.0)`: Displays a message with fade-in/out animation

## How to Add New Tutorial Triggers

### Method 1: In the Editor
1. Open `res://maps/tutorial_map.tscn` in the Godot Editor
2. Go to **TutorialTriggers** node
3. Right-click and select **Duplicate Node** on any existing TutorialTrigger
4. Move and scale the new Area3D to the desired location
5. In the Inspector, change the **message** and **duration** properties
6. The CollisionShape3D should automatically be set up

### Method 2: Via Script (if you need dynamic creation)
```gdscript
# Create a new tutorial trigger at a specific position
var trigger: Area3D = Area3D.new()
trigger.position = Vector3(0, 0, 10)
trigger.script = preload("res://Scripts/TutorialTrigger.gd")
trigger.message = "Your tutorial message here"
trigger.duration = 3.0

var collision_shape: CollisionShape3D = CollisionShape3D.new()
var box_shape: BoxShape3D = BoxShape3D.new()
box_shape.size = Vector3(10, 3, 10)
collision_shape.shape = box_shape
trigger.add_child(collision_shape)

$TutorialTriggers.add_child(trigger)
```

## Customization Options

### Change Message Text and Duration
1. Select any **TutorialTrigger** in the scene tree
2. In the Inspector panel on the right:
   - Edit the **message** field for custom text
   - Edit the **duration** field for how long it displays (in seconds)

### Change Trigger Zone Size
1. Select a **TutorialTrigger**
2. Expand its **CollisionShape3D** child
3. Select the **CollisionShape3D**
4. In the Inspector, find the **Shape** property
5. Expand it and change the **Size** (X, Y, Z dimensions)

### Visual Debugging
To see the trigger zones while editing:
1. Select a **TutorialTrigger** node
2. Use Gizmo tools (in the top toolbar) to move/resize the collision shape
3. The zone is invisible at runtime but shows when selected in the editor

## Important Notes

- **One-time Trigger**: Each trigger only activates once. If you need to reset it, call `reset_trigger()` on the trigger node
- **Player Group**: The triggers check if the body has the "player" group. Make sure your player is in the "player" group (it already is in this project)
- **Message UI**: The ObjectMessageUI is automatically found via:
  1. First, it looks in the scene at "Node3D/ObjectMessageUI"
  2. If not found, it searches for any node in the "message_ui" group
  3. Make sure ObjectMessageUI is in your scene

## Example Messages

Good tutorial messages are:
- **Short**: "Use WASD to move"
- **Clear**: "Press SPACE to jump"
- **Encouraging**: "Great job! Now try something new"
- **Actionable**: "Use the mouse to look around"

Avoid:
- **Too long**: Messages that take too long to read
- **Vague**: "Do something"
- **Technical jargon**: Unless teaching advanced mechanics

## Troubleshooting

### Messages not showing up
1. Check that ObjectMessageUI exists in the scene hierarchy
2. Verify the player has the "player" group assigned
3. Check the console for error messages
4. Make sure the CollisionShape3D is not set to "disabled"

### Triggers firing multiple times
1. This shouldn't happen - triggers are designed to fire only once
2. If it does, check if `has_triggered` is being reset somewhere
3. You can manually reset with: `$TutorialTriggers/TutorialTrigger1.reset_trigger()`

### Collision not detecting player
1. Make sure player's CharacterBody3D has a valid CollisionShape3D
2. Check collision layers/masks if you're using physics layers
3. Ensure the trigger Area3D's CollisionShape3D is enabled

## Advanced: Multiple Message Systems

You can have different message UIs by creating multiple CanvasLayer nodes with the ObjectiveMessage script attached, and updating TutorialTrigger to reference the correct one:

```gdscript
# In TutorialTrigger.gd - modify _ready() to reference a specific UI:
func _ready() -> void:
    message_ui = get_node("path/to/specific/ObjectMessageUI")
    body_entered.connect(_on_body_entered)
```
