# Dynamic Test Room - Sonic-Like Velocity Movement Testing
## Organized Zones for Soulslike Speed-Based Gameplay

---

## 🎮 Overview

The **test_play_world** is now a **structured testing facility** with **7 independent zones**, each designed to isolate and test specific movement mechanics. This is like a controlled lab for the player controller - clean, organized, and perfect for iterative testing and debugging.

**Design Philosophy**: Each zone is separated spatially so you can:
- Test individual mechanics without interference
- Measure specific behavior in isolation
- Debug without environmental complexity
- Record clean gameplay footage of each system
- Tweak physics values per-mechanic

---

## 🗺️ Room Layout

```
                         ZONE_JUMPING (0, 20~105)
                         Jump gaps & coyote timing
                              |
    ZONE_ACCEL        ZONE_TURNING        ZONE_VELOCITY_JUMP (80, 80~135)
    (-80, -50)        (80, 20~80)         Platform air control
    Linear speed      Arc turning &        Multi-platform strafe
                      ramps
              |              |              |
    ZONE_SLIDING      ZONE_WALLRIDE       ZONE_DASHATTAK
    (0, -50~-25)      (80, -50~-25)       (-80, 80)
    Slope + friction  Vertical wall       Dash corridor
              |              |              |
    ZONE_WALLJUMP (-80, 20~55)
    Twin walls & jumping momentum
    
Test Room spans: X[-100 to 100], Y[-20 to 10], Z[-50 to 135]
Player spawns at: (-80, -30, -50) - ACCELERATION zone entrance
```

---

## 📍 Zone Details & Usage

### **ZONE 1: ACCELERATION** (X: -80, Z: -50)
**Floor**: 25×25 units, perfectly flat

**Purpose**: Test base movement mechanics
- Measure acceleration ramp-up
- Test `speed_min` and `speed_max`
- Verify input responsiveness
- Check friction decay at rest

**Mechanics Tested**:
- `acceleration` (60.0) - forward speed gain
- `speed_min` (10.0) - minimum speed floor
- `speed_max` (40.0) - normal speed cap
- `friction_accel` (0.95) - gradual speedup
- Input steering response

**How to Test**:
1. Spawn here (default position)
2. Hold forward for 3 seconds
3. Observe: Should reach ~40 speed, feel responsive
4. Release input: Should gradually slow to ~10 (speed_min)
5. Strafe while running: Should turn smoothly

**Expected Behavior**:
```
Speed over time (forward held):
  t=0.0s: speed = 0
  t=0.5s: speed ≈ 20 (half max)
  t=1.0s: speed ≈ 35 (approaching max)
  t=2.0s: speed ≈ 39 (at max)
  
Release input:
  t=2.0s: speed = 39
  t=2.5s: speed ≈ 30 (friction_accel 0.95)
  t=3.0s: speed ≈ 25
  t=4.0s: speed ≈ 10 (reaches min)
```

**Debug Points**:
- [ ] Speed increases smoothly (not jerky)
- [ ] Turning works at all speeds
- [ ] Can reach max speed (40.0)
- [ ] Respects speed_min floor

**Tweak Variables**: `acceleration`, `friction_accel`, `speed_min`, `speed_max`

---

### **ZONE 2: SLIDING** (X: 0, Z: -50 to -25)
**Features**: Downward ramp (tall) + flat floor at bottom

**Purpose**: Test slope physics and slide mechanics
- Slope bonus acceleration
- Friction on slopes vs. flat
- Max speed cap increase during slide
- Speed decay after slide ends

**Mechanics Tested**:
- `slide_min_speed` (6.0) - entry requirement
- `slide_friction` (4.0) - natural decay
- `slide_slope_boost` (18.0) - slope bonus
- `slide_max_speed` (60.0) - slide speed cap
- Gravity interaction on slopes

**How to Test**:
1. Run from ACCELERATION zone into slope
2. Approach ramp with ~30+ speed
3. Press **Shift** to slide
4. Observe speed buildup on downslope
5. Reach bottom, keep sliding on flat section
6. Watch speed decay back to normal cap

