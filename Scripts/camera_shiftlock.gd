extends Node3D

@export_group("Mouse")
@export var sensitivity_x:float=0.20; @export var sensitivity_y:float=0.18
@export var max_yaw_delta_deg:float=6.0

@export_group("Vertical")
@export var pitch_min:float=-70.0; @export var pitch_max:float=60.0

@export_group("Orbital Arm")
@export var arm_length:float=6.0;    @export var pivot_height_offset:float=1.6
@export var arm_min:float=1.5;       @export var arm_max:float=14.0
@export var arm_zoom_smooth:float=10.0; @export var arm_speed_pullback:float=2.5
@export var arm_lookahead:float=1.8
@export var pitch_ground_factor:float=0.55

@export_group("Shoulder")
@export var shoulder_base:float=2.2
@export var shoulder_lean_sweep:float=2.80
@export var shoulder_turn_shift:float=1.2
@export var shoulder_smooth:float=6.0
@export var shoulder_y_drop_max:float=0.80

@export_group("Spring Damper")
@export var spring_h:float=14.0; @export var spring_v:float=8.0
@export var lag_yaw_factor:float=0.08

@export_group("Speed Resistance")
@export var resistance_start:float=8.0; @export var resistance_max:float=40.0
@export var min_turn_ratio:float=0.15

@export_group("Auto Recentre")
@export var recentre_delay:float=2.0; @export var recentre_speed:float=2.5

@export_group("FOV")
@export var fov_base:float=75.0; @export var fov_max:float=100.0; @export var fov_smooth:float=6.0

@export_group("Lean")
@export var roll_max_deg:float=22.0;   @export var roll_smooth:float=5.5
@export var roll_buildup_rate:float=3.0; @export var roll_drain_rate:float=4.5
@export var moto_pitch_max:float=35.0; @export var moto_pitch_rate:float=5.0
@export var lean_arm_pull:float=1.8

@export_group("Vertical Feel")
@export var fall_pitch_bias:float=6.0; @export var fall_pitch_speed:float=10.0
@export var land_pitch_kick:float=4.0

@export_group("Running Shake")
@export var run_shake_max:float=0.55;  @export var run_shake_speed:float=40.0
@export var run_shake_freq:float=9.0;  @export var topspeed_shake_bonus:float=0.40

@export_group("Impact Shake")
@export var shake_max_deg:float=3.5;   @export var shake_idle_floor:float=0.08
@export var shake_frequency:float=26.0; @export var shake_attack:float=18.0
@export var shake_decay:float=10.0;    @export var shake_full_yaw_rate:float=3.5
@export var impact_shake_deg:float=3.8; @export var impact_decay:float=16.0

@export_group("Wall Hit")
@export var wall_hit_trauma:float=5.0; @export var wall_pitch_kick:float=3.5

@export_group("Knockback Feel")
@export var knockback_arm_push:float=0.8    # Extra arm pullback during knockback (units)
@export var knockback_pitch_kick:float=3.5  # Downward pitch nudge on hit (degrees)
@export var knockback_decay_speed:float=4.5 # How fast the knockback offset fades out

@export_group("Collision")
@export var collision_enabled:bool=true; @export var collision_radius:float=0.2

@export_group("Speed Lines")
@export var lines_start_speed:float=8.0; @export var lines_max_speed:float=28.0
@export var line_count:int=52; @export var line_color:Color=Color(1,1,1,0.85)

@export_group("Follow")
@export var character_path:NodePath=^".."

# ── State ─────────────────────────────────────────────────────────────────────
var _cam_yaw:float; var _char_yaw:float; var _pitch:float
var _smooth_yaw:float; var _smooth_pitch:float
var _arm_target:float; var _arm_current:float; var _shoulder_cur:float
var _freelook_active:bool; var _current_speed:float; var _max_spd:float=40.0
var _vert_vel:float
var _shake_target:float; var _shake_smooth:float; var _shake_time:float
var _impact_trauma:float; var _prev_strain:float
var _yaw_delta:float; var _turn_dir:float; var _run_shake_time:float
var _recentre_timer:float
var _lean_roll:float; var _lean_pitch:float
var _lateral_input:float; var _extra_pitch:float
var _character:CharacterBody3D; var _camera:Camera3D
var _line_ctrl:_SpeedLineControl; var _space:PhysicsDirectSpaceState3D
var _knockback_trauma:float=0.0   # Smooth knockback camera offset [0..1]


