# Tutorial System - Quick Start

## What You Have
✅ **TutorialTrigger.gd** - Detects when player enters Area3D zones  
✅ **ObjectiveMessage.gd** - Shows fade-in/out messages on screen  
✅ **tutorial_map.tscn** - Ready-to-use scene with 2 example triggers  

## How It Works
1. Player walks into an Area3D trigger zone
2. TutorialTrigger script detects the collision
3. Message displays on screen with fade animation
4. Message stays for the set duration, then fades out

## How to Add Your Own Messages

### Easiest Way (5 seconds):
1. Open **res://maps/tutorial_map.tscn**
2. Click on **TutorialTriggers** → **TutorialTrigger1** in the scene tree
3. In the right panel (Inspector), change:
   - **message**: "Your text here"
   - **duration**: 3 (seconds)
4. Done! That's it.

### To Make New Triggers:
1. Duplicate an existing TutorialTrigger (right-click → Duplicate Node)
2. Move it to where you want it in the viewport
3. Change the message and duration in the Inspector
4. That's it!

### To Change Trigger Size:
1. Select a TutorialTrigger
2. Expand **CollisionShape3D** child node
3. Select the **CollisionShape3D**
4. In Inspector, edit **Shape** → **Size** (larger = bigger detection zone)

## Example Messages You Can Use

```
"Welcome! Use WASD to move around."

"Great! Now try pressing SPACE to jump."

"You're doing great! Use the mouse to look around."

"Challenge: Try jumping over that wall!"

"You completed the tutorial section!"
```

## Current Setup
- **TutorialTrigger1**: Position (-48.4, 1.9, 5) - Welcome message
- **TutorialTrigger2**: Position (-48.4, 7.0, 36.7) - Jump tutorial

## Pro Tips
- Keep messages short (1-2 sentences)
- Duration of 3-4 seconds is usually best
- Position triggers just before new mechanics are needed
- Test your tutorial by walking through the areas
- Each trigger only shows once (by design)

## Files Modified/Created
- ✨ `res://Scripts/TutorialTrigger.gd` (new)
- ✨ `res://Scenes/ObjectMessageUI.tscn` (updated)
- ✨ `res://Scripts/ObjectiveMessage.gd` (updated)
- ✨ `res://maps/tutorial_map.tscn` (updated)

## Need to Reset a Trigger?
If you want a trigger to show again, use:
```gdscript
$TutorialTriggers/TutorialTrigger1.reset_trigger()
```

Enjoy your tutorial system! 🎮
