class_name Player

extends CharacterBody3D

enum State { IDLE, RUN, AIR, SLIDE, ARC }

@export_group("Speed & Mass")
@export var speed_min:float=10.0;  @export var speed_max:float=40.0
@export var speed_ramp_rate:float=3.0; @export var speed_ramp_decay:float=8.0
@export var mass:float=1.0

@export_group("Horizontal")
@export var acceleration:float=60.0; @export var friction:float=80.0
@export var air_control:float=12.0;  @export var turn_boost:float=1.5
@export var arc_threshold:float=70.0; @export var arc_turn_rate:float=140.0
@export var arc_speed_drag:float=0.88

@export_group("Momentum")
@export var momentum_resistance:float=0.92; @export var momentum_full_speed:float=30.0
@export var momentum_bleed:float=0.28

@export_group("Corner Braking")
@export var corner_speed_bleed:float=0.80; @export var corner_min_speed:float=6.0
@export var corner_brake_ramp:float=30.0

@export_group("Wall Bounce")
@export var bounce_min_speed:float=6.0;      @export var bounce_restitution:float=0.55
@export var bounce_up_factor:float=0.22;     @export var bounce_dot_threshold:float=0.25

@export_group("Drift")
@export var drift_traction:float=0.40; @export var drift_threshold:float=75.0
@export var drift_min_speed:float=8.0

@export_group("Vertical")
@export var jump_velocity:float=10.0;  @export var gravity_rise:float=28.0
@export var gravity_fall:float=40.0;   @export var max_fall_speed:float=55.0
@export var fall_damage_spd:float=22.0; @export var coyote_time:float=0.10
@export var jump_buffer_t:float=0.12

@export_group("Tilt")
@export var tilt_max:float=18.0; @export var tilt_ref_speed:float=40.0; @export var tilt_smooth:float=10.0

# How much extra tilt is added from raw A/D input on top of velocity-based tilt
@export_group("Input Tilt")
@export var input_tilt_max:float=8.0
@export var input_tilt_smooth:float=6.0

@export_group("Slide")
@export var slide_min_speed:float=6.0;   @export var slide_friction:float=4.0
@export var slide_slope_boost:float=18.0; @export var slide_max_speed:float=60.0
@export var slide_steer_start:float=30.0; @export var slide_steer_min:float=0.08
@export var slide_crouch:float=0.55

@export_group("Impulse")
@export var dash_force:float=22.0; @export var dash_cooldown:float=0.6
@export var knockback_decay:float=18.0

@export_group("Environment")
@export var drag_coefficient:float=0.008; @export var wind:=Vector3.ZERO
@export var gravity_scale:float=1.0

@export_group("Damage")
@export var damage_control:float=0.55; @export var damage_speed_cap:float=0.70

@export_group("Assists")
@export var corner_assist_str:float=0.30; @export var ground_magnet:float=6.0

@export_group("Reversal")
@export var reversal_bleed:float=0.55
@export var reversal_threshold:float=145.0

# How long (seconds) the brake phase lasts on a sharp direction flip
@export_group("Direction Change")
@export var dir_brake_time:float=0.18
# Speed must be above this to trigger a brake phase
@export var dir_brake_min_speed:float=5.0
# Angle (degrees) that counts as a direction flip (A→D style, less than reversal)
@export var dir_flip_threshold:float=100.0
# How hard speed is bled during the brake phase (0=none, 1=instant stop)
@export var dir_brake_bleed:float=0.92

# Wall slam detection and curved bounce
@export_group("Wall Slam")
# Deceleration (units/s²) spike that counts as a slam — tune this high enough
# that normal cornering doesn't trigger it (~400–800 is a good starting range)
@export var wall_slam_threshold:float=500.0
# Upward kick on slam bounce
@export var slam_bounce_up:float=0.18
# How long the curved arc after a wall slam lasts
@export var wall_bounce_curve_time:float=0.35
# Lateral curve strength — positive curves right relative to reflected dir
@export var wall_bounce_curve_str:float=18.0

@export_group("Nodes")
@export var camera_path:NodePath=^"CameraController/Camera3D"
@export var mesh_path:NodePath=^"MeshInstance3D"