**Expected Behavior**:
```
Slide on downslope:
  Entry: speed = 30
  Slope bonus: +18.0/frame
  Gravity: +9.0/frame (downward component)
  Friction: -4.0/frame
  Net: ~+23/frame (if slope is steep)
  Result: Speed increases toward 60.0
  
Exit to flat:
  Bonus stops: -18.0
  Friction remains: -4.0
  No gravity help
  Result: Speed decays toward 40.0 cap
```

**Debug Points**:
- [ ] Cannot slide below 6.0 speed
- [ ] Speed can exceed 40.0 while sliding (up to 60.0)
- [ ] Downslope clearly accelerates
- [ ] Friction works on flat after slope
- [ ] Slide animation/state visible

**Tweak Variables**: `slide_min_speed`, `slide_friction`, `slide_slope_boost`, `slide_max_speed`

**Pro Tip**: Use this zone to dial in the "feel" of sliding. Higher `slide_slope_boost` = more rewarding downhill. Higher `slide_friction` = harder to maintain speed on flat.

---

### **ZONE 3: WALL RIDING** (X: 80, Z: -50 to -25)
**Features**: Tall vertical wall (16 units) + approach floor

**Purpose**: Test extended wall contact and momentum preservation
- Wall stick mechanics
- Gravity reduction during ride
- Time limit enforcement
- Forward speed preservation

**Mechanics Tested**:
- `wall_ride_enabled` (true)
- `wall_ride_min_speed` (8.0) - entry speed
- `wall_ride_gravity` (8.0) - reduced gravity
- `wall_ride_drag` (4.0) - forward momentum decay
- `wall_ride_time_limit` (1.25s) - max duration

**How to Test**:
1. Run from ACCELERATION toward wall with 20+ speed
2. Contact wall - should stick if speed >8.0
3. Hold forward input to maintain contact
4. Observe slow descent (wall_ride_gravity)
5. Hold for full 1.25s - should eject automatically
6. Jump mid-ride to test wall jump output

**Wall Riding States**:
```
Entry (touching wall):
  Condition: speed >= wall_ride_min_speed (8.0)
  Result: Horizontal velocity preserved, vertical = wall_ride_gravity
  
During Ride:
  Applied: wall_ride_gravity (8.0) downward (vs normal 42.0)
  Applied: wall_ride_drag (4.0) forward decay
  Stick force: 2.0 units keeps you on wall
  Duration: tracks up to 1.25s
  
Exit by Input (Jump):
  Vertical: +18.0 (wall_jump_force_up)
  Outward: +12.0 (wall_jump_force_out)
  Forward: +18.0 (wall_jump_force_fwd)
  
Exit by Time:
  Auto-eject after 1.25s
  State returns to air (preserve momentum)
  
Exit by Speed:
  If forward speed drops below 8.0
  Cannot maintain wall contact
```

**Debug Points**:
- [ ] Cannot enter below 8.0 speed
- [ ] Can ride wall for full 1.25s
- [ ] Descent is slow and controlled
- [ ] Wall jump produces momentum boost
- [ ] Forward speed gradually decays
- [ ] Time limit auto-ejects you

**Tweak Variables**: `wall_ride_min_speed`, `wall_ride_gravity`, `wall_ride_drag`, `wall_ride_time_limit`, wall jump forces

**Pro Tip**: Lower `wall_ride_gravity` = floatier feel (easier for players). Lower `wall_ride_drag` = more speed preservation (harder physics). Adjust these to match your desired difficulty.

---

### **ZONE 4: WALL JUMPING** (X: -80, Z: 20 to 55)
**Features**: Setup floor + twin walls (14 units tall, spaced apart) + landing floor

**Purpose**: Test wall jump mechanics and momentum from wall bounces
- Jump output consistency
- Wall jump timing
- Recovery paths between walls
- Momentum management in tight spaces

**Mechanics Tested**:
- `wall_jump_force_up` (18.0)
- `wall_jump_force_out` (12.0)
- `wall_jump_force_fwd` (18.0)
- Wall jump cooldown (if implemented)
- Twin-wall technique (advanced)