func _ready() -> void:
	_character=get_node(character_path); _camera=$Camera3D
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_cam_yaw=rad_to_deg(_character.rotation.y)
	_char_yaw=_cam_yaw; _smooth_yaw=_cam_yaw; _smooth_pitch=_pitch
	_arm_target=arm_length; _arm_current=arm_length; _shoulder_cur=shoulder_base
	_apply_orbital_transform(); _build_speed_lines()
	for sig in [["speed_changed",_on_speed_changed],["turn_strain",_on_turn_strain],
				["landed",_on_landed],["dash_performed",_on_dash],["dash_attack_performed",_on_dash_attack],["wall_hit",_on_wall_hit],
				["knockback_received",_on_knockback_received]]:
		if _character.has_signal(sig[0]): _character.connect(sig[0],sig[1])


func _on_speed_changed(flat:float,mx:float)->void: _current_speed=flat; _max_spd=mx

func _on_turn_strain(strain:float)->void:
	if strain>0.55 and _prev_strain<0.35:
		_impact_trauma=maxf(_impact_trauma,impact_shake_deg*strain)
	_prev_strain=strain
	var yr:=clampf(absf(_yaw_delta)/maxf(shake_full_yaw_rate,0.001),0.0,1.0)
	_shake_target=clampf(shake_idle_floor*strain+strain*yr*yr,0.0,1.0)

func _on_landed(impact:float)->void:
	_impact_trauma=maxf(_impact_trauma,impact_shake_deg*clampf(impact/30.0,0.0,1.0))
	_extra_pitch+=land_pitch_kick

func _on_dash()->void: _impact_trauma=maxf(_impact_trauma,impact_shake_deg*0.4)

func _on_dash_attack()->void:
	"""Handle dash attack performed signal - triggers camera shake and FOV effect"""
	_impact_trauma=maxf(_impact_trauma,impact_shake_deg*1.2)

func _on_wall_hit(_wall_normal:Vector3,impact_speed:float)->void:
	var t:=clampf(impact_speed/maxf(_max_spd,1.0),0.0,1.0)
	_impact_trauma=maxf(_impact_trauma,wall_hit_trauma*t); _extra_pitch+=wall_pitch_kick*t

func _on_knockback_received(strength:float)->void:
	# strength is 0..1 normalised by the caller; nudge arm and pitch smoothly
	var t:=clampf(strength,0.0,1.0)
	_knockback_trauma=maxf(_knockback_trauma,t)
	_extra_pitch+=knockback_pitch_kick*t


func _input(event:InputEvent)->void:
	if event.is_action_pressed("freelook"):   _freelook_active=true
	if event.is_action_released("freelook"):  _freelook_active=false; _cam_yaw=_char_yaw
	if event is InputEventMouseMotion:
		var h:=sensitivity_x
		if not _freelook_active:
			var t:=clampf((_current_speed-resistance_start)/(resistance_max-resistance_start),0.0,1.0)
			h*=lerpf(1.0,min_turn_ratio,t*t)
		var raw:=clampf(-event.relative.x*h,-max_yaw_delta_deg,max_yaw_delta_deg)
		_cam_yaw+=raw
		if not _freelook_active: _char_yaw+=raw
		_yaw_delta+=absf(raw)
		if absf(raw)>0.001: _turn_dir=sign(raw)
		_pitch=clampf(_pitch+event.relative.y*sensitivity_y,pitch_min,pitch_max)
		_recentre_timer=0.0
	if event is InputEventMouseButton and event.pressed:
		if   event.button_index==MOUSE_BUTTON_WHEEL_UP:   _arm_target=clampf(_arm_target-0.8,arm_min,arm_max)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: _arm_target=clampf(_arm_target+0.8,arm_min,arm_max)