signal speed_changed(flat_speed:float,max_speed:float)
signal debug_stats(momentum:float,speed:float,stopping_force:float)
signal turn_strain(strain:float)
signal state_changed(new_state:int)
signal height_changed(world_y:float)
signal landed(impact_speed:float)
signal dash_performed()
signal wall_hit(wall_normal:Vector3,impact_speed:float)
signal food_consumed(food_name:String)

var _state:=State.IDLE; var _state_time:float; var _max_spd:float
var _coyote:float; var _buf:float; var _dash_cd:float; var _bounce_cd:float
var _impulse:=Vector3.ZERO; var _air_vel_y:float
var _damaged:bool; var _drifting:bool; var _prev_spd:float
var _surf_friction:=1.0; var _surf_accel:=1.0; var _surf_drag:=1.0; var _surf_gravity:=1.0
var _slide_h:float=1.8; var _slide_oy:float; var _capsule_h:float=1.8
var _camera:Camera3D; var _mesh:Node3D; var _col:CollisionShape3D

# Input tilt accumulator (separate from velocity tilt so they stack)
var _input_tilt:float=0.0

# Direction-change brake phase
var _brake_timer:float=0.0          # counts down while braking
var _brake_target_dir:=Vector3.ZERO # direction we're braking toward

# Wall slam curved bounce
var _slam_curve_timer:float=0.0
var _slam_curve_axis:=Vector3.ZERO  # lateral axis to curve around
var _prev_flat_vel:=Vector3.ZERO    # flat velocity from last frame for decel detection

# Food inventory system
var food_inventory: Dictionary = {}  # { food_name: count }
var total_food_consumed: int = 0


func _ready()->void:
	_max_spd=speed_min; _camera=get_node(camera_path)
	if has_node(mesh_path): _mesh=get_node(mesh_path)
	for c in get_children():
		if c is CollisionShape3D:
			_col=c
			if _col.shape is CapsuleShape3D:
				var cap:=_col.shape as CapsuleShape3D
				_slide_h=cap.height; _slide_oy=_col.position.y; _capsule_h=_slide_h
			break
	
	# Add player to "player" group so FoodItem can detect it
	add_to_group("player")
	
	# Connect to GameEvents food consumption signal
	GameEvents.player_consumed_food.connect(_on_food_consumed)


func _physics_process(d:float)->void:
	_bounce_cd=maxf(_bounce_cd-d,0.0); _dash_cd=maxf(_dash_cd-d,0.0); _buf=maxf(_buf-d,0.0)
	if Input.is_action_just_pressed("jump"): _buf=jump_buffer_t
	if is_on_floor(): _coyote=coyote_time
	else:             _coyote=maxf(_coyote-d,0.0)
	_apply_gravity(d)
	_impulse=_impulse.move_toward(Vector3.ZERO,knockback_decay*d)

	# Tick slam curve
	if _slam_curve_timer>0.0:
		_slam_curve_timer=maxf(_slam_curve_timer-d,0.0)
		var fv:=Vector3(velocity.x,0,velocity.z)
		var curve_t:=_slam_curve_timer/wall_bounce_curve_time
		fv=fv.rotated(Vector3.UP,deg_to_rad(wall_bounce_curve_str)*curve_t*d)
		velocity.x=fv.x; velocity.z=fv.z

	_run_sm(d)
	velocity+=(_impulse+wind)*d
	velocity-=velocity.normalized()*drag_coefficient*_surf_drag*velocity.length_squared()*d

	# Store flat vel BEFORE move_and_slide for decel spike detection
	var pre_slide_flat:=Vector3(velocity.x,0,velocity.z)
	move_and_slide()
	_check_wall_bounce()

	# Wall slam detection: huge sudden deceleration spike
	var post_flat:=Vector3(velocity.x,0,velocity.z)
	var decel_spike:=(pre_slide_flat.length()-post_flat.length())/maxf(d,0.0001)
	if decel_spike>wall_slam_threshold and _bounce_cd<=0.0 and pre_slide_flat.length()>bounce_min_speed:
		_trigger_slam_bounce(pre_slide_flat, d)

	_prev_flat_vel=post_flat

	if is_on_floor() and _state==State.AIR:
		var impact:=absf(_air_vel_y)
		if impact>fall_damage_spd: landed.emit(impact)
	_air_vel_y=velocity.y if not is_on_floor() else 0.0

	# Tilt: stack velocity-based tilt + input-based tilt
	if _mesh:
		var fv:=Vector3(velocity.x,0,velocity.z)
		var lat:=fv.dot(_mesh.global_transform.basis.x)
		var rat:=clampf(fv.length()/tilt_ref_speed,0.0,1.0)
		var vel_tz:=clampf(-sign(lat)*absf(lat)/maxf(fv.length(),0.01)*deg_to_rad(tilt_max)*rat,
			-deg_to_rad(tilt_max),deg_to_rad(tilt_max))

		# Raw A/D input tilt — stacks on top of vel tilt
		var raw:=Input.get_vector("move_left","move_right","move_forward","move_back")
		var target_input_tilt:=deg_to_rad(input_tilt_max)*raw.x
		_input_tilt=lerpf(_input_tilt,target_input_tilt,input_tilt_smooth*d)

		_mesh.rotation.z=lerpf(_mesh.rotation.z,vel_tz+_input_tilt,tilt_smooth*d)

	var fs:=_flat_spd()
	speed_changed.emit(fs,_max_spd)
	debug_stats.emit(fs,fs,maxf((_prev_spd-fs)/maxf(d,0.0001),0.0))
	height_changed.emit(global_position.y); _prev_spd=fs
	
	# Update HeatManager with current speed
	HeatManager.update_speed(fs)


