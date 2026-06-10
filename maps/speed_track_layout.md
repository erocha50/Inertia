# Dynamic Speed Track Layout
## Sonic-like Soulslike Track Design

### Map Philosophy
- **Player Size Reference**: Capsule ~1.8 units tall, ~0.5 units radius
- **Movement Styles**: Velocity-based running, sliding, wall riding, wall jumping, dash attacks
- **Flow**: Progressive speed buildup with recovery sections and technical challenges

### Sections Overview

#### SECTION 1: Launch Pad (0 to 50 units)
- Straight flat floors for initial momentum building
- 3x Floor segments creating a corridor
- Purpose: Get player up to speed, test basic controls
- Wall jumps available as alternatives

#### SECTION 2: First Ascent (50 to 100 units)
- Gradual ramp up at ~20-30 degree angle
- Ramp slope boost applies (+slide_slope_boost = 18.0)
- Player reaches speed_max territory
- Wall on left side for wall riding challenge at the top

#### SECTION 3: Technical Turn Challenge (100 to 140 units)
- Floor with 45-degree left turn via ramps
- Tests turning at high speed (arc braking, momentum)
- Tight spacing encourages slide + wall jump combos
- Short wall for emergency wall ride / bounce recovery

#### SECTION 4: Drop & Speed Rush (140 to 200 units)
- Descending ramp section
- Slide-friendly downhill (friction = 4.0, slide_friction applied)
- Gravity assists acceleration (slide_slope_boost active)
- Long straightaway for maximum velocity buildup

#### SECTION 5: Wall Ride Challenge (200 to 260 units)
- Vertical wall for extended wall riding (wall_ride_time_limit = 1.25s)
- Floor platforms at intervals for reset
- Wall jump to climb via momentum
- Tests wall_jump_force mechanics (up/out/fwd)

#### SECTION 6: The Momentum Arc (260 to 320 units)
- Series of banked ramps (left-right zigzag)
- Tests arc turning (arc_threshold = 70°, arc_turn_rate = 140°/s)
- Momentum resistance scaling at speed_max speeds
- Rewards smart momentum preservation

#### SECTION 7: Dash Attack Gauntlet (320 to 380 units)
- Narrow corridor with walls on sides
- Enemies/obstacles to practice dash_attack_speed (38.0)
- Wall bounces (bounce_restitution = 0.55)
- Tests wall slam mechanics (wall_slam_threshold = 500)

#### SECTION 8: Air Control Section (380 to 440 units)
- Platforms over a drop with gap jumping
- Tests air_strafe mechanics (air_strafe_accel = 40.0)
- Coyote time usage (0.12s)
- Jump buffer mechanics (0.14s)

#### SECTION 9: Finale Speed Run (440+ units)
- Wide open straight with optional ramps
- No obstacles - pure speed achievement area
- Wall ride walls as optional vertical expression

---

## Key Variables from Player Controller

**Speed Mechanics**:
- `speed_min`: 10.0 (can't go below this)
- `speed_max`: 40.0 (horizontal cap, increased via momentum buildup)
- `momentum_full_speed`: 30.0 (where resistance starts)
- `momentum_resistance`: 0.92 (decay when over threshold)

**Sliding**:
- `slide_min_speed`: 6.0
- `slide_friction`: 4.0 (slow decay)
- `slide_slope_boost`: 18.0 (downhill acceleration)
- `slide_max_speed`: 60.0 (can exceed normal max!)
- Can steer with move input at `slide_steer_start` speed

**Wall Riding**:
- `wall_ride_enabled`: true
- `wall_ride_min_speed`: 8.0
- `wall_ride_gravity`: 8.0 (gentle pull)
- `wall_ride_drag`: 4.0
- `wall_ride_time_limit`: 1.25s
- `wall_jump_force_up`: 18.0
- `wall_jump_force_out`: 12.0
- `wall_jump_force_fwd`: 18.0

**Jump/Air**:
- `jump_velocity`: 15.0
- `gravity_rise`: 20.0 (slower ascent)
- `gravity_fall`: 42.0 (faster descent)
- `air_control`: 12.0
- `coyote_time`: 0.12s (can jump after leaving ground)
- `air_strafe_accel`: 40.0
- `air_strafe_wishcap`: 50.0

**Arc (Momentum Turn)**:
- `arc_threshold`: 70.0 degrees
- `arc_turn_rate`: 140.0 deg/s
- Tests at corners and banked turns

**Damage**:
- `fall_damage_spd`: 22.0 (landing at high speed = damage)
- Impacts > 22 emit impact signals

---

## Track Section Placements

Using Godot unit system (1 unit ≈ 1 meter):

```
START (0, -27, 0)
│
├─ FLOOR (10×0.1×10 scaled) - Launch Pad
├─ FLOOR - Straightaway
├─ RAMP (ascending 20°) - First Ascent
├─ WALL (left side) - Wall challenge
├─ RAMP (20° turn left) - Technical corner
├─ FLOOR - Setup for drop
├─ RAMP (descending -30°) - Speed Rush
├─ FLOOR (long) - Max speed zone
├─ WALL (tall, vertical) - Wall Ride Challenge
├─ FLOOR (platform) - Recovery
├─ RAMP (banked L) - Momentum Arc L
├─ RAMP (banked R) - Momentum Arc R
├─ WALL (narrow corridor walls) - Dash Gauntlet
├─ FLOOR (gap floor) - Air Control
├─ FLOOR (final straight) - Finale
└─ GOAL
```

---

## Design Rationale

### For Sliding Mechanics
- Downhill sections (ramps at negative angle) trigger slide_slope_boost
- Long straightaways let slide_friction decay naturally
- Tight corners challenge slide steering control

### For Wall Riding
- Vertical walls with minimal curvature
- Positioned where player has forward momentum
- Wall jump is primary exit (jump input)
- Alternatives: loss of speed, timeout

### For Jumps & Air Control
- Gaps between platforms force air strafe usage
- Short coyote window rewards timing
- Jump buffer lets player "queue" jumps

### For Dash Attack
- Narrow corridors limit evasion
- Wall bounces create emergent moment routes
- Cooldown (5.0s) means strategic use

### For Overall Flow
- Progressive difficulty ramp-up
- Multiple paths (ground, wall, air) through sections
- Reward skilled momentum management
- Recovery sections prevent snowballing failures