**How to Test**:
1. Approach from ZONE 1 with good speed (30+)
2. Run toward LEFT wall, jump
3. Hit wall, should ride if speed >8
4. Press jump input - should get wall jump boost
5. Boost should arc you toward RIGHT wall
6. Land on right wall, repeat
7. Or land on center floor, recover

**Twin-Wall Technique**:
```
Left Wall Jump:
  Exit velocity: Up(18) + Out(12) + Fwd(18)
  Arc: 45° upward-outward
  Landing: On right wall or center floor
  
Right Wall Jump:
  Exit velocity: Up(18) + Out(-12) + Fwd(18)
  Arc: 45° upward-outward (opposite direction)
  Landing: Back to left wall or center floor
```

**Debug Points**:
- [ ] Can initiate wall ride on both walls
- [ ] Wall jump produces upward arc
- [ ] Outward force pushes away from wall
- [ ] Forward force maintains horizontal velocity
- [ ] Can chain wall jumps between walls
- [ ] Landing floor is always safe

**Tweak Variables**: wall jump forces - higher = more extreme arcs

**Skill Expression**: This zone teaches wall jump chaining. Easy: Jump once to floor. Medium: Jump to opposite wall, land. Hard: Alternate walls repeatedly for height/distance.

---

### **ZONE 5: JUMPING** (X: 0, Z: 20 to 105)
**Features**: Long series of platforms at varying heights with gaps

**Purpose**: Test jump mechanics, coyote time, air strafing
- Jump input buffering
- Coyote time window (post-edge jumps)
- Mid-air control
- Air acceleration toward platforms

**Mechanics Tested**:
- `jump_velocity` (15.0)
- `coyote_time` (0.12s) - post-edge jump window
- `jump_buffer_t` (0.14s) - pre-jump buffer
- `gravity_rise` (20.0) - ascending gravity
- `gravity_fall` (42.0) - falling gravity
- `air_strafe_accel` (40.0) - in-air horizontal acceleration

**Platform Sequence**:
```
Platform 1 (Z: 20): Wide start, elevation Y: -10
    ↓ Jump (gap ~30 units)
Platform 2 (Z: 50): Medium, elevation Y: -5
    ↓ Jump (gap ~25 units)
Platform 3 (Z: 75): Medium, elevation Y: 0
    ↓ Jump (gap ~30 units)
Platform 4 (Z: 105): Wide landing, elevation Y: -10
```

**How to Test**:
1. Approach Platform 1 from ACCELERATION zone
2. Build speed (30+)
3. Walk toward edge confidently
4. At edge, BEFORE falling, press jump - tests coyote time
5. Mid-air, steer toward next platform with A/D
6. Land on Platform 2
7. Repeat for each gap

**Coyote Time Details**:
```
Walking off edge:
  t=0.0: Still on ground (coyote enabled)
  t=0.04s: In air (coyote still active)
  t=0.08s: In air (coyote still active)
  t=0.12s: In air (coyote expires here)
  
If jump pressed t=0.08s: ✓ Jump executes (within coyote window)
If jump pressed t=0.14s: ✗ Jump fails (past coyote_time of 0.12s)

BUT with jump buffer (0.14s pre-buffer):
If jump pressed t=-0.06s: Buffered, executes at t=0 when grounded
```

**Air Strafe Details**:
```
In air with directional input (A/D):
  Acceleration: 40.0 units/frame
  Wishcap: 50.0 max additional speed
  Total speed cap: 1.3x normal (52 units at 40 max)
  Friction preservation: 0.995/frame
  Result: Can steer mid-air toward platforms
```

**Debug Points**:
- [ ] Can jump at edge (coyote time working)
- [ ] Cannot jump after falling 0.12s+ (coyote expired)
- [ ] Can steer mid-air toward platforms
- [ ] Landing feels consistent and safe
- [ ] Jump buffer allows early jump presses
- [ ] Reaching Platform 4 is always possible

**Tweak Variables**: `coyote_time`, `jump_buffer_t`, `gravity_rise`, `gravity_fall`, `air_strafe_accel`