func _trigger_slam_bounce(pre_vel:Vector3, _d:float)->void:
	# Reflect off the wall (approximate normal from velocity reversal)
	var flat:=pre_vel
	var post:=Vector3(velocity.x,0,velocity.z)
	# Use the difference to infer the wall normal
	var delta:=post-flat
	var wall_normal:=delta.normalized() if delta.length()>0.01 else -flat.normalized()
	var reflected:=(flat-2.0*flat.dot(wall_normal)*wall_normal).normalized()
	var bounce_spd:=flat.length()*bounce_restitution
	velocity.x=reflected.x*bounce_spd
	velocity.z=reflected.z*bounce_spd
	velocity.y=maxf(velocity.y,bounce_spd*slam_bounce_up)

	# Set up the curved arc — rotate around Y axis
	_slam_curve_timer=wall_bounce_curve_time
	# Curve direction: cross of reflected dir and up gives the lateral axis
	_slam_curve_axis=reflected.cross(Vector3.UP).normalized()
	_bounce_cd=0.25


func _run_sm(d:float)->void:
	_state_time+=d; var nx:=_state
	match _state:
		State.IDLE:  nx=_idle(d)
		State.RUN:   nx=_run(d)
		State.AIR:   nx=_air(d)
		State.SLIDE: nx=_slide_st(d)
		State.ARC:   nx=_arc(d)
	if nx!=_state:
		if _state==State.SLIDE or nx!=State.SLIDE: _restore_shape()
		if nx==State.SLIDE: _crouch_shape()
		_state=nx; _state_time=0.0; state_changed.emit(nx as int)


func _idle(d:float)->State:
	_horiz(d)
	if not is_on_floor():                return State.AIR
	if _jump():                          return State.AIR
	if _slide_ok():                      return State.SLIDE
	if _flat_spd()>0.5 and _has_in():   return State.RUN
	return State.IDLE

func _run(d:float)->State:
	_horiz(d)
	if not is_on_floor():                        return State.AIR
	if _jump():                                  return State.AIR
	if _slide_ok():                              return State.SLIDE
	var ang:=_ang_to_wish()
	if ang>arc_threshold and ang<reversal_threshold and _flat_spd()>speed_min: return State.ARC
	if _flat_spd()<0.5:                          return State.IDLE
	return State.RUN

func _air(d:float)->State:
	_horiz(d)
	if Input.is_action_just_released("jump") and velocity.y>0.0: velocity.y*=0.45
	if is_on_floor(): return State.RUN if _flat_spd()>0.5 else State.IDLE
	return State.AIR

func _slide_st(d:float)->State:
	if not is_on_floor():                         return State.SLIDE
	if _slide_phys(d):                            return State.IDLE
	if Input.is_action_just_released("slide"):    return State.RUN if _flat_spd()>0.5 else State.IDLE
	if _jump():                                   return State.AIR
	return State.SLIDE

func _arc(d:float)->State:
	if not _arc_move(d): return State.RUN if _flat_spd()>0.5 else State.IDLE
	if not is_on_floor(): return State.AIR
	if _jump():           return State.AIR
	if _slide_ok():       return State.SLIDE
	return State.ARC


