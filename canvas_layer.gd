## debug_hud.gd  –  CanvasLayer (layer = 20)
## Connects to the full-physics flash_character_3d.gd.
## Fixed: typed arrays throughout (_trail, _tstr, _elev, _edist, _shist)
##        eliminates all "cannot infer type" and implicit-cast errors.
extends CanvasLayer

@export var character_path : NodePath = ^"/root/TestWorld/CharacterBody3D"

const GW := 220; const GH := 55; const GAP := 10
const ML := 10;  const MT := 10
const MAP := 200; const EW := 200; const EH := 90; const STH := 100
const TRAIL := 220; const HLEN := 120; const ELEN := 220
const EYRNG : float = 12.0; const SHLEN := 8

var _sm  : float = 60.0; var _ss  : float = 60.0; var _sto : float = 40.0
var _hm  : Array[float] = []; var _hsp : Array[float] = []; var _hst : Array[float] = []
# FIX: typed arrays so element access has a known type everywhere
var _trail : Array[Vector2] = []; var _tstr : Array[float] = []
var _strain : float = 0.0; var _vxz : Vector2 = Vector2.ZERO
var _elev : Array[float] = []; var _edist : Array[float] = []
var _eref : float = 0.0; var _eref_set := false; var _eld : float = 0.0
var _pxz  : Vector2 = Vector2.ZERO
var _sid  : int = 0; var _stime : float = 0.0; var _shist : Array[int] = []
var _stamina : float = 100.0; var _drifting := false; var _dash_cd := 0.0
var _char : Node; var _ctrl : _HUD


func _ready() -> void:
	layer = 20
	_char = get_node_or_null(character_path)
	if _char == null: push_warning("debug_hud: path not found"); return
	if _char.has_signal("debug_stats"):    _char.debug_stats.connect(_on_stats)
	if _char.has_signal("turn_strain"):    _char.turn_strain.connect(func(v): _strain = v)
	if _char.has_signal("height_changed"): _char.height_changed.connect(_on_elev)
	if _char.has_signal("state_changed"):  _char.state_changed.connect(_on_state)
	for _i in HLEN: _hm.append(0.0); _hsp.append(0.0); _hst.append(0.0)
	_ctrl = _HUD.new()
	_ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctrl.position = Vector2(ML, MT)
	_ctrl.size     = Vector2(GW + GAP + MAP, maxi(GH*3+GAP*2+GAP+STH, MAP+GAP+EH))
	add_child(_ctrl)
	_ctrl.init(GW, GH, GAP, MAP, EW, EH, STH,
		["Momentum", "Speed m/s", "Stop Force"],
		[Color(0.35,0.85,1.0), Color(0.4,1.0,0.5), Color(1.0,0.45,0.35)],
		[_hm, _hsp, _hst])
	print("[canvas_layer] HUD initialized. Press F1 to toggle visibility.")


func _physics_process(_d: float) -> void:
	# HUD toggle with F1
	if Input.is_action_just_pressed("ui_cancel"):
		if _ctrl: _ctrl.visible = !_ctrl.visible
	
	if _char == null: return
	if _char is CharacterBody3D:
		var cb := _char as CharacterBody3D
		var p  := Vector2(cb.global_position.x, cb.global_position.z)
		_trail.append(p); _tstr.append(_strain)
		_vxz = Vector2(cb.velocity.x, cb.velocity.z)
		if _trail.size() > TRAIL: _trail.pop_front(); _tstr.pop_front()
		_eld += p.distance_to(_pxz); _pxz = p
	if _char.has_method("get_state"):      _sid     = _char.get_state()
	if _char.has_method("get_state_time"): _stime   = _char.get_state_time()
	if _char.has_method("get_stamina"):    _stamina = _char.get_stamina()
	if _char.has_method("is_drifting"):    _drifting= _char.is_drifting()
	if "dash_cooldown" in _char and "_dash_cd" in _char:
		_dash_cd = float(_char.get("_dash_cd")) / float(_char.get("dash_cooldown"))
	if _ctrl:
		_ctrl.set_trail(_trail, _tstr, _vxz)
		_ctrl.set_elev(_elev, _edist, _eref, EYRNG)
		_ctrl.set_state(_sid, _stime, _shist, _stamina, _drifting, _dash_cd)
		_ctrl.set_fps(Engine.get_frames_per_second())
		# OPTIMIZATION: Only redraw if data significantly changed
		if _ctrl._needs_redraw():
			_ctrl.queue_redraw()