**Pro Tip**: 
- Increase `coyote_time` for forgiving platforming (good for casual games)
- Decrease for precision (good for hardcore games)
- Increase `air_strafe_accel` for more responsive air control

---

### **ZONE 6: ARC TURNING** (X: 80, Z: 20 to 80)
**Features**: Setup floor + angled ramp + recovery floor

**Purpose**: Test momentum-based arc turning
- Turning at speed maintains momentum
- Arc state activation at angle thresholds
- Speed bleed during turns
- Corner assist functionality

**Mechanics Tested**:
- `arc_threshold` (70°) - turn angle to trigger arc state
- `arc_turn_rate` (140°/s) - max rotation speed during arc
- `corner_speed_bleed` (0.80) - speed decay per degree
- `corner_assist_str` (0.30) - auto-steer toward direction
- `momentum_resistance` (0.92) - resistance at speed

**How to Test**:
1. Approach from ACCELERATION with 30+ speed
2. Enter recovery floor to stabilize
3. Approach ramp that's angled left (rotated -3 in X transform)
4. At ramp entry, turn hard left (>70°)
5. Observe: Player enters arc state
6. Feel the resistance to turning (arc_turn_rate limits rotation)
7. Feel the speed loss as you turn (corner_speed_bleed)
8. Complete turn onto recovery floor
9. Measure final speed vs. initial

**Arc State Activation**:
```
Condition: Turn angle > arc_threshold (70°) AND speed > momentum_full_speed (30.0)

Effect:
  - arc_turn_rate (140°/s) limits how fast you can rotate
  - More restrictive than normal turning
  - Speed decays per degree: speed *= pow(0.80, turn_degrees * delta)
  
Example: 35° turn at 40 speed
  Turn factor: pow(0.80, 35 * delta)
  Speed loss: ~10-15% of current speed
```

**Speed Bleed Formula**:
```
If turning more degrees in arc state:
  speed_decay = pow(corner_speed_bleed, turn_angle_accumulated * delta)
  
More aggressive turn = faster speed loss
Shallow turn = minimal speed loss
```

**Debug Points**:
- [ ] Can turn without arc below 70° threshold
- [ ] Arc state engages above 70° at speed
- [ ] Rotation is limited to 140°/s
- [ ] Speed decreases during turn (measurable)
- [ ] Can complete recovery on far floor
- [ ] Final speed is 60-70% of initial (rough estimate)

**Tweak Variables**: `arc_threshold`, `arc_turn_rate`, `corner_speed_bleed`

**Balance Tips**:
- Lower `arc_turn_rate` = tighter control but slower turning
- Higher `corner_speed_bleed` = speed loss is worse, rewards gentle turning
- Lower thresholds encourage aggressive play; higher reward caution

---

### **ZONE 7: DASH ATTACK** (X: -80, Z: 80)
**Features**: Approach floor + narrow corridor (2 walls, tight space, 22 units deep)

**Purpose**: Test dash attack mechanic and wall bouncing
- Dash state activation
- Limited steering during dash
- Wall collision response
- Bounce mechanics

**Mechanics Tested**:
- Dash attack input (Left Click)
- `dash_attack_speed` (38.0) during active window
- Dash duration (0.28s)
- Wall bouncing with `bounce_restitution` (0.55)
- Recovery positioning

**How to Test**:
1. Approach corridor floor from ZONE 1
2. Build speed to 25+ (near walls provide contrast)
3. When aligned with corridor, click (dash attack)
4. Player enters dash state - high speed, limited steering
5. Corridor is narrow - tight navigation test
6. Hit wall at angle - should bounce (restitution 0.55)
7. Continue through or exit corridor
8. Wait 5s cooldown before next dash

**Dash Attack Details**:
```
Input: Left Mouse Click
Activation: Instant, any state
Duration: 0.28 seconds
Speed: 38.0 units/sec (capped)
Steering: A/D only (limited control)
Forward Input: Disabled during dash
Deceleration Spike: -55.0/sec during active window
Cooldown: 5.0 seconds before next dash

Exit conditions:
  - Duration expires (0.28s)
  - Hit something and bounce
  - Player input changes
```

