# Wall Ride Camera Tilt Implementation

## Overview
This implementation adds smooth camera tilting during wall ride states to automatically orient the camera toward the wall the player is riding on. This provides a better view angle automatically without requiring manual camera adjustments.

## Features
- **Automatic Camera Tilt**: When the player enters a wall ride state, the camera smoothly tilts toward the nearest wall
- **Configurable Angle**: Default 30-degree tilt angle (adjustable via export)
- **Smooth Transitions**: Uses lerp-based smooth camera rotation without FOV changes
- **No FOV Changes**: Only affects camera rotation on the Z-axis, preserves FOV for consistency
- **State-Aware**: Automatically disables when exiting wall ride state

## Implementation Details

### Files Modified

#### 1. `res://Scripts/camera_shiftlock.gd`
**New Exports Added:**
```gdscript
@export_group("Wall Ride Camera")
@export var wall_tilt_enabled:bool=true
@export var wall_tilt_angle:float=30.0
@export var wall_tilt_smooth:float=8.0
```

**New State Variables:**
```gdscript
var _wall_tilt_target:float=0.0
var _wall_tilt_current:float=0.0
var _is_wall_riding:bool=false
```

**New Methods:**
- `_on_state_changed(new_state:int)`: Tracks when player enters/exits WALL_RIDE state (State 5)
- `_update_wall_tilt()`: Calculates tilt angle based on wall normal and camera orientation

**Modified Methods:**
- `_ready()`: Added connection to `state_changed` signal
- `_process()`: Added wall tilt update and smooth lerp calculation
- `_apply_orbital_transform()`: Added wall tilt to camera Z rotation

**Key Algorithm:**
1. Gets wall normal from player's exposed `wall_normal_exposed` variable
2. Projects wall normal onto horizontal plane for calculation
3. Uses cross product to determine which direction to tilt
4. Smoothly lerps between current and target tilt angle
5. Applies tilt to camera rotation.z

#### 2. `res://Scripts/player_controller.gd`
**New Variable Added:**
```gdscript
var wall_normal_exposed:Vector3=Vector3.ZERO
```

**Modified Method:**
- `_wall_ride()`: Now updates `wall_normal_exposed` each frame with current wall normal

## How It Works

### State Detection
The camera listens to the player's `state_changed` signal. When the state becomes WALL_RIDE (int value 5), the camera enables wall tilt tracking.

### Wall Normal Acquisition
During wall ride, the player updates `wall_normal_exposed` with the current wall normal vector. The camera retrieves this each frame.

### Tilt Calculation
1. **Horizontal Projection**: Wall normal is projected onto the horizontal plane
2. **Direction Determination**: Cross product between camera forward and wall normal determines tilt direction
3. **Angle Assignment**: Target tilt is set to ±30° (or configured angle) based on which side the wall is

### Smooth Application
The tilt is smoothly interpolated using lerp with `wall_tilt_smooth` speed (default 8.0), providing fluid camera movement without jarring instant rotations.

### Automatic Reset
When the player leaves the wall ride state, `_wall_tilt_target` resets to 0.0, smoothly returning the camera to normal orientation.

## Configuration

You can adjust the wall camera behavior in the Editor by modifying these export variables on the CameraController node:

- **wall_tilt_enabled**: Toggle the feature on/off (default: true)
- **wall_tilt_angle**: Tilt angle in degrees (default: 30.0°)
- **wall_tilt_smooth**: Smoothing speed, higher = faster transition (default: 8.0)

## Testing

To test the wall camera tilt:
1. Open `res://maps/test_play_world.tscn`
2. Look for the "Wall Hop" structure with walls in the scene
3. Jump toward the walls to trigger wall riding
4. The camera should automatically tilt toward the wall at ~30°
5. As you move along the wall, the tilt angle should update smoothly
6. When you leave the wall, the camera should smoothly return to normal

## Technical Notes

- The implementation uses normalized vectors for all calculations to ensure consistent behavior regardless of geometry scale
- The wall normal is obtained each frame during wall ride, ensuring the tilt updates as the wall orientation changes
- The camera continues to support all existing features (FOV changes, shake, lean, etc.) - this is purely additive
- The Z-axis rotation is independent of all other camera rotations and movements

## Future Enhancements

Potential improvements for this feature:
1. **Distance-based Tilt**: Vary tilt angle based on proximity to wall
2. **Smart Angle Interpolation**: Smoothly transition between different walls without sudden jumps
3. **Oscillation Prevention**: Add deadzone to prevent tiny oscillations near perpendicular angles
4. **Priority System**: Handle multiple nearby walls with closest-wall priority
