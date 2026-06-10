# Test Play World - Sonic-Like Soulslike Speed Test Room

## 🎯 What is this?

Your **test_play_world.tscn** is now a **professional testing facility** for your Sonic-like velocity-based player controller. It contains **8 organized, non-overlapping zones**, each designed to isolate and test specific movement mechanics.

Think of it like a physics testing lab - clean, organized, methodical. This is where you'll dial in the feel of your game before building real levels.

---

## 📦 What's Included

### Scene: `test_play_world.tscn`
- **8 independent testing zones** arranged in a grid
- **No overlapping geometry** - clean layout
- **Player spawns in Zone 1** - easy access to all zones
- **Simple, flat backgrounds** - focus on mechanics, not visuals
- **Pre-positioned with proper lighting**

### Documentation Files

1. **TEST_ROOM_GUIDE.md** (Primary)
   - Detailed breakdown of each zone
   - What mechanics are tested
   - How to test them properly
   - Physics parameters explained
   - Tuning strategies

2. **TEST_ZONES_QUICK_REFERENCE.txt** (Cheat Sheet)
   - Quick lookup table
   - Spawn coordinates for each zone
   - Checklist for testing
   - Physics quick-tune guide
   - Control scheme

3. **README.md** (This File)
   - Overview and workflow
   - File structure
   - Getting started guide

---

## 🗺️ The 8 Testing Zones