**Bounce Mechanics**:
```
Trigger: Hit wall at angle
Conditions:
  - Speed > bounce_min_speed (6.0)
  - Hit normal ⋅ velocity > bounce_dot_threshold (0.25)
  - Recent decel spike detected
  
Result:
  - Velocity reflects off surface
  - bounce_restitution (0.55) = 55% speed retention
  - slam_bounce_up boost upward component
  - Continue momentum through bounce
```

**Debug Points**:
- [ ] Dash attack activates on click
- [ ] Speed is 38 during dash
- [ ] Can steer with A/D (limited)
- [ ] Cannot add forward speed during dash
- [ ] Hit walls and bounce (not stop)
- [ ] Bounce preserves ~55% speed
- [ ] 5s cooldown before next dash
- [ ] Exit corridor without getting stuck

**Tweak Variables**: `dash_attack_speed`, dash duration, steering limits, `bounce_restitution`

**Pro Tip**: This zone tests both offense (dash attack) and environmental interaction (wall bounces). Use it to verify wall collision is responsive and bouncing feels natural.

---

### **ZONE 8: VELOCITY & AIR CONTROL** (X: 80, Z: 80 to 135)
**Features**: Large base floor + 3 floating platforms at heights/positions, wide landing zone

**Purpose**: Test full air control, air strafe, and landing mechanics
- Maintenance of momentum in air
- Precise platform landing with strafing
- Air acceleration toward targets
- Safe landing zones

**Mechanics Tested**:
- `air_strafe_accel` (40.0) - horizontal accel in air
- `air_strafe_wishcap` (50.0) - max additional speed
- `air_strafe_speed_cap` (1.3x) - total speed limit
- Momentum preservation (0.995/frame)
- Gravity during fall phases

**Platform Sequence**:
```
Base Floor (Z: 80, Y: -10): Wide start
    ↓ Jump + strafe
Platform 1 (Z: 105, Y: 0): Medium, LEFT
    ↓ Jump + strafe (diagonal)
Platform 2 (Z: 120, Y: 5): Small, CENTER-TOP
    ↓ Jump + strafe (tight)
Platform 3 (Z: 105, Y: 2): Medium, RIGHT
    ↓ Jump + strafe
Landing Floor (Z: 135, Y: -10): Wide recovery
```

**How to Test**:
1. Build speed on base floor (20+)
2. Jump toward Platform 1 (LEFT)
   - In air: Hold A (left strafe)
   - Feel horizontal acceleration
   - Land safely on platform 1
3. Jump toward Platform 2 (CENTER-UP)
   - Hold W+D (forward-right)
   - Diagonal strafe (air accel in 2D)
   - Land on small platform 2
4. Jump toward Platform 3 (RIGHT)
   - Hold D (right strafe)
   - Recover on platform 3
5. Jump to Landing Floor
   - Large target, should be easy
   - Safe recovery zone

**Air Strafe Physics**:
```
In air with directional input:
  wish_velocity = input_dir * air_strafe_accel (40.0)
  accelerate toward wish_velocity
  capped at air_strafe_wishcap (50.0) additional
  total capped at 1.3x base speed
  friction: 0.995/frame (very minimal)

Result: Can make significant mid-air course corrections
  Example: 20 unit/s speed
    Air strafe X: +40 accel for 0.5s = +20 additional
    Total: 40 unit/s (1.3x cap reaches 52)
```

**Debug Points**:
- [ ] Can maintain momentum through jump
- [ ] Can steer toward each platform
- [ ] Air acceleration is responsive
- [ ] Landing all 3 platforms is consistent
- [ ] Recovery floor is always reachable
- [ ] Landing feels smooth and forgiving
- [ ] Speed is retained between jumps

**Tweak Variables**: `air_strafe_accel`, `air_strafe_wishcap`, `air_strafe_speed_cap`, gravity

**Difficulty Scaling**:
- **Easy**: Increase platform sizes, increase landing zone
- **Medium**: Current setup
- **Hard**: Smaller platforms, more spread out, lower landing zone

