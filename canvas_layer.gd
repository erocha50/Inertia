## debug_hud.gd – CanvasLayer (layer = 20)
extends CanvasLayer

# ↓ Updated to match your new scene: Node3D "test_world" → "FlashCharacter"
@export var character_path : NodePath = ^"/root/test_world/FlashCharacter"

const GW:=220; const GH:=55; const GAP:=10; const ML:=10; const MT:=10
const MAP:=200; const EW:=200; const EH:=90; const STH:=100
const TRAIL:=220; const HLEN:=120; const ELEN:=220
const EYRNG:float=12.0; const SHLEN:=8

var _sm:float=60.0; var _ss:float=60.0; var _sto:float=40.0
var _hm:Array[float]=[]; var _hsp:Array[float]=[]; var _hst:Array[float]=[]
var _trail:Array[Vector2]=[]; var _tstr:Array[float]=[]
var _strain:float=0.0; var _vxz:=Vector2.ZERO
var _elev:Array[float]=[]; var _edist:Array[float]=[]
var _eref:float=0.0; var _eref_set:=false; var _eld:float=0.0; var _pxz:=Vector2.ZERO
var _sid:int=0; var _stime:float=0.0; var _shist:Array[int]=[]
var _stamina:float=100.0; var _stamina_max:float=100.0
var _drifting:=false; var _dash_cd:=0.0
var _char:Node=null; var _ctrl:_HUD=null


func _ready() -> void:
	layer = 20
	# Try the exported path first; if it fails, search the tree for a CharacterBody3D
	_char = get_node_or_null(character_path)
	if _char == null:
		push_warning("debug_hud: '%s' not found — searching scene tree for CharacterBody3D" % character_path)
		_char = _find_character(get_tree().root)
	if _char == null:
		push_error("debug_hud: could not find character — HUD disabled"); return

	if _char.has_signal("debug_stats"):    _char.debug_stats.connect(_on_stats)
	if _char.has_signal("turn_strain"):    _char.turn_strain.connect(func(v:float): _strain=v)
	if _char.has_signal("height_changed"): _char.height_changed.connect(_on_elev)
	if _char.has_signal("state_changed"):  _char.state_changed.connect(_on_state)

	for _i in HLEN:
		_hm.append(0.0)
		_hsp.append(0.0)
		_hst.append(0.0)

	_ctrl = _HUD.new()
	_ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctrl.position = Vector2(ML, MT)
	_ctrl.size = Vector2(GW+GAP+MAP, maxi(GH*3+GAP*2+GAP+STH, MAP+GAP+EH))
	add_child(_ctrl)
	_ctrl.init(GW,GH,GAP,MAP,EW,EH,STH,
		["Momentum","Speed m/s","Stop Force"],
		[Color(0.35,0.85,1.0),Color(0.4,1.0,0.5),Color(1.0,0.45,0.35)],
		[_hm,_hsp,_hst])


# Fallback: walk the entire scene tree to find a CharacterBody3D
func _find_character(node:Node) -> Node:
	if node is CharacterBody3D: return node
	for child in node.get_children():
		var found := _find_character(child)
		if found != null: return found
	return null


func _physics_process(_d: float) -> void:
	if _char == null or _ctrl == null: return
	if _char is CharacterBody3D:
		var cb := _char as CharacterBody3D
		var p  := Vector2(cb.global_position.x, cb.global_position.z)
		_trail.append(p); _tstr.append(_strain)
		_vxz = Vector2(cb.velocity.x, cb.velocity.z)
		if _trail.size() > TRAIL: _trail.pop_front(); _tstr.pop_front()
		_eld += p.distance_to(_pxz); _pxz = p
	if _char.has_method("get_state"):      _sid      = _char.get_state()
	if _char.has_method("get_state_time"): _stime    = _char.get_state_time()
	if _char.has_method("get_stamina"):    _stamina  = _char.get_stamina()
	if _char.has_method("is_drifting"):    _drifting = _char.is_drifting()
	if "dash_cooldown" in _char and "_dash_cd" in _char:
		var dc:float = _char.get("dash_cooldown")
		_dash_cd = _char.get("_dash_cd") / dc if dc > 0.0 else 0.0
	if "stamina_max" in _char: _stamina_max = _char.get("stamina_max")
	_ctrl.set_trail(_trail, _tstr, _vxz)
	_ctrl.set_elev(_elev, _edist, _eref, EYRNG)
	_ctrl.set_state(_sid, _stime, _shist, _stamina, _stamina_max, _drifting, _dash_cd)
	_ctrl.queue_redraw()