```
┌─────────────────────────────────────────────────────┐
│  ZONE 1: ACCELERATION          Wide flat floor       │
│  → Tests: Base movement, speed ramps, steering       │
│                                                     │
│  ZONE 2: SLIDING              Downslope + flat      │
│  → Tests: Friction, slope bonus, speed caps         │
│                                                     │
│  ZONE 3: WALL RIDING          Tall vertical wall     │
│  → Tests: Wall contact, gravity reduction, timer    │
│                                                     │
│  ZONE 4: WALL JUMPING         Twin walls, gaps      │
│  → Tests: Wall jump forces, chaining, momentum      │
│                                                     │
│  ZONE 5: JUMPING              Platform series       │
│  → Tests: Coyote time, air strafe, buffering        │
│                                                     │
│  ZONE 6: ARC TURNING          Ramp + turning        │
│  → Tests: Turn resistance, speed bleed, arc state   │
│                                                     │
│  ZONE 7: DASH ATTACK          Narrow corridor       │
│  → Tests: Dash state, wall bounces, collision       │
│                                                     │
│  ZONE 8: AIR CONTROL          Multi-platform       │
│  → Tests: Air strafe, momentum preservation, precision
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 🚀 Getting Started

### 1. Load the Scene
```
File → Open Scene
res://maps/test_play_world.tscn
```

### 2. Enter Play Mode
```
Press F5 (or Play button)
```

You'll spawn in **ZONE 1 (Acceleration)** at position (-80, -30, -50).

### 3. Navigate the Zones
- **ZONE 1**: Forward direction (↑)
- **ZONE 2**: Right from Zone 1 (→)
- **ZONE 3**: Far right (→→)
- **ZONE 4**: Left from start, then forward (←, then ↑)
- **ZONE 5**: Center, forward (forward, then ↑)
- **ZONE 6**: Far right, forward (→→, then ↑)
- **ZONE 7**: Left side, far forward (←, then ↑↑)
- **ZONE 8**: Right side, far forward (→→, then ↑↑)

### 4. Test Each Zone
- See TEST_ROOM_GUIDE.md for detailed testing procedures
- Check TEST_ZONES_QUICK_REFERENCE.txt for quick reminders
- Follow the testing checklist as you go

---

## 🎮 Controls

From your project.godot:
| Key | Action |
|-----|--------|
| W / ↑ | Move forward |
| S / ↓ | Move backward |
| A / ← | Strafe left |
| D / → | Strafe right |
| **Space** | Jump |
| **Shift** | Slide (if speed > 6) |
| **Left Click** | Dash Attack |
| **Q** | Roll |
| **Mouse** | Look around |

---

## 📊 Physics Variables by Zone

### ZONE 1 (Acceleration)
```gdscript
speed_min = 10.0              # Can't go slower
speed_max = 40.0              # Normal speed cap
acceleration = 60.0           # Forward speed gain
friction_accel = 0.95         # Speed loss when not accelerating
```

### ZONE 2 (Sliding)
```gdscript
slide_min_speed = 6.0         # Minimum speed to slide
slide_friction = 4.0          # Decay while sliding
slide_slope_boost = 18.0      # Downhill acceleration
slide_max_speed = 60.0        # Sliding allows 50% overspeed
```

### ZONE 3 (Wall Riding)
```gdscript
wall_ride_min_speed = 8.0     # Entry speed requirement
wall_ride_gravity = 8.0       # Reduced gravity on wall
wall_ride_drag = 4.0          # Forward decay while riding
wall_ride_time_limit = 1.25   # Max seconds on wall
```

### ZONE 4 (Wall Jumping)
```gdscript
wall_jump_force_up = 18.0     # Vertical boost
wall_jump_force_out = 12.0    # Away from wall
wall_jump_force_fwd = 18.0    # Along wall direction
```

### ZONE 5 (Jumping)
```gdscript
jump_velocity = 15.0          # Initial upward speed
coyote_time = 0.12            # Post-edge jump window (seconds)
jump_buffer_t = 0.14          # Pre-jump buffer (seconds)
gravity_rise = 20.0           # Ascending gravity
gravity_fall = 42.0           # Falling gravity
air_strafe_accel = 40.0       # In-air acceleration
```

### ZONE 6 (Arc Turning)
```gdscript
arc_threshold = 70.0          # Degrees to trigger arc state
arc_turn_rate = 140.0         # Max rotation speed (°/s)
corner_speed_bleed = 0.80     # Speed decay per degree
momentum_full_speed = 30.0    # Speed for full momentum resistance
momentum_resistance = 0.92    # Resistance multiplier
```

### ZONE 7 (Dash Attack)
```gdscript
dash_attack_speed = 38.0      # Speed during dash
bounce_restitution = 0.55     # Speed retained on bounce
bounce_min_speed = 6.0        # Minimum speed to bounce
```

### ZONE 8 (Air Control)
```gdscript
air_strafe_accel = 40.0       # Horizontal acceleration in air
air_strafe_wishcap = 50.0     # Max additional speed
air_strafe_speed_cap = 1.3    # Total speed multiplier cap
```

---

## 🔧 Common Tweaking Scenarios

### "Game feels too slow"
1. Go to ZONE 1
2. Edit player_controller.gd:
   - Increase `acceleration` (currently 60.0, try 75.0)
   - OR increase `speed_max` (currently 40.0, try 50.0)
3. Test in ZONE 1, verify before moving to others

### "Turning feels bad"
1. Go to ZONE 6
2. Edit player_controller.gd:
   - Decrease `arc_threshold` (currently 70.0, try 60.0)
   - OR increase `arc_turn_rate` (currently 140.0, try 180.0)
3. Test in ZONE 6, sweep other zones for side effects

### "Jumping feels floaty"
1. Go to ZONE 5
2. Edit player_controller.gd:
   - Increase `gravity_fall` (currently 42.0, try 50.0)
   - OR decrease `jump_velocity` (currently 15.0, try 12.0)
3. Test in ZONE 5, especially platform gaps

### "Wall riding is impossible"
1. Go to ZONE 3
2. Edit player_controller.gd:
   - Decrease `wall_ride_min_speed` (currently 8.0, try 5.0)
   - OR decrease `wall_ride_drag` (currently 4.0, try 2.0)
3. Test in ZONE 3

### "Sliding feels weak"
1. Go to ZONE 2
2. Edit player_controller.gd:
   - Increase `slide_slope_boost` (currently 18.0, try 24.0)
   - OR decrease `slide_friction` (currently 4.0, try 2.0)
3. Test in ZONE 2

---

## 📋 Testing Workflow

### Quick Testing (5 minutes)
```
1. Play scene (F5)
2. Move through each zone briefly
3. Feel for obvious problems
4. Identify problem zone
5. Stop (Escape)
```

### Deep Testing (15-30 minutes)
```
1. Play scene (F5)
2. Spawn in problem zone
3. Test specific mechanic thoroughly
4. Record behavior/video
5. Stop and edit variable
6. Replay same zone
7. Compare before/after
8. Repeat until satisfied
```

### Regression Testing (After changes)
```
1. Quick sweep all zones
2. Check each mechanic still works
3. Look for side effects
4. Document any changes
```

---

## 📸 How Each Zone Looks

When you load the scene in the editor:

- **Zone 1**: Large flat platform (25×25 units)
- **Zone 2**: Downward ramp leading to flat floor
- **Zone 3**: Tall vertical wall (16 units) with approach floor
- **Zone 4**: Two parallel walls with landing floor between
- **Zone 5**: Series of 4 platforms at varying heights
- **Zone 6**: Angled ramp with setup/recovery floors
- **Zone 7**: Narrow corridor with walls on sides
- **Zone 8**: 3 floating platforms + wide base and landing zones

All zones are **spatially separated** - no overlaps, no clipping.

---

## 🐛 Debugging Tips

### Problem: "Physics feel weird in Zone X"
**Solution**: 
1. Isolate to that zone
2. Run a simple test (e.g., just forward movement)
3. Measure the specific behavior
4. Compare to expected values in guide
5. Identify which variable is wrong

### Problem: "Changes in Zone X broke Zone Y"
**Solution**:
1. You changed a variable that affects both zones
2. Check which zones share that variable
3. Test both zones separately
4. Find a compromise value or split mechanics

### Problem: "Can't reach platform in Zone 8"
**Solution**:
1. Check `air_strafe_accel` value
2. Check `jump_velocity` value
3. Check `gravity_fall` value
4. One of these is too low for the gap
5. Increase the limiting factor

---

## 📁 File Structure

```
res://maps/
├── test_play_world.tscn          ← Main test scene
├── README.md                       ← This file
├── TEST_ROOM_GUIDE.md             ← Detailed zone guide
├── TEST_ZONES_QUICK_REFERENCE.txt ← Quick cheat sheet
├── floor.tscn                      ← Floor structure
├── ramp.tscn                       ← Ramp structure
└── wall.tscn                       ← Wall structure