---

## 🎯 Testing Workflow

### Daily Testing Routine

1. **Start in ZONE 1** - Verify base physics feel correct
2. **Quick sweep through each zone** - Check for showstoppers
3. **Deep dive into problem zone** - If something feels off
4. **Record video** - For comparison/documentation
5. **Adjust one variable** - Test in isolation
6. **Retest all zones** - Cascade effects check

### Physics Tuning Process

**Example: "Sliding feels too slow"**
```
1. Isolate in ZONE 2 (Sliding)
2. Check current variables:
   - slide_slope_boost = 18.0
   - slide_friction = 4.0
3. Try: Increase slope_boost to 22.0
4. Retest ZONE 2 only (fast)
5. If good, test ZONE 1, 4 for interaction
6. If bad, revert and try different variable
7. Document change with reason
```

### Regression Testing

After any change:
```
Test sequence (in order):
  ✓ ZONE 1 - Acceleration (baseline)
  ✓ ZONE 2 - Sliding (slope interaction)
  ✓ ZONE 3 - Wall Riding (vertical physics)
  ✓ ZONE 4 - Wall Jumping (momentum change)
  ✓ ZONE 5 - Jumping (air physics)
  ✓ ZONE 6 - Arc Turning (turn mechanics)
  ✓ ZONE 7 - Dash Attack (collision response)
  ✓ ZONE 8 - Air Control (composite mechanics)
```

---

## 📊 Physics Parameters Summary

### Speed & Movement
| Variable | Value | Zone | Notes |
|----------|-------|------|-------|
| `speed_min` | 10.0 | 1,2 | Floor on horizontal speed |
| `speed_max` | 40.0 | 1,2,5,6 | Normal speed cap |
| `acceleration` | 60.0 | 1 | Forward speed gain |
| `slide_max_speed` | 60.0 | 2 | Sliding allows 50% overspeed |
| `friction_accel` | 0.95 | 1 | Speed loss when not accelerating |

### Slopes & Slides
| Variable | Value | Zone | Notes |
|----------|-------|------|-------|
| `slide_min_speed` | 6.0 | 2 | Minimum speed to slide |
| `slide_friction` | 4.0 | 2 | Friction decay while sliding |
| `slide_slope_boost` | 18.0 | 2 | Downhill acceleration bonus |

### Wall Mechanics
| Variable | Value | Zone | Notes |
|----------|-------|------|-------|
| `wall_ride_min_speed` | 8.0 | 3,4 | Minimum speed to attach wall |
| `wall_ride_gravity` | 8.0 | 3 | Reduced gravity while riding |
| `wall_ride_drag` | 4.0 | 3 | Forward momentum decay |
| `wall_ride_time_limit` | 1.25s | 3 | Max duration on wall |
| `wall_jump_force_up` | 18.0 | 4 | Vertical boost |
| `wall_jump_force_out` | 12.0 | 4 | Away from wall |
| `wall_jump_force_fwd` | 18.0 | 4 | Along wall direction |

### Jumping & Air
| Variable | Value | Zone | Notes |
|----------|-------|------|-------|
| `jump_velocity` | 15.0 | 5 | Initial upward speed |
| `coyote_time` | 0.12s | 5 | Post-edge jump window |
| `jump_buffer_t` | 0.14s | 5 | Pre-jump input buffer |
| `gravity_rise` | 20.0 | 5 | Ascending gravity |
| `gravity_fall` | 42.0 | 5 | Falling gravity |
| `air_strafe_accel` | 40.0 | 5,8 | In-air acceleration |
| `air_strafe_wishcap` | 50.0 | 8 | Max additional speed |

### Turning
| Variable | Value | Zone | Notes |
|----------|-------|------|-------|
| `arc_threshold` | 70° | 6 | Angle to trigger arc state |
| `arc_turn_rate` | 140°/s | 6 | Rotation speed limit |
| `corner_speed_bleed` | 0.80 | 6 | Speed decay per degree |
| `momentum_resistance` | 0.92 | 6 | High-speed turn resistance |