func _on_stats(m:float, s:float, st:float) -> void:
	_push(_hm,m); _push(_hsp,s); _push(_hst,st)
	_sm=maxf(_sm,m*1.1); _ss=maxf(_ss,s*1.1); _sto=maxf(_sto,st*1.1)
	if _ctrl: _ctrl.set_scales([_sm,_ss,_sto])

func _on_elev(y:float) -> void:
	if not _eref_set: _eref=y; _eref_set=true
	_elev.append(y); _edist.append(_eld)
	if _elev.size()>ELEN: _elev.pop_front(); _edist.pop_front()

func _on_state(ns:int) -> void:
	_shist.append(ns); if _shist.size()>SHLEN: _shist.pop_front()

func _push(a:Array[float], v:float) -> void:
	a.append(v); if a.size()>HLEN: a.pop_front()


# ═════════════════════════════════════════════════════════════════════════════
class _HUD extends Control:
	var _gw:int; var _gh:int; var _gap:int; var _msz:int
	var _ew:int; var _eh:int; var _sth:int
	var _labels:Array; var _colors:Array; var _hists:Array
	var _scales:Array = [60.0,60.0,40.0]
	var _trail:Array[Vector2]=[]; var _tstr:Array[float]=[]; var _vxz:=Vector2.ZERO
	var _elev:Array[float]=[]; var _edist:Array[float]=[]
	var _eref:=0.0; var _eyr:=12.0
	var _sid:=0; var _st:=0.0; var _shist:Array[int]=[]
	var _stamina:=100.0; var _stamina_max:=100.0
	var _drifting:=false; var _dash_t:=0.0

	const SNAMES:=["IDLE","RUN","AIR","SLIDE","ARC"]
	const SCOLS:=[Color(0.55,0.55,0.60),Color(0.30,0.90,0.45),
				  Color(0.30,0.70,1.00),Color(1.00,0.70,0.20),Color(1.00,0.35,0.35)]
	const BARMAX:=5.0

	func init(gw:int,gh:int,gap:int,msz:int,ew:int,eh:int,sth:int,lb:Array,co:Array,hi:Array)->void:
		_gw=gw;_gh=gh;_gap=gap;_msz=msz;_ew=ew;_eh=eh;_sth=sth;_labels=lb;_colors=co;_hists=hi

	func set_scales(s:Array)->void: _scales=s
	func set_trail(t:Array[Vector2],st:Array[float],v:Vector2)->void: _trail=t;_tstr=st;_vxz=v
	func set_elev(h:Array[float],d:Array[float],r:float,y:float)->void: _elev=h;_edist=d;_eref=r;_eyr=y
	func set_state(sid:int,st:float,sh:Array[int],stam:float,stam_max:float,drft:bool,dcd:float)->void:
		_sid=sid;_st=st;_shist=sh;_stamina=stam;_stamina_max=stam_max;_drifting=drft;_dash_t=dcd

	func _draw()->void: _graphs();_state_panel();_map();_elevation()

	func _graphs()->void:
		var fnt:=ThemeDB.fallback_font; var fs:=10
		for gi in 3:
			var ox:=0; var oy:=gi*(_gh+_gap); var col:Color=_colors[gi]
			var hist:Array=_hists[gi]; var sc:=maxf(_scales[gi],0.001)
			draw_rect(Rect2(ox,oy,_gw,_gh),Color(0.05,0.05,0.09,0.84))
			draw_line(Vector2(ox,oy+_gh*0.5),Vector2(ox+_gw,oy+_gh*0.5),Color(1,1,1,0.06),1.0)
			if hist.size()>1:
				var step:=float(_gw)/float(hist.size()-1)
				for i in hist.size()-1:
					var age:=lerpf(0.2,1.0,float(i)/float(hist.size()))
					draw_line(
						Vector2(ox+i*step, oy+_gh-clampf(hist[i]/sc,0.0,1.0)*_gh),
						Vector2(ox+(i+1)*step, oy+_gh-clampf(hist[i+1]/sc,0.0,1.0)*_gh),
						Color(col.r,col.g,col.b,age),1.6)
			if hist.size()>0:
				draw_circle(Vector2(ox+_gw-1,oy+_gh-clampf(hist[-1]/sc,0.0,1.0)*_gh),2.5,col)
			draw_rect(Rect2(ox,oy,_gw,_gh),Color(col.r,col.g,col.b,0.22),false,1.0)
			draw_string(fnt,Vector2(ox+5,oy+fs+3),
				_labels[gi]+"  %.1f"%[hist[-1] if hist.size()>0 else 0.0],
				HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(col.r,col.g,col.b,0.92))

	func _state_panel()->void:
		var fnt:=ThemeDB.fallback_font
		var ox:=0.0; var oy:=float(3*(_gh+_gap)); var pw:=float(_gw); var ph:=float(_sth)
		draw_rect(Rect2(ox,oy,pw,ph),Color(0.04,0.05,0.10,0.90))
		var sid:=clampi(_sid,0,SNAMES.size()-1); var sc:Color=SCOLS[sid]
		draw_rect(Rect2(ox+8,oy+10,68,24),Color(sc.r,sc.g,sc.b,0.18))
		draw_rect(Rect2(ox+8,oy+10,68,24),Color(sc.r,sc.g,sc.b,0.70),false,1.2)
		draw_string(fnt,Vector2(ox+42,oy+26),SNAMES[sid],HORIZONTAL_ALIGNMENT_CENTER,68,11,sc)
		if _drifting: draw_string(fnt,Vector2(ox+84,oy+24),"DRIFT",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(1.0,0.8,0.2,0.90))
		if _dash_t>0.0:
			draw_rect(Rect2(ox+84,oy+10,40*_dash_t,8),Color(0.4,0.8,1.0,0.70))
			draw_rect(Rect2(ox+84,oy+10,40,8),Color(0.4,0.8,1.0,0.30),false,0.8)
		var bx:=ox+8; var by:=oy+42; var bw:=pw-16
		draw_rect(Rect2(bx,by,bw,7),Color(0.12,0.12,0.18,0.80))
		draw_rect(Rect2(bx,by,bw*clampf(_st/BARMAX,0.0,1.0),7),Color(sc.r,sc.g,sc.b,0.70))
		draw_rect(Rect2(bx,by,bw,7),Color(sc.r,sc.g,sc.b,0.30),false,0.5)
		draw_string(fnt,Vector2(bx,by-2),"%.2fs"%_st,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(sc.r,sc.g,sc.b,0.75))
		var sy:=by+14
		var stam_col:=Color(0.3,1.0,0.45,0.80) if _stamina>_stamina_max*0.3 else Color(1.0,0.3,0.3,0.90)
		draw_rect(Rect2(bx,sy,bw,5),Color(0.10,0.10,0.15,0.80))
		draw_rect(Rect2(bx,sy,bw*clampf(_stamina/_stamina_max,0.0,1.0),5),stam_col)
		draw_rect(Rect2(bx,sy,bw,5),Color(stam_col.r,stam_col.g,stam_col.b,0.30),false,0.5)
		draw_string(fnt,Vector2(bx,sy-2),"STA",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color(stam_col.r,stam_col.g,stam_col.b,0.65))
		var cw:=(bw-float((SNAMES.size()-1)*3))/8.0; var cy:=oy+ph-12-8
		for i in _shist.size():
			var hc:Color=SCOLS[clampi(_shist[i],0,SCOLS.size()-1)]
			var age:=float(i+1)/float(_shist.size()); var cx:=bx+float(i)*(cw+3)
			draw_rect(Rect2(cx,cy,cw,12),Color(hc.r,hc.g,hc.b,lerpf(0.15,0.65,age)))
			draw_string(fnt,Vector2(cx+2,cy+9),SNAMES[clampi(_shist[i],0,SNAMES.size()-1)].left(1),
				HORIZONTAL_ALIGNMENT_LEFT,cw,7,Color(hc.r,hc.g,hc.b,lerpf(0.4,0.9,age)))
		draw_rect(Rect2(ox,oy,pw,ph),Color(sc.r,sc.g,sc.b,0.18),false,1.0)
		draw_string(fnt,Vector2(ox+pw-48,oy+18),"STATE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(0.5,0.5,0.6,0.50))

	func _map()->void:
		var fnt:=ThemeDB.fallback_font
		var mx:=float(_gw+_gap); var my:=0.0; var sz:=float(_msz); var half:=sz*0.5; var rng:=20.0
		draw_rect(Rect2(mx,my,sz,sz),Color(0.05,0.05,0.09,0.88))
		draw_line(Vector2(mx,my+half),Vector2(mx+sz,my+half),Color(1,1,1,0.06),1.0)
		draw_line(Vector2(mx+half,my),Vector2(mx+half,my+sz),Color(1,1,1,0.06),1.0)
		draw_string(fnt,Vector2(mx+5,my+11),"TOP DOWN",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.4,0.8,1.0,0.55))
		if _trail.size()<2:
			draw_rect(Rect2(mx,my,sz,sz),Color(0.4,0.8,1.0,0.18),false,1.0); return
		var orig:Vector2=_trail[-1]
		for i in _trail.size():
			var rel:Vector2=_trail[i]-orig
			var px:=mx+half+(rel.x/rng)*half; var py:=my+half+(rel.y/rng)*half
			if px<mx or px>mx+sz or py<my or py>my+sz: continue
			var age:=float(i)/float(_trail.size()-1)
			var strain:float=_tstr[i] if i<_tstr.size() else 0.0
			draw_circle(Vector2(px,py),lerpf(1.0,2.5,age),
				Color(lerpf(0.85,1.0,strain),lerpf(0.85,0.25,strain),lerpf(0.85,0.20,strain),lerpf(0.08,0.80,age)))
		var spd:=_vxz.length()
		if spd>0.5:
			var dn:=_vxz.normalized(); var al:=clampf(spd/rng*half*0.6,6.0,half*0.45)
			var cx:=mx+half; var cy:=my+half; var tip:=Vector2(cx,cy)+dn*al
			var perp:=Vector2(-dn.y,dn.x); var hs:=clampf(al*0.28,4.0,12.0)
			draw_line(Vector2(cx,cy),tip,Color(0.3,1.0,0.5,0.95),2.0)
			draw_line(tip,tip-dn*hs+perp*hs*0.55,Color(0.3,1.0,0.5,0.95),1.8)
			draw_line(tip,tip-dn*hs-perp*hs*0.55,Color(0.3,1.0,0.5,0.95),1.8)
		var cs:float=_tstr[-1] if _tstr.size()>0 else 0.0
		draw_circle(Vector2(mx+half,my+half),4.0,Color(lerpf(0.3,1.0,cs),lerpf(1.0,0.2,cs),lerpf(0.5,0.2,cs),1.0))
		if cs>0.05: draw_arc(Vector2(mx+half,my+half),7.0,0.0,TAU,16,Color(1.0,0.3,0.2,cs*0.8),1.5)
		draw_rect(Rect2(mx,my,sz,sz),Color(0.4,0.8,1.0,0.20),false,1.0)
		draw_string(fnt,Vector2(mx+5,my+sz-5),"%.0f m/s"%spd,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(0.4,1.0,0.5,0.70))

	func _elevation()->void:
		if _elev.size()<2: return
		var fnt:=ThemeDB.fallback_font
		var ox:=float(_gw+_gap); var oy:=float(_msz+_gap); var ew:=float(_ew); var eh:=float(_eh)
		draw_rect(Rect2(ox,oy,ew,eh),Color(0.04,0.06,0.10,0.90))
		for b in 4: draw_line(Vector2(ox,oy+eh*float(b)/4),Vector2(ox+ew,oy+eh*float(b)/4),Color(1,1,1,0.05),1.0)
		var zy:=oy+eh*0.5
		draw_line(Vector2(ox,zy),Vector2(ox+ew,zy),Color(0.5,0.8,1.0,0.35),1.5)
		draw_string(fnt,Vector2(ox+3,oy+9),"+%.0fm"%_eyr,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(0.6,0.9,1.0,0.55))
		draw_string(fnt,Vector2(ox+3,zy-2),"0",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(0.6,0.9,1.0,0.55))
		draw_string(fnt,Vector2(ox+3,oy+eh-2),"-%.0fm"%_eyr,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(0.6,0.9,1.0,0.55))
		draw_string(fnt,Vector2(ox+ew-58,oy+9),"ELEVATION",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(0.9,0.7,0.3,0.60))
		var n:=_elev.size(); var dn:float=_edist[-1] if n>0 else 0.0; var dw:=ew*0.25
		var ppx:=-1.0; var ppy:=0.0
		for i in n:
			var tx:=(_edist[i]-dn+dw)/dw
			if tx<0.0 or tx>1.0: continue
			var dy:=_elev[i]-_eref; var ty:=clampf(0.5-dy/(_eyr*2.0),0.0,1.0)
			var px:=ox+tx*ew; var py:=oy+ty*eh; var age:=float(i)/float(n-1)
			var col:=Color(lerpf(0.25,1.0,clampf(dy/_eyr,0.0,1.0)),lerpf(0.80,0.75,clampf(dy/_eyr,0.0,1.0)),lerpf(0.85,0.10,clampf(dy/_eyr,0.0,1.0)),lerpf(0.20,0.95,age))
			if ppx>=0.0: draw_line(Vector2(ppx,ppy),Vector2(px,py),col,1.8)
			ppx=px; ppy=py
		if n>0:
			var cd:=_elev[-1]-_eref; var ct:=clampf(0.5-cd/(_eyr*2.0),0.0,1.0)
			draw_circle(Vector2(ox+ew-2,oy+ct*eh),3.0,Color(1.0,0.9,0.4,1.0))
			draw_string(fnt,Vector2(ox+ew-46,oy+eh-3),"%+.1fm"%cd,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color(1.0,0.9,0.4,0.85))
		draw_rect(Rect2(ox,oy,ew,eh),Color(0.4,0.8,1.0,0.20),false,1.0)