res://characters/
└── player_controller.tscn         ← Player character

res://Scripts/
└── player_controller.gd           ← Physics values to tweak
```

---

## ✅ Verification Checklist

Before considering a zone "tested":
- [ ] Can complete the zone's primary mechanic
- [ ] Behavior matches expected values
- [ ] No unexpected clipping or physics
- [ ] Transitions smoothly to other zones
- [ ] Feel is responsive and fun

---

## 🎓 Best Practices

1. **Test one variable at a time** - Change only one number per test
2. **Use the zones in order** - Start with Zone 1, move forward
3. **Record before/after** - Video comparison helps spot differences
4. **Document changes** - "Changed X from Y to Z because W"
5. **Regression test after changes** - Quick sweep all zones
6. **Feel over numbers** - If it feels right, it's right

---

## 🚀 Next Steps

### When test room feels good:
1. Create real level using same mechanics
2. Use TEST_ROOM_GUIDE physics values as starting point
3. Test in new level
4. Tweak for level-specific challenges
5. Keep test room as reference

### To expand testing:
1. Add speed readout UI
2. Add zone timer display
3. Add physics debug overlay
4. Record best times per zone
5. Create difficulty variants

---

## 📚 Related Files

- **TEST_ROOM_GUIDE.md** - Detailed mechanics explanation
- **TEST_ZONES_QUICK_REFERENCE.txt** - Quick lookup table
- **player_controller.gd** - Physics variables to tweak
- **project.godot** - Input configuration

---

## 🎬 Video Walkthrough Concepts

If you're recording/streaming your testing:

1. **Intro**: Explain this is a testing facility
2. **Zone Tour**: Walk through each zone (2 min per zone)
3. **Test Procedure**: Show how you test one mechanic
4. **Variable Tuning**: Adjust one value, retest
5. **Regression Check**: Quick sweep all zones
6. **Summary**: Document findings

---

**Test Room Version**: 1.0  
**Player Controller**: Sonic-like with wall riding, momentum, sliding  
**Test Zones**: 8 isolated areas  
**Total Facility Size**: ~200×200 units  
**Documentation**: 3 files (this + guide + reference)

---

## Questions?

Refer to:
1. **TEST_ROOM_GUIDE.md** - For zone details and mechanics
2. **TEST_ZONES_QUICK_REFERENCE.txt** - For quick lookups
3. **player_controller.gd** - For variable definitions
4. **project.godot** - For input configuration

**Remember**: A well-designed test room is the foundation of a well-polished game. Take your time here - it pays dividends later!

Happy testing! 🚀