func _apply_gravity(d:float)->void:
	if is_on_floor() and _state!=State.SLIDE: return
	if _state==State.SLIDE and is_on_floor(): velocity.y=0.0; return
	var g:=(gravity_fall if velocity.y<0.0 else gravity_rise)*gravity_scale*_surf_gravity
	if not is_on_floor() and velocity.y<0.0:
		g+=ground_magnet*clampf(-get_floor_normal().y,0.0,1.0)
	velocity.y=maxf(velocity.y-g*d,-max_fall_speed)


func _horiz(d:float)->float:
	var wish:=_wish_dir(); var flat:=Vector3(velocity.x,0,velocity.z)
	var spd:=flat.length(); var eff_a:=acceleration*_surf_accel/mass
	var eff_f:=friction*_surf_friction
	var spd_cap:=speed_max*(damage_speed_cap if _damaged else 1.0)
	_max_spd=minf(_max_spd+speed_ramp_rate*d,spd_cap) if (_has_in() and is_on_floor()) \
		else maxf(_max_spd-speed_ramp_decay*d,speed_min)
	var mom_t:=clampf((spd-speed_min)/maxf(momentum_full_speed-speed_min,0.01),0.0,1.0)
	var resist:=lerpf(0.0,momentum_resistance,mom_t*mom_t)

	if wish.length_squared()<0.01:
		flat=flat.move_toward(Vector3.ZERO,(eff_f if is_on_floor() else air_control)*lerpf(1.0,momentum_bleed,resist)*d)
		velocity.x=flat.x; velocity.z=flat.z; turn_strain.emit(0.0); _drifting=false
		_brake_timer=0.0; return 0.0

	if spd<2.0:
		flat=flat.move_toward(wish*spd_cap,eff_a*d)
		velocity.x=flat.x; velocity.z=flat.z; turn_strain.emit(0.0)
		_brake_timer=0.0; return 0.0

	var ang:=rad_to_deg(flat.normalized().angle_to(wish))
	var spd_t:=clampf(spd/speed_max,0.0,1.0)
	var ctrl:=lerpf(1.0,0.55,spd_t*spd_t)*(damage_control if _damaged else 1.0)
	var eff_steer:=eff_a*ctrl*lerpf(1.0,1.0-resist,mom_t)

	# --- Direction-change brake phase (A→D / W→D style flips) ---
	# Enter brake if angle is a hard flip but not quite a full reversal
	if ang>=dir_flip_threshold and ang<reversal_threshold and is_on_floor() \
			and spd>=dir_brake_min_speed and _brake_timer<=0.0:
		_brake_timer=dir_brake_time
		_brake_target_dir=wish

	if _brake_timer>0.0:
		_brake_timer=maxf(_brake_timer-d,0.0)
		# Bleed speed strongly during brake window
		flat*=pow(1.0-dir_brake_bleed,d*60.0)
		# Once nearly stopped, point in new direction and let normal accel take over
		if flat.length()<1.5 or _brake_timer<=0.0:
			_brake_timer=0.0
			flat=flat.move_toward(wish*spd_cap,eff_a*2.0*d)
		velocity.x=flat.x; velocity.z=flat.z
		turn_strain.emit(clampf(ang/180.0,0.0,1.0)*0.6); return 0.0

	# Natural reversal (beyond reversal_threshold): bleed + redirect
	if ang>=reversal_threshold and is_on_floor():
		var rev_t:=clampf((ang-reversal_threshold)/(180.0-reversal_threshold),0.0,1.0)
		flat*=lerpf(1.0,1.0-reversal_bleed,rev_t*spd_t)*pow(1.0-reversal_bleed*0.4,d*60.0*rev_t)
		flat=flat.move_toward(wish*spd_cap,eff_a*ctrl*(1.0+rev_t)*d)
		velocity.x=flat.x; velocity.z=flat.z
		turn_strain.emit(clampf(rev_t*0.5,0.0,1.0)); return 0.0

	if ang>15.0 and ang<arc_threshold:
		flat=flat.normalized().slerp(wish,corner_assist_str*d*ctrl*lerpf(1.0,1.0-resist,mom_t))*spd
	_drifting=spd>=drift_min_speed and ang>=drift_threshold
	if _drifting:
		var trac:=lerpf(drift_traction,1.0,1.0-clampf((ang-drift_threshold)/90.0,0.0,1.0))
		flat=flat.lerp(wish*spd,trac*d*3.0*lerpf(1.0,1.0-resist*0.6,mom_t))
		velocity.x=flat.x; velocity.z=flat.z
		var drift_strain:=clampf((ang-drift_threshold)/90.0,0.0,1.0)*0.7; turn_strain.emit(drift_strain); return drift_strain
	if ang>arc_threshold and is_on_floor():
		var arc_strain:=clampf((ang-arc_threshold)/(180.0-arc_threshold),0.0,1.0); turn_strain.emit(arc_strain); return arc_strain
	flat=flat.move_toward(wish*spd_cap,eff_steer*(turn_boost if flat.dot(wish)<0.0 else 1.0)*d)
	velocity.x=flat.x; velocity.z=flat.z
	turn_strain.emit(clampf(ang/arc_threshold,0.0,1.0)*0.25); return 0.0


