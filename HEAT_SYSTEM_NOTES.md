# Heat System Implementation

## Overview
The heat system is now fully functional. The heat bar builds up when the player runs/moves and cools down when the player is idle. This encourages constant movement as a core gameplay mechanic.

## Changes Made

### 1. HeatManager.gd
Added dynamic heat management with three new exported properties:

```gdscript
@export var heat_gain_per_second: float = 30.0      # Heat gained while moving
@export var heat_loss_per_second: float = 15.0      # Heat lost while idle
@export var movement_speed_threshold: float = 2.0   # Min speed to count as "moving"
```

Added `_process()` method that automatically:
- **Gains heat** when `current_flat_speed >= movement_speed_threshold`
- **Loses heat** when the player is below the threshold (idle)

Added `update_speed()` method that receives speed updates from the player controller.

### 2. player_controller.gd
Added one line at the end of `_physics_process()`:
```gdscript
# Update HeatManager with current speed
HeatManager.update_speed(fs)
```

This sends the player's flat speed to the HeatManager every frame, enabling real-time heat management.

## Behavior

### Moving
- When the player moves at speed >= 2.0 units/sec, heat increases at **30 per second**
- At max speed (40 units/sec), the player will reach "hot" tier in ~2 seconds
- At max speed, reaching "burning" (75 heat) takes ~2.5 seconds

### Idle
- When standing still or moving slowly (< 2.0 units/sec), heat decreases at **15 per second**
- Starting from 100 heat (fully hot), it takes ~6.7 seconds to return to "cold" (0 heat)
- This creates tension: the player must keep moving or momentum will be lost

## Tiers & Damage Multiplier

- **Cold** (0-24%): 1.0x damage
- **Warm** (25-49%): 1.2x damage
- **Hot** (50-74%): 1.5x damage
- **Burning** (75-100%): 2.0x damage

## Tuning

You can adjust the heat rates in the Inspector on the HeatManager autoload:
- Lower `heat_gain_per_second` = longer to heat up
- Raise `heat_loss_per_second` = more pressure to keep moving
- Adjust `movement_speed_threshold` = speed at which heat starts building

Currently tuned for a fast-paced, momentum-driven gameplay style.
