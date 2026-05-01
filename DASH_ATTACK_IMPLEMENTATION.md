# Dash Attack Implementation - Complete

## Summary
The dash attack system has been fully implemented in the player controller. This is a powerful offensive ability that launches the player in a direction with momentum-scaled speed.

## What's Implemented

### 1. **Core Variables & Configuration** (Lines 58-64, 125-129)
- `@export var dash_attack_force: float = 50.0` - Base attack force
- `@export var dash_attack_cooldown: float = 5.0` - Cooldown between attacks
- `@export var dash_attack_fov_pop: float = 15.0` - FOV pop amount for camera effect
- `@export var dash_attack_fov_duration: float = 0.3` - Duration of FOV pop
- `@export var dash_attack_momentum_scale: float = 1.5` - Multiplier for momentum-based speed
- `@export var dash_attack_min_speed: float = 15.0` - Minimum dash speed threshold
- Internal state tracking variables:
  - `_dash_attack_cd: float` - Cooldown timer
  - `_dash_attack_active: bool` - Whether currently attacking
  - `_dash_attack_dir: Vector3` - Locked direction during attack
  - `_dash_attack_end_time: float` - When the attack ends
  - `_dash_attack_duration: float` - How long the attack lasts (0.2s)

### 2. **Signal** (Line 118)
- `signal dash_attack_performed()` - Emitted when dash attack is executed

### 3. **Input Handling** (Line 180 in _physics_process)
```gdscript
if Input.is_action_just_pressed("dash_attack"): _perform_dash_attack()
```
- Input action "dash_attack" is bound to left mouse button (defined in project.godot)
- Called every frame in _physics_process to check for input

### 4. **Cooldown Management** (Lines 177, 183-186)
```gdscript
_dash_attack_cd = maxf(_dash_attack_cd - d, 0.0)  # Tick down cooldown
if _dash_attack_active:
    _dash_attack_end_time = maxf(_dash_attack_end_time - d, 0.0)
    if _dash_attack_end_time <= 0.0:
        _dash_attack_active = false
```
- Cooldown is decremented each frame
- Active state is maintained for the duration of the attack

### 5. **Main Implementation: _perform_dash_attack()** (Lines 514-554)
The function:
- **Checks cooldown** - Returns early if on cooldown
- **Calculates momentum factor** - Based on current speed vs max speed (0 to 1)
- **Computes effective force** - Base force + momentum-scaled bonus
  - `effective_force = dash_attack_force + dash_attack_force * momentum_factor * dash_attack_momentum_scale`
- **Determines direction** (priority order):
  1. Player's current WASD input direction
  2. Current velocity direction (if moving)
  3. Camera forward direction (if stationary)
- **Locks direction** - Stores direction to prevent input during attack
- **Sets velocity** - Applies computed dash speed in locked direction
- **Activates state** - Sets `_dash_attack_active = true` and timer
- **Triggers cooldown** - Sets `_dash_attack_cd = dash_attack_cooldown`
- **Emits signal** - Triggers `dash_attack_performed` for feedback systems

### 6. **Input Lock During Attack** (Line 340)
```gdscript
var wish := Vector3.ZERO if (_dash_attack_active or _roll_active) else _wish_dir()
```
- Player input is ignored during dash attack duration
- Velocity maintains locked direction throughout the attack

### 7. **Camera Integration** (Lines 549-550, 611-613)
- Calls `_apply_dash_attack_camera_pop()` which triggers the camera effect
- Camera controller listens to `dash_attack_performed` signal (camera_shiftlock.gd)
- Camera applies impact trauma (shake) when attack is performed

### 8. **Camera Handler** (res://Scripts/camera_shiftlock.gd, Lines 114-116)
```gdscript
func _on_dash_attack()->void:
    """Handle dash attack performed signal - triggers camera shake and FOV effect"""
    _impact_trauma = maxf(_impact_trauma, impact_shake_deg * 1.2)
```
- Increases camera shake intensity when dash attack is triggered
- Provides feedback through camera trauma system

## Behavior

### Attack Sequence
1. Player presses left mouse button (dash_attack input)
2. `_perform_dash_attack()` is called
3. If cooldown is 0:
   - Player's horizontal velocity is set to attack direction × computed speed
   - `_dash_attack_active` becomes true
   - Timer is set to 0.2 seconds
   - Cooldown timer is set to 5.0 seconds
   - Signal is emitted
4. During the 0.2s attack duration:
   - Player maintains the locked direction and speed
   - WASD input is ignored
   - Player moves in straight line
5. After 0.2s:
   - `_dash_attack_active` becomes false
   - Normal controls resume
6. After 5.0s:
   - Cooldown expires, can dash attack again

### Speed Calculation
- **Minimum momentum**: When stationary, speed = 15.0 (dash_attack_min_speed)
- **With momentum**: Speed scales up based on current movement speed
  - Example: If moving at 30 units/s (75% of 40 max), momentum_factor = 0.75
  - Effective force = 50 + (50 × 0.75 × 1.5) = 50 + 56.25 = 106.25
  - Speed capped to max of this value (so minimum 15.0 is only used when speed is low)

## Testing Recommendations

1. **Test stationary attack** - Press attack while standing still
   - Should dash at minimum speed (15.0) in camera forward direction

2. **Test momentum scaling** - Gain speed, then press attack
   - Attack speed should increase based on run speed

3. **Test direction priority** - Try with different input combinations:
   - Press attack while holding WASD - should go that direction
   - Press attack while moving without input - should go momentum direction
   - Press attack while stationary without input - should go camera forward

4. **Test cooldown** - Rapidly press attack
   - Should only work once every 5 seconds

5. **Test camera feedback** - Watch FOV and camera shake
   - Camera should show impact when attack is performed

## Related Systems

- **HeatManager**: Not directly integrated, but `dash_attack_performed` signal is available for heat cost
- **Animation system**: `dash_attack_performed` signal can trigger attack animations
- **Damage system**: Attack direction is tracked in `_dash_attack_dir` for hit detection
- **State machine**: Properly ignores input during attack via `_horiz()` function

## Future Enhancements

1. Add hit detection and damage dealing during attack
2. Add particle effects at start and end of attack
3. Add trail effect during dash
4. Integrate with animation system for attack animations
5. Add heat cost to HeatManager on dash attack
6. Add wind-up time before attack launches