func _arc_move(d:float)->bool:
	var wish:=_wish_dir(); var flat:=Vector3(velocity.x,0,velocity.z); var spd:=flat.length()
	if wish.length_squared()<0.01 or spd<2.0:
		flat=flat.move_toward(Vector3.ZERO,friction*d)
		velocity.x=flat.x; velocity.z=flat.z; turn_strain.emit(0.0); return false
	var cur:=flat.normalized(); var ang:=rad_to_deg(cur.angle_to(wish))
	if ang<=arc_threshold:
		flat=flat.move_toward(wish*_max_spd,acceleration*d)
		velocity.x=flat.x; velocity.z=flat.z; turn_strain.emit(0.0); return false
	var str:=clampf((ang-arc_threshold)/(180.0-arc_threshold),0.0,1.0)
	var brake_t:=clampf((ang-arc_threshold)/maxf(corner_brake_ramp,1.0),0.0,1.0)
	var new_spd:=maxf(spd*pow(corner_speed_bleed,brake_t*d),corner_min_speed)
	var steer_cap:=lerpf(1.0,0.25,brake_t*clampf(spd/speed_max,0.0,1.0))
	var rot:=clampf(cur.signed_angle_to(wish,Vector3.UP),
		-deg_to_rad(arc_turn_rate)*d*steer_cap, deg_to_rad(arc_turn_rate)*d*steer_cap)
	var drag:=lerpf(1.0,arc_speed_drag,str*d*5.0)
	var new_dir:=cur.rotated(Vector3.UP,rot)
	velocity.x=new_dir.x*new_spd*drag; velocity.z=new_dir.z*new_spd*drag
	turn_strain.emit(str); return true


func _slide_phys(d:float)->bool:
	var fn:=get_floor_normal(); var slope:=1.0-fn.y
	var fv:=Vector3(velocity.x,0,velocity.z); var fspd:=fv.length()
	var tt:=clampf((fspd-slide_steer_start)/(slide_max_speed-slide_steer_start),0.0,1.0)
	var steer:=lerpf(1.0,slide_steer_min,tt*tt)
	var raw:=Input.get_vector("move_left","move_right","move_forward","move_back")
	if raw.length_squared()>0.01 and fspd>0.5:
		var cb:=_camera.global_transform.basis
		var wd:=((-cb.z*Vector3(1,0,1)).normalized()*-raw.y+(cb.x*Vector3(1,0,1)).normalized()*raw.x).normalized()
		fv=fv.move_toward(wd*fspd,acceleration*0.35*steer*_surf_accel*d)
	if slope>0.02:
		fv+=-Vector3(fn.x,0,fn.z).normalized()*slope*slide_slope_boost*d
		if fv.length()>slide_max_speed: fv=fv.normalized()*slide_max_speed
	else:
		fv=fv.move_toward(Vector3.ZERO,slide_friction*_surf_friction*d)
		if fv.length()<1.5: return true
	velocity.x=fv.x; velocity.z=fv.z; velocity.y=0.0; return false


