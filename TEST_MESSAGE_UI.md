# Testing the Message UI

## Quick Test Instructions

1. **Open the Tutorial Map**
   - File → Open Scene → `res://maps/tutorial_map.tscn`

2. **Run the Game**
   - Press `F5` or click the Play button

3. **Walk Into the First Trigger**
   - Move forward with WASD or arrow keys
   - You should see a blue-bordered box appear in the center of the screen
   - The text says: "Welcome to the tutorial! Use WASD to move around."

4. **Watch the Animation**
   - The message fades in smoothly (0.4 seconds)
   - Stays visible for 3 seconds
   - Fades out smoothly (0.5 seconds)

## What You Should See

```
In the center of your screen, you'll see:

    ╔════════════════════════════════════════╗
    ║  Welcome to the tutorial!              ║
    ║  Use WASD to move around.              ║
    ╚════════════════════════════════════════╝

- Blue border (3px)
- Dark semi-transparent background
- White text (28px) with black outline
- Smooth fade in and out
```

## If You Don't See the Text

**The text should be visible now!** The scene has been fixed:

✅ Text is white (Color 1, 1, 1, 1)
✅ Font size is 28px
✅ Text says "Tutorial Message" by default
✅ Black outline (2px) for readability
✅ Centered horizontally and vertically
✅ Background is dark with blue border

## Scene Structure

The ObjectMessageUI scene now has:

```
ObjectMessageUI (CanvasLayer)
└── Panel (600x120, centered, styled)
    └── MarginContainer (20px padding)
        └── VBoxContainer (center alignment)
            └── MessageLabel (28px white text)
```

## Script Update

The ObjectiveMessage.gd script has been updated to:
- Reference the correct label path: `$Panel/MarginContainer/VBoxContainer/MessageLabel`
- Fade the panel properly
- Maintain smooth animations

## Next Steps

1. Test by walking through the triggers
2. Customize messages in the Inspector
3. The text should now be clearly visible!

If you still don't see the text, check:
- Is the ObjectMessageUI visible in the scene?
- Is the MessageLabel showing "Tutorial Message" in the Inspector?
- Are you zoomed in enough to see the 600x120px box?