func _process(delta:float)->void:
	_space=get_world_3d().direct_space_state; _vert_vel=_character.velocity.y
	var raw_in:=Input.get_vector("move_left","move_right","move_forward","move_back")
	_lateral_input=lerpf(_lateral_input,raw_in.x,12.0*delta)

	_recentre_timer+=delta
	if not _freelook_active and _recentre_timer>recentre_delay:
		var diff:=wrapf(_char_yaw-_cam_yaw,-180.0,180.0)
		_cam_yaw=lerpf(_cam_yaw,_cam_yaw+diff,recentre_speed*delta); _char_yaw=_cam_yaw

	var spd_t:=clampf(_current_speed/_max_spd,0.0,1.0)
	_smooth_yaw=lerpf(_smooth_yaw,_cam_yaw,spring_h/(1.0+absf(_yaw_delta)*lag_yaw_factor*spd_t)*delta)
	_smooth_pitch=lerpf(_smooth_pitch,_pitch,spring_v*delta)

	_knockback_trauma=lerpf(_knockback_trauma,0.0,knockback_decay_speed*delta)
	var knockback_arm_offset:=_knockback_trauma*knockback_arm_push

	var lean_t:=clampf(absf(_lean_roll)/roll_max_deg,0.0,1.0)
	_arm_current=lerpf(_arm_current,
		clampf(_arm_target+arm_speed_pullback*spd_t*spd_t-lean_t*lean_t*lean_arm_pull+knockback_arm_offset,arm_min,arm_max+arm_speed_pullback),
		arm_zoom_smooth*delta)

	# Shoulder: right by default; mouse turns, lateral input and lean all drive the sweep.
	# Turning right pushes further right and lowers Y; turning left sweeps toward center/left.
	var lean_signed:=clampf(_lean_roll/maxf(roll_max_deg,0.001),-1.0,1.0)
	var lateral_signed:=clampf(_lateral_input,-1.0,1.0)
	var yaw_signed:=clampf(_yaw_delta/maxf(max_yaw_delta_deg,0.001)*_turn_dir,-1.0,1.0)
	var sweep_driver:=clampf(lean_signed*0.4+lateral_signed*0.35+yaw_signed*0.55,-1.0,1.0)
	_shoulder_cur=lerpf(_shoulder_cur,
		shoulder_base+sweep_driver*shoulder_lean_sweep+_turn_dir*shoulder_turn_shift*_prev_strain,
		shoulder_smooth*delta)

	# Lean
	var fwd_blend:=clampf(-raw_in.y,0.0,1.0)
	var lean_intent:=clampf(
		_lateral_input*fwd_blend*0.5 +
		_turn_dir*clampf(absf(_yaw_delta)/maxf(max_yaw_delta_deg,0.01),0.0,1.0)*0.8 +
		_turn_dir*_prev_strain*1.2,-1.0,1.0)
	var roll_target:=lean_intent*roll_max_deg*lerpf(0.25,1.0,spd_t)
	_lean_roll=lerpf(_lean_roll,roll_target,
		(roll_buildup_rate if absf(roll_target)>absf(_lean_roll) else roll_drain_rate)*delta)

	var ln:=absf(_lean_roll)/maxf(roll_max_deg,0.001)
	_lean_pitch=lerpf(_lean_pitch,ln*ln*moto_pitch_max*spd_t,moto_pitch_rate*delta)
	_extra_pitch=lerpf(_extra_pitch,0.0,8.0*delta)

	var fall_bias:=clampf((-_vert_vel-fall_pitch_speed)/20.0,0.0,1.0)*fall_pitch_bias
	_apply_orbital_transform(
		_compute_impact_shake(delta)+_compute_run_shake(delta,spd_t),
		fall_bias+_extra_pitch+_lean_pitch,
		spd_t)

	if not _freelook_active:
		_character.global_transform.basis=_character.global_transform.basis.slerp(
			Basis(Vector3.UP,deg_to_rad(_char_yaw)),minf(delta*20.0,1.0))
	_yaw_delta=0.0
	_camera.fov=lerpf(_camera.fov,lerpf(fov_base,fov_max,spd_t*spd_t),fov_smooth*delta)
	_line_ctrl.set_intensity(clampf((_current_speed-lines_start_speed)/(lines_max_speed-lines_start_speed),0.0,1.0)**3)


func _apply_orbital_transform(shake:Vector2=Vector2.ZERO, extra_pitch:float=0.0, spd_t:float=0.0)->void:
	var char_pos:=_character.global_position+Vector3(0,pivot_height_offset,0)
	global_position=char_pos
	rotation_degrees=Vector3(0,_smooth_yaw+shake.x,0)
	var pr:=deg_to_rad(_smooth_pitch+shake.y+extra_pitch)
	var pitch_t:=clampf((-(_smooth_pitch+extra_pitch)-20.0)/maxf(-pitch_min-20.0,1.0),0.0,1.0)
	var ground_drop:=pitch_t*pitch_t*pitch_ground_factor*_arm_current

	# Y drops as shoulder moves rightward; visible even at idle (floor 0.55 not 0.0)
	var shoulder_t:=clampf(_shoulder_cur/maxf(shoulder_base+shoulder_lean_sweep,0.001),0.0,1.5)
	var shoulder_y_drop:=shoulder_t*shoulder_t*shoulder_y_drop_max*lerpf(0.55,1.0,spd_t)

	var arm:=Vector3(_shoulder_cur, sin(pr)*_arm_current - ground_drop - shoulder_y_drop, cos(pr)*_arm_current)
	var fwd:=-global_transform.basis.z*Vector3(1,0,1)
	if fwd.length_squared()>0.01:
		global_position+=fwd.normalized()*arm_lookahead*spd_t*spd_t
	if collision_enabled and _space!=null:
		var p:=PhysicsRayQueryParameters3D.new()
		p.from=char_pos; p.to=global_transform*arm
		p.exclude=[_character.get_rid()]; p.collision_mask=1
		var hit:=_space.intersect_ray(p)
		if hit:
			arm=arm.normalized()*maxf(char_pos.distance_to(hit.position)-collision_radius,collision_radius)
	_camera.position=arm; _camera.look_at(global_position,Vector3.UP)
	_camera.rotation_degrees.z=_lean_roll