func _on_stats(m: float, s: float, st: float) -> void:
	_push(_hm, m); _push(_hsp, s); _push(_hst, st)
	_sm = maxf(_sm, m*1.1); _ss = maxf(_ss, s*1.1); _sto = maxf(_sto, st*1.1)
	if _ctrl: _ctrl.set_scales([_sm, _ss, _sto])

func _on_elev(y: float) -> void:
	if not _eref_set: _eref = y; _eref_set = true
	_elev.append(y); _edist.append(_eld)
	if _elev.size() > ELEN: _elev.pop_front(); _edist.pop_front()

func _on_state(ns: int) -> void:
	_shist.append(ns)
	if _shist.size() > SHLEN: _shist.pop_front()

func _push(a: Array[float], v: float) -> void:
	a.append(v); if a.size() > HLEN: a.pop_front()


# ═════════════════════════════════════════════════════════════════════════════
class _HUD extends Control:
	var _gw : int; var _gh : int; var _gap : int; var _msz : int
	var _ew : int; var _eh : int; var _sth : int
	var _labels : Array; var _colors : Array; var _hists : Array
	var _scales := [60.0, 60.0, 40.0]
	# FIX: typed arrays — no more "cannot infer type" on element access
	var _trail  : Array[Vector2] = []
	var _tstr   : Array[float]   = []
	var _vxz    := Vector2.ZERO
	var _elev   : Array[float]   = []
	var _edist  : Array[float]   = []
	var _eref   := 0.0
	var _eyr    := 12.0
	var _sid    := 0
	var _st     := 0.0
	var _shist  : Array[int]     = []
	var _stamina := 100.0
	var _drifting := false
	var _dash_t  := 0.0
	var _fps: int = 0

	const SNAMES := ["IDLE","RUN","AIR","SLIDE","ARC"]
	const SCOLS  := [Color(0.55,0.55,0.60), Color(0.30,0.90,0.45),
					 Color(0.30,0.70,1.00), Color(1.00,0.70,0.20), Color(1.00,0.35,0.35)]
	const BARMAX := 5.0

	func init(gw,gh,gap,msz,ew,eh,sth,lb,co,hi) -> void:
		_gw=gw; _gh=gh; _gap=gap; _msz=msz; _ew=ew; _eh=eh; _sth=sth
		_labels=lb; _colors=co; _hists=hi
	
	var _last_sid: int = -1
	var _last_st: float = -1.0
	var _last_stamina: float = -1.0
	var _last_drifting: bool = false
	var _last_dash_t: float = -1.0
	var _last_trail_sz: int = -1
	
	func _needs_redraw() -> bool:
		# Only redraw if state significantly changed
		return (_sid != _last_sid or 
				abs(_st - _last_st) > 0.05 or 
				abs(_stamina - _last_stamina) > 2.0 or 
				_drifting != _last_drifting or 
				abs(_dash_t - _last_dash_t) > 0.05 or
				_trail.size() != _last_trail_sz)

	func set_scales(s: Array)                                           -> void: _scales=s
	func set_trail(t: Array[Vector2], st: Array[float], v: Vector2)    -> void: _trail=t; _tstr=st; _vxz=v
	func set_elev(h: Array[float], d: Array[float], r: float, y: float)-> void: _elev=h; _edist=d; _eref=r; _eyr=y
	func set_state(sid:int,st:float,sh:Array[int],stam:float,drft:bool,dcd:float) -> void:
		_sid=sid; _st=st; _shist=sh; _stamina=stam; _drifting=drft; _dash_t=dcd
	func set_fps(f: int) -> void: _fps = f
	
	func _cache_state() -> void:
		_last_sid=_sid; _last_st=_st; _last_stamina=_stamina; _last_drifting=_drifting; _last_dash_t=_dash_t; _last_trail_sz=_trail.size()

	func _draw() -> void:
		_graphs(); _state_panel(); _map(); _elevation()
		# Draw FPS in top-right corner
		var fnt := ThemeDB.fallback_font
		var fps_color: Color = Color(0.3,1.0,0.5,0.9) if _fps >= 60 else (Color(1.0,0.7,0.2,0.9) if _fps >= 30 else Color(1.0,0.3,0.3,0.9))
		draw_string(fnt, Vector2(get_viewport_rect().size.x - 80, 20), 
			"%d FPS" % _fps, HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, fps_color)
		_cache_state()  # Cache after drawing

	# ── Graphs ────────────────────────────────────────────────────────────────
	func _graphs() -> void:
		var fnt := ThemeDB.fallback_font; var fs := 10
		for gi in 3:
			var ox := 0; var oy := gi * (_gh + _gap)
			var col : Color = _colors[gi]
			var hist : Array = _hists[gi]
			var sc : float = maxf(_scales[gi], 0.001)
			draw_rect(Rect2(ox, oy, _gw, _gh), Color(0.05,0.05,0.09,0.84))
			draw_line(Vector2(ox, oy+_gh*0.5), Vector2(ox+_gw, oy+_gh*0.5), Color(1,1,1,0.06), 1.0)
			if hist.size() > 1:
				var step := float(_gw) / float(hist.size()-1)
				# OPTIMIZATION: Only draw last N lines instead of all
				var start_idx := maxi(0, hist.size()-60)
				for i in range(start_idx, hist.size()-1):
					var age := lerpf(0.2, 1.0, float(i-start_idx) / float(maxi(1, hist.size()-start_idx-1)))
					draw_line(
						Vector2(ox + (i-start_idx)*step,     oy + _gh - clampf(float(hist[i])   / sc, 0.0, 1.0) * _gh),
						Vector2(ox + (i-start_idx+1)*step, oy + _gh - clampf(float(hist[i+1]) / sc, 0.0, 1.0) * _gh),
						Color(col.r, col.g, col.b, age), 1.6)
			if hist.size() > 0:
				draw_circle(Vector2(ox+_gw-1, oy+_gh - clampf(float(hist[-1])/sc, 0.0, 1.0)*_gh), 2.5, col)
			draw_rect(Rect2(ox, oy, _gw, _gh), Color(col.r,col.g,col.b,0.22), false, 1.0)
			draw_string(fnt, Vector2(ox+5, oy+fs+3),
				_labels[gi] + "  %.1f" % [float(hist[-1]) if hist.size() > 0 else 0.0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r,col.g,col.b,0.92))

	# ── State panel ───────────────────────────────────────────────────────────
	func _state_panel() -> void:
		var fnt := ThemeDB.fallback_font
		var ox := 0.0; var oy := float(3*(_gh+_gap)); var pw := float(_gw); var ph := float(_sth)
		draw_rect(Rect2(ox, oy, pw, ph), Color(0.04,0.05,0.10,0.90))
		var sid := clampi(_sid, 0, SNAMES.size()-1)
		var sc  : Color = SCOLS[sid]

		# Badge
		draw_rect(Rect2(ox+8, oy+10, 68, 24), Color(sc.r,sc.g,sc.b,0.18), true)
		draw_rect(Rect2(ox+8, oy+10, 68, 24), Color(sc.r,sc.g,sc.b,0.70), false, 1.2)
		draw_string(fnt, Vector2(ox+42, oy+26), SNAMES[sid], HORIZONTAL_ALIGNMENT_CENTER, 68, 11, sc)

		# Drift / Dash indicators
		if _drifting:
			draw_string(fnt, Vector2(ox+84, oy+24), "DRIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
				Color(1.0,0.8,0.2,0.90))
		if _dash_t > 0.0:
			draw_rect(Rect2(ox+84, oy+10, 40*_dash_t, 8), Color(0.4,0.8,1.0,0.70))
			draw_rect(Rect2(ox+84, oy+10, 40, 8), Color(0.4,0.8,1.0,0.30), false, 0.8)

		# Time bar
		var bx := ox+8; var by := oy+42; var bw := pw-16
		draw_rect(Rect2(bx, by, bw, 7), Color(0.12,0.12,0.18,0.80))
		draw_rect(Rect2(bx, by, bw * clampf(_st/BARMAX, 0.0, 1.0), 7), Color(sc.r,sc.g,sc.b,0.70))
		draw_rect(Rect2(bx, by, bw, 7), Color(sc.r,sc.g,sc.b,0.30), false, 0.5)
		draw_string(fnt, Vector2(bx, by-2), "%.2fs" % _st, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(sc.r,sc.g,sc.b,0.75))

		# Stamina bar
		var sy := by + 14
		var stam_col := Color(0.3,1.0,0.45,0.80) if _stamina > 30 else Color(1.0,0.3,0.3,0.90)
		draw_rect(Rect2(bx, sy, bw, 5), Color(0.10,0.10,0.15,0.80))
		draw_rect(Rect2(bx, sy, bw * clampf(_stamina/100.0, 0.0, 1.0), 5), stam_col)
		draw_rect(Rect2(bx, sy, bw, 5), Color(stam_col.r,stam_col.g,stam_col.b,0.30), false, 0.5)
		draw_string(fnt, Vector2(bx, sy-2), "STA", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			Color(stam_col.r,stam_col.g,stam_col.b,0.65))

		# History chips
		# FIX: renamed loop variable from 'cy' to 'chip_y' to avoid shadowing outer 'cy' in _map()
		var cw := (bw - float((SNAMES.size()-1)*3)) / 8.0
		var chip_y := oy + ph - 12 - 8
		for i in _shist.size():
			var hc : Color = SCOLS[clampi(_shist[i], 0, SCOLS.size()-1)]
			var age := float(i+1) / float(_shist.size())
			var chip_x := bx + float(i) * (cw + 3)
			draw_rect(Rect2(chip_x, chip_y, cw, 12), Color(hc.r,hc.g,hc.b, lerpf(0.15,0.65,age)))
			draw_string(fnt, Vector2(chip_x+2, chip_y+9),
				SNAMES[clampi(_shist[i], 0, SNAMES.size()-1)].left(1),
				HORIZONTAL_ALIGNMENT_LEFT, cw, 7, Color(hc.r,hc.g,hc.b, lerpf(0.4,0.9,age)))

		draw_rect(Rect2(ox, oy, pw, ph), Color(sc.r,sc.g,sc.b,0.18), false, 1.0)
		draw_string(fnt, Vector2(ox+pw-48, oy+18), "STATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color(0.5,0.5,0.6,0.50))

	# ── Top-down map ──────────────────────────────────────────────────────────
	func _map() -> void:
		var fnt  := ThemeDB.fallback_font
		var mx   := float(_gw + _gap); var my := 0.0
		var sz   := float(_msz); var half := sz * 0.5; var rng := 20.0
		draw_rect(Rect2(mx, my, sz, sz), Color(0.05,0.05,0.09,0.88))
		draw_line(Vector2(mx, my+half),  Vector2(mx+sz, my+half), Color(1,1,1,0.06), 1.0)
		draw_line(Vector2(mx+half, my),  Vector2(mx+half, my+sz), Color(1,1,1,0.06), 1.0)
		draw_string(fnt, Vector2(mx+5, my+11), "TOP DOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.4,0.8,1.0,0.55))
		if _trail.size() < 2:
			draw_rect(Rect2(mx, my, sz, sz), Color(0.4,0.8,1.0,0.18), false, 1.0); return

		# FIX: _trail is now Array[Vector2] — direct access is typed, no cast needed
		var orig : Vector2 = _trail[-1]
		# OPTIMIZATION: Skip every other point for smaller trails
		var step_size: int = 1 if _trail.size() < 100 else 2
		for i in range(0, _trail.size(), step_size):
			var rel : Vector2 = _trail[i] - orig
			var px := mx + half + (rel.x / rng) * half
			var py := my + half + (rel.y / rng) * half
			if px < mx or px > mx+sz or py < my or py > my+sz: continue
			var age := float(i) / float(_trail.size()-1)
			# FIX: _tstr is now Array[float] — direct access is typed
			var str : float = _tstr[i] if i < _tstr.size() else 0.0
			draw_circle(Vector2(px, py), lerpf(1.0, 2.5, age),
				Color(lerpf(0.85,1.0,str), lerpf(0.85,0.25,str), lerpf(0.85,0.20,str), lerpf(0.08,0.80,age)))

		var spd := _vxz.length()
		if spd > 0.5:
			var dn  := _vxz.normalized()
			var al  := clampf(spd / rng * half * 0.6, 6.0, half * 0.45)
			# FIX: renamed 'cx'/'cy' to 'map_cx'/'map_cy' — distinct from any chip loop vars
			var map_cx := mx + half; var map_cy := my + half
			var tip    := Vector2(map_cx, map_cy) + dn * al
			var perp   := Vector2(-dn.y, dn.x); var hs := clampf(al * 0.28, 4.0, 12.0)
			draw_line(Vector2(map_cx, map_cy), tip, Color(0.3,1.0,0.5,0.95), 2.0)
			draw_line(tip, tip - dn*hs + perp*hs*0.55, Color(0.3,1.0,0.5,0.95), 1.8)
			draw_line(tip, tip - dn*hs - perp*hs*0.55, Color(0.3,1.0,0.5,0.95), 1.8)

		# FIX: _tstr is Array[float] — last element access is typed
		var cs : float = _tstr[-1] if _tstr.size() > 0 else 0.0
		draw_circle(Vector2(mx+half, my+half), 4.0,
			Color(lerpf(0.3,1.0,cs), lerpf(1.0,0.2,cs), lerpf(0.5,0.2,cs), 1.0))
		if cs > 0.05:
			draw_arc(Vector2(mx+half, my+half), 7.0, 0.0, TAU, 16, Color(1.0,0.3,0.2,cs*0.8), 1.5)
		draw_rect(Rect2(mx, my, sz, sz), Color(0.4,0.8,1.0,0.20), false, 1.0)
		draw_string(fnt, Vector2(mx+5, my+sz-5), "%.0f m/s" % spd,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4,1.0,0.5,0.70))

	# ── Elevation graph ───────────────────────────────────────────────────────
	func _elevation() -> void:
		if _elev.size() < 2: return
		var fnt := ThemeDB.fallback_font
		var ox  := float(_gw + _gap); var oy := float(_msz + _gap)
		var ew  := float(_ew);        var eh := float(_eh)
		draw_rect(Rect2(ox, oy, ew, eh), Color(0.04,0.06,0.10,0.90))
		for b in 4:
			draw_line(Vector2(ox, oy+eh*float(b)/4), Vector2(ox+ew, oy+eh*float(b)/4),
				Color(1,1,1,0.05), 1.0)
		var zy := oy + eh * 0.5
		draw_line(Vector2(ox, zy), Vector2(ox+ew, zy), Color(0.5,0.8,1.0,0.35), 1.5)
		draw_string(fnt, Vector2(ox+3, oy+9),    "+%.0fm" % _eyr,  HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6,0.9,1.0,0.55))
		draw_string(fnt, Vector2(ox+3, zy-2),    "0",               HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6,0.9,1.0,0.55))
		draw_string(fnt, Vector2(ox+3, oy+eh-2), "-%.0fm" % _eyr,  HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6,0.9,1.0,0.55))
		draw_string(fnt, Vector2(ox+ew-58, oy+9),"ELEVATION",       HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9,0.7,0.3,0.60))

		var n   := _elev.size()
		# FIX: _edist is Array[float] — last element access is typed
		var dn  : float = _edist[-1] if n > 0 else 0.0
		var dw  := ew * 0.25
		var ppx := -1.0; var ppy := 0.0
		# OPTIMIZATION: Skip points if elevation has many entries
		var elev_step: int = 1 if n < 150 else (2 if n < 300 else 3)
		for i in range(0, n, elev_step):
			# FIX: _edist/_elev are Array[float] — all element accesses are typed
			var tx := (_edist[i] - dn + dw) / dw
			if tx < 0.0 or tx > 1.0: continue
			var dy  := _elev[i] - _eref
			var ty  := clampf(0.5 - dy / (_eyr * 2.0), 0.0, 1.0)
			var px  := ox + tx * ew; var py := oy + ty * eh
			var age := float(i) / float(n-1)
			var asc := clampf(dy / _eyr, 0.0, 1.0)
			var col := Color(lerpf(0.25,1.0,asc), lerpf(0.80,0.75,asc), lerpf(0.85,0.10,asc),
				lerpf(0.20,0.95,age))
			if ppx >= 0.0: draw_line(Vector2(ppx,ppy), Vector2(px,py), col, 1.8)
			ppx = px; ppy = py

		if n > 0:
			# FIX: _elev is Array[float] — last element access is typed
			var cd : float = _elev[-1] - _eref
			var ct := clampf(0.5 - cd / (_eyr * 2.0), 0.0, 1.0)
			draw_circle(Vector2(ox+ew-2, oy+ct*eh), 3.0, Color(1.0,0.9,0.4,1.0))
			draw_string(fnt, Vector2(ox+ew-46, oy+eh-3), "%+.1fm" % cd,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0,0.9,0.4,0.85))
		draw_rect(Rect2(ox, oy, ew, eh), Color(0.4,0.8,1.0,0.20), false, 1.0)