func _check_wall_bounce()->void:
	if _bounce_cd>0.0 or _flat_spd()<bounce_min_speed: return
	for i in get_slide_collision_count():
		var col:=get_slide_collision(i); var normal:=col.get_normal()
		if absf(normal.y)>0.65: continue
		var fv:=Vector3(velocity.x,0,velocity.z)
		if -fv.normalized().dot(normal)<bounce_dot_threshold: continue
		if col.get_position().y-global_position.y<0.32: continue
		var spd:=fv.length()
		var ref:=(fv-2.0*fv.dot(normal)*normal).normalized()*spd*bounce_restitution
		velocity.x=ref.x; velocity.z=ref.z
		velocity.y=0.0 if velocity.y>0.0 else clampf(spd*bounce_up_factor,0.0,jump_velocity*1.4)
		_bounce_cd=0.18; wall_hit.emit(normal,spd)
		if _state!=State.AIR: _transition_to(State.AIR); break


func _transition_to(nx:State)->void:
	if _state==State.SLIDE or nx!=State.SLIDE: _restore_shape()
	if nx==State.SLIDE: _crouch_shape()
	_state=nx; _state_time=0.0; state_changed.emit(nx as int)


func _jump()->bool:
	if _buf>0.0 and _coyote>0.0:
		velocity.y=jump_velocity; _coyote=0.0; _buf=0.0; return true
	return false

func _slide_ok()->bool:
	return Input.is_action_just_pressed("slide") and _flat_spd()>=slide_min_speed

func _wish_dir()->Vector3:
	var r:=Input.get_vector("move_left","move_right","move_forward","move_back")
	if r.length_squared()<0.01: return Vector3.ZERO
	if _camera==null: return Vector3.ZERO
	var cb:=_camera.global_transform.basis
	return ((-cb.z*Vector3(1,0,1)).normalized()*-r.y+(cb.x*Vector3(1,0,1)).normalized()*r.x).normalized()

func _ang_to_wish()->float:
	var f:=Vector3(velocity.x,0,velocity.z); var w:=_wish_dir()
	return rad_to_deg(f.normalized().angle_to(w)) if f.length()>0.01 and w.length_squared()>0.01 else 0.0

func _flat_spd()->float: return Vector3(velocity.x,0,velocity.z).length()
func _has_in()->bool: return Input.get_vector("move_left","move_right","move_forward","move_back").length()>0.1

func _crouch_shape()->void:
	if _col==null or not (_col.shape is CapsuleShape3D): return
	var c:=_col.shape as CapsuleShape3D; c.height=_slide_h*slide_crouch
	_col.position.y=(_slide_oy-_slide_h*0.5)+c.height*0.5
	if _mesh: _mesh.scale.y=slide_crouch

func _restore_shape()->void:
	if _col==null or not (_col.shape is CapsuleShape3D): return
	(_col.shape as CapsuleShape3D).height=_slide_h; _col.position.y=_slide_oy
	if _mesh: _mesh.scale.y=1.0


func set_surface(data:Dictionary,entering:bool)->void:
	_surf_friction=data.get("friction",1.0) if entering else 1.0
	_surf_accel=data.get("accel",1.0)       if entering else 1.0
	_surf_drag=data.get("drag",1.0)         if entering else 1.0
	_surf_gravity=data.get("gravity",1.0)   if entering else 1.0

func add_impulse(force:Vector3)->void: _impulse+=force

func try_dash()->void:
	if _dash_cd>0.0: return
	add_impulse(_wish_dir()*dash_force/mass); _dash_cd=dash_cooldown; dash_performed.emit()

func set_damaged(v:bool)->void:        _damaged=v
func get_state()->int:                 return _state as int
func get_state_time()->float:          return _state_time
func get_flat_speed()->float:          return _flat_spd()
func is_sliding_state()->bool:         return _state==State.SLIDE
func is_in_momentum_arc()->bool:       return _state==State.ARC
func is_drifting()->bool:              return _drifting


# Food consumption
func _on_food_consumed(food_name: String)->void:
	"""Called when the player consumes food via collision with FoodItem"""
	# Add to inventory
	if food_name not in food_inventory:
		food_inventory[food_name] = 0
	food_inventory[food_name] += 1
	total_food_consumed += 1
	
	# Emit signal for other systems to react
	food_consumed.emit(food_name)
	
	# Log for debugging
	print("Player consumed food: %s (Total: %d)" % [food_name, total_food_consumed])


func get_food_count(food_name: String)->int:
	"""Get count of a specific food item"""
	return food_inventory.get(food_name, 0)


func get_total_food_consumed()->int:
	"""Get total number of food items consumed"""
	return total_food_consumed


func get_food_inventory()->Dictionary:
	"""Get a copy of the entire food inventory"""
	return food_inventory.duplicate()