func _compute_impact_shake(delta:float)->Vector2:
	_shake_smooth=lerpf(_shake_smooth,_shake_target,
		(shake_attack if _shake_target>_shake_smooth else shake_decay)*delta)
	_impact_trauma=maxf(_impact_trauma-impact_decay*delta,0.0)
	var total:=clampf(_shake_smooth+_impact_trauma/maxf(shake_max_deg,0.001),0.0,1.0)
	if total<0.004: return Vector2.ZERO
	_shake_time+=delta*shake_frequency
	var t:=_shake_time
	var nx:=sin(t)*0.5+sin(t*2.3+1.1)*0.3+sin(t*5.1+2.7)*0.2
	var ny:=sin(t+0.8)*0.5+sin(t*2.7+3.2)*0.3+sin(t*4.9+0.5)*0.2
	var mag:=shake_max_deg*(total*total)
	return Vector2(nx*mag,ny*mag*0.55)


func _compute_run_shake(delta:float,spd_t:float)->Vector2:
	if _current_speed<1.0: return Vector2.ZERO
	_run_shake_time+=delta*run_shake_freq*lerpf(0.6,1.0,spd_t)
	var amp:=clampf(_current_speed/run_shake_speed,0.0,1.0)*run_shake_max \
		+clampf((spd_t-0.85)/0.15,0.0,1.0)*topspeed_shake_bonus*run_shake_max
	return Vector2(sin(_run_shake_time*0.5+0.8)*amp*0.3,sin(_run_shake_time)*amp*0.6)


func _build_speed_lines()->void:
	var c:=CanvasLayer.new(); c.layer=10; add_child(c)
	_line_ctrl=_SpeedLineControl.new()
	_line_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line_ctrl.mouse_filter=Control.MOUSE_FILTER_IGNORE
	c.add_child(_line_ctrl); _line_ctrl.setup(line_count,line_color)


func get_movement_basis()->Array:
	var yr:=deg_to_rad(_cam_yaw)
	return [Vector3(-sin(yr),0,-cos(yr)),Vector3(cos(yr),0,-sin(yr))]


# ── Speed Lines ───────────────────────────────────────────────────────────────
class _SpeedLineControl extends Control:
	var _intensity:float; var _time:float
	var _angles:PackedFloat32Array; var _lengths:PackedFloat32Array
	var _offsets:PackedFloat32Array; var _speeds:PackedFloat32Array
	var _widths:PackedFloat32Array;  var _col:Color; var _n:int

	func setup(count:int,col:Color)->void:
		_n=count; _col=col
		_angles.resize(count);_lengths.resize(count);_offsets.resize(count)
		_speeds.resize(count);_widths.resize(count)
		var r:=RandomNumberGenerator.new(); r.randomize()
		for i in count:
			_angles[i]=r.randf_range(0,TAU);     _lengths[i]=r.randf_range(0.18,0.52)
			_offsets[i]=r.randf_range(0.10,0.90);_speeds[i]=r.randf_range(1.4,3.8)
			_widths[i]=r.randf_range(2.0,5.5)

	func set_intensity(t:float)->void: _intensity=t; queue_redraw()
	func _process(delta:float)->void:
		if _intensity>0.001: _time+=delta*(1.2+_intensity*3.2); queue_redraw()

	func _draw()->void:
		if _intensity<0.001: return
		var cx:=size.x*0.5; var cy:=size.y*0.5; var diag:=Vector2(cx,cy).length()
		for i in _n:
			var off:=fmod(_offsets[i]+_time*_speeds[i]*0.28*_intensity,1.0)
			var ds:=diag*off; var de:=diag*minf(off+_lengths[i]*_intensity,1.10)
			var dir:=Vector2(cos(_angles[i]),sin(_angles[i]))
			var alpha:=_col.a*_intensity*smoothstep(0.10,0.45,off)
			draw_line(Vector2(cx,cy)+dir*ds,Vector2(cx,cy)+dir*de,
				Color(_col.r,_col.g,_col.b,alpha),_widths[i]*(0.5+_intensity*0.8))