### Dash & Collision
| Variable | Value | Zone | Notes |
|----------|-------|------|-------|
| `dash_attack_speed` | 38.0 | 7 | Speed during dash |
| `bounce_restitution` | 0.55 | 7 | Speed retention on bounce |
| `bounce_min_speed` | 6.0 | 7 | Minimum speed to bounce |

---

## 🔧 Quick Tweaking Guide

### "Game feels too slow"
- Increase `acceleration` (Zone 1)
- Increase `speed_max` (Zone 1)
- Decrease `friction_accel` (Zone 1)
- Increase `air_strafe_accel` (Zone 8)

### "Turning feels sluggish"
- Decrease `arc_threshold` (Zone 6 - lower angle triggers arc)
- Increase `arc_turn_rate` (Zone 6 - faster rotation)
- Decrease `corner_speed_bleed` (Zone 6 - less speed loss)

### "Wall riding is too hard"
- Increase `wall_ride_time_limit` (Zone 3 - more time)
- Increase `wall_ride_min_speed` cap slightly? No - lower barrier
- Decrease `wall_ride_drag` (Zone 3 - keep speed better)
- Decrease `wall_ride_gravity` (Zone 3 - slower descent)

### "Jumping feels floaty"
- Increase `gravity_fall` (Zone 5 - faster descent)
- Decrease `coyote_time` (Zone 5 - stricter timing)
- Decrease `jump_buffer_t` (Zone 5 - narrower buffer)

### "Sliding feels weak"
- Increase `slide_slope_boost` (Zone 2 - more bonus)
- Decrease `slide_friction` (Zone 2 - less decay)

---

## 📸 Visual Verification Checklist

When viewing the test room in editor:
- [ ] All 8 zones are visually separated
- [ ] No overlapping geometry between zones
- [ ] Floors are flat and stable
- [ ] Ramps have visible angles
- [ ] Walls are vertical and substantial (16 units for riding)
- [ ] Platforms in Zone 8 are at different elevations
- [ ] Corridor in Zone 7 looks appropriately narrow
- [ ] Player spawns inside Zone 1 (at base floor)

---

## 🚀 Next Steps

### To expand testing:
1. **Add speed readout UI** - Display current speed in HUD
2. **Zone timing** - Measure time to cross each zone
3. **Telemetry recording** - Log physics values for analysis
4. **Photo mode** - Pause and rotate camera for screenshots
5. **Instant replay** - 10-second buffer for cool moments

### To add advanced zones:
- **Zone 9: Loop Test** - Banked circular path
- **Zone 10: Spike Test** - Obstacle avoidance at speed
- **Zone 11: Momentum Transfer** - Multiple jumps maintaining speed
- **Zone 12: Enemy Interaction** - Combat in motion (boss test)

### To create variants:
- **Hard Mode Room** - Smaller platforms, tighter spaces
- **Training Room** - Slower speeds, forgiving mechanics
- **Speedrun Room** - Optimized path with checkpoints
- **Arena** - Circular deathmatch with pickup zones

---

## 🎓 Learning Resources

### For Physics Tuning:
- **Adjust one variable at a time** - Isolate cause/effect
- **Test in multiple zones** - Check for interactions
- **Video record results** - Compare before/after
- **Document all changes** - Track reasoning

### For Movement Feel:
- **Test at different speeds** - Does it feel good at 10? 30? 50?
- **Test at different angles** - Slopes, curves, spirals
- **Feel the acceleration curves** - Smooth vs. snappy
- **Compare to reference** - How does Sonic feel? How does Genshin feel?

### For Debugging:
1. **Is it reproducible?** - Can you repeat the issue?
2. **In which zone?** - Can you isolate it?
3. **Which variable?** - Narrow down the culprit
4. **What's the fix?** - Test and document

---

**Test Room Version**: 1.0  
**Last Updated**: Now  
**Player Controller Version**: With wall riding, momentum, sliding  
**Zones**: 8 isolated testing areas  
**Total Size**: ~200×200 unit facility

**Remember**: A good test space is the foundation of a good game. Take your time tuning physics here - it will payoff in the final product!
