class_name MeshGen
extends RefCounted
## Procedural mesh builder. Every part (parametric surface, lathe, tube, sheet,
## rounded box) is appended to one vertex/index buffer and committed as a single
## ArrayMesh surface, so a whole food model is one draw call.
##
## Vertex layout read by shaders/food.gdshader:
##   COLOR.rgb  sRGB base colour        COLOR.a  cooking sensitivity (0 = packaging/ceramic)
##   UV.x       roughness               UV.y     bump strength
##   UV2.x      metallic

static var _noise: FastNoiseLite

var verts := PackedVector3Array()
var cols := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var idx := PackedInt32Array()
var xf := Transform3D.IDENTITY
var rough := 0.5
var bump := 0.0
var metal := 0.0
var sens := 1.0
var _patches: Array = [] # [vbase, cols_u, rows, istart, iend, solid]


static func n3(p: Vector3) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.seed = 7
	return _noise.get_noise_3dv(p)


## Deterministic pseudo-random 0..1 from an integer.
static func h1(i: int) -> float:
	var x := (i * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x & 0xffff) / 65535.0


## Sets the placement transform for following parts.
func at(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE, parent := Transform3D.IDENTITY) -> void:
	var bs := Basis.from_euler(rot_deg * (PI / 180.0)).scaled_local(scl)
	xf = parent * Transform3D(bs, pos)


func mat(r: float, bmp := 0.0, s := 1.0, m := 0.0) -> void:
	rough = r
	bump = bmp
	sens = s
	metal = m


# ------------------------------------------------------------------ core

## Parametric grid surface. fn(u, v) -> Vector3 in local space, u,v in 0..1.
## cf is a Color or Callable(u, v, p) -> Color. wrap_u joins u=1 back to u=0.
func surf(nu: int, nv: int, fn: Callable, cf = Color.WHITE, wrap_u := true, solid := true) -> void:
	var base := verts.size()
	var cu := nu if wrap_u else nu + 1
	var call: bool = cf is Callable
	var uvp := Vector2(rough, bump)
	var uv2p := Vector2(metal, 0.0)
	for j in nv + 1:
		var v := float(j) / nv
		for i in cu:
			var u := float(i) / nu
			var p: Vector3 = fn.call(u, v)
			var c: Color = cf.call(u, v, p) if call else cf
			c.a *= sens
			verts.append(xf * p)
			cols.append(c)
			uvs.append(uvp)
			uv2s.append(uv2p)
	var istart := idx.size()
	for j in nv:
		var r0 := base + j * cu
		var r1 := r0 + cu
		for i in nu:
			var i2 := (i + 1) % cu if wrap_u else i + 1
			idx.append(r0 + i)
			idx.append(r1 + i)
			idx.append(r0 + i2)
			idx.append(r0 + i2)
			idx.append(r1 + i)
			idx.append(r1 + i2)
	_patches.append([base, cu, nv + 1, istart, idx.size(), solid])


## Ellipsoid around c with radii r. f(theta, v, dir) -> radius multiplier.
func blob(c: Vector3, r: Vector3, cf, nu := 16, nv := 10, f := Callable()) -> void:
	surf(nu, nv, func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var ph := v * PI
		var dir := Vector3(sin(ph) * cos(th), -cos(ph), sin(ph) * sin(th))
		var k := 1.0 if f.is_null() else float(f.call(th, v, dir))
		return c + dir * r * k, cf)


## Surface of revolution around +Y. prof = [Vector2(radius, y)...]; a repeated
## point makes a hard crease. rf(theta, t, y) -> radius multiplier.
func lathe(prof: Array, cf, nu := 20, rf := Callable(), close_u := true) -> void:
	var n := prof.size()
	var start := 0
	for k in range(1, n + 1):
		if k == n or (prof[k] as Vector2).is_equal_approx(prof[k - 1]):
			if k - 1 > start:
				_lathe_seg(prof, start, k - 1, n, cf, nu, rf, close_u)
			start = k
	return


func _lathe_seg(prof: Array, a: int, b: int, n: int, cf, nu: int, rf: Callable, close_u: bool) -> void:
	var call: bool = cf is Callable
	var cc = cf
	if call:
		cc = func(u: float, v: float, p: Vector3) -> Color:
			return cf.call(u, (a + v * (b - a)) / maxf(1.0, n - 1.0), p)
	surf(nu, b - a, func(u: float, v: float) -> Vector3:
		var j := a + int(round(v * (b - a)))
		var pt: Vector2 = prof[j]
		var th := u * TAU
		var r := pt.x
		if not rf.is_null():
			r *= float(rf.call(th, float(j) / maxf(1.0, n - 1.0), pt.y))
		return Vector3(cos(th) * r, pt.y, sin(th) * r), cc, close_u)


## Tube along path(t) with radius rad(t, theta). flat squashes the cross
## section along the frame's "up" (ribbons). The frame starts from `up`.
func tube(nv: int, nu: int, path: Callable, rad: Callable, cf, flat := 1.0, up := Vector3.UP) -> void:
	var pts: Array = []
	for j in nv + 1:
		pts.append(path.call(float(j) / nv))
	var frames: Array = []
	var prev_n := Vector3.ZERO
	for j in nv + 1:
		var t: Vector3 = (pts[mini(j + 1, nv)] - pts[maxi(j - 1, 0)]).normalized()
		var nn: Vector3
		if j == 0:
			nn = up - t * up.dot(t)
			if nn.length() < 0.001:
				nn = Vector3.FORWARD - t * Vector3.FORWARD.dot(t)
		else:
			nn = prev_n - t * prev_n.dot(t)
		nn = nn.normalized()
		prev_n = nn
		frames.append([t.cross(nn).normalized(), nn])
	surf(nu, nv, func(u: float, v: float) -> Vector3:
		var j := int(round(v * nv))
		var th := u * TAU
		var r := float(rad.call(v, th))
		var fr: Array = frames[j]
		return pts[j] + (fr[0] as Vector3) * cos(th) * r + (fr[1] as Vector3) * sin(th) * r * flat, cf)


## Rounded box (superellipsoid). e: 1 = ellipsoid, ~0.15 = crisp box.
func rbox(c: Vector3, size: Vector3, e: float, cf, nu := 16, nv := 10, f := Callable()) -> void:
	var hs := size * 0.5
	surf(nu, nv, func(u: float, v: float) -> Vector3:
		var th := u * TAU - PI * 0.75
		var ph := v * PI - PI * 0.5
		var cp := _sp(cos(ph), e)
		var p := Vector3(cp * _sp(cos(th), e), _sp(sin(ph), e), cp * _sp(sin(th), e)) * hs
		if not f.is_null():
			p = f.call(p)
		return c + p, cf)


static func _sp(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)


## Box with subdivided flat faces (labels need the vertices). f(p) displaces.
func box(c: Vector3, size: Vector3, cf, div := 4, f := Callable()) -> void:
	var hs := size * 0.5
	for ax in 3:
		for sg in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[ax] = sg
			var a := Vector3.ZERO
			var b := Vector3.ZERO
			a[(ax + 1) % 3] = 1.0
			b[(ax + 2) % 3] = 1.0
			surf(div, div, func(u: float, v: float) -> Vector3:
				var p := n * hs + a * (u - 0.5) * size + b * (v - 0.5) * size
				if not f.is_null():
					p = f.call(p)
				return c + p, cf, false)


## Disc-like solid over a polar outline. rn = r / outline radius (0..1).
## top(rn, th) / bot(rn, th) give heights; rf(th) scales the outline; cf(face, rn, th, p)
## with face 0 top, 1 bottom, 2 rim wall, 3 cut sides (when th0..th1 is a sector).
func dsolid(R: float, top: Callable, bot: Callable, cf: Callable, nu := 24, nr := 6,
		rf := Callable(), th0 := 0.0, th1 := TAU, rim := true) -> void:
	var full := is_equal_approx(th1 - th0, TAU)
	var span := th1 - th0
	var nu2 := nu if full else maxi(2, int(ceil(nu * span / TAU)))
	var rad := func(th: float) -> float:
		return R * (1.0 if rf.is_null() else float(rf.call(th)))
	for face in 2:
		var hf: Callable = top if face == 0 else bot
		surf(nu2, nr, func(u: float, v: float) -> Vector3:
			var th := th0 + u * span
			var r: float = rad.call(th) * v
			return Vector3(cos(th) * r, hf.call(v, th), sin(th) * r),
			func(u: float, v: float, p: Vector3) -> Color:
				return cf.call(face, v, th0 + u * span, p), full)
	if rim:
		surf(nu2, 2, func(u: float, v: float) -> Vector3:
			var th := th0 + u * span
			var r: float = rad.call(th)
			return Vector3(cos(th) * r, lerpf(top.call(1.0, th), bot.call(1.0, th), v), sin(th) * r),
			func(u: float, v: float, p: Vector3) -> Color:
				return cf.call(2, 1.0, th0 + u * span, p), full)
	if not full:
		for th in [th0, th1]:
			surf(nr, 2, func(u: float, v: float) -> Vector3:
				var r: float = rad.call(th) * u
				return Vector3(cos(th) * r, lerpf(top.call(u, th), bot.call(u, th), v), sin(th) * r),
				func(u: float, v: float, p: Vector3) -> Color:
					return cf.call(3, u, th, p), false)


## Open two-sided sheet: fn(u, v) -> Vector3, u across, v along.
func sheet(nu: int, nv: int, fn: Callable, cf) -> void:
	surf(nu, nv, fn, cf, false, false)


## Leaf-like sheet. Grows from base along dir with `rise` (upward bend) and
## `droop`; cup curls the sides; ruffle waves the edge.
func leaf(base: Vector3, dir: Vector3, length: float, width: float, cf, rise := 0.0,
		droop := 0.0, cup := 0.0, ruffle := 0.0, shape := 0.5, nu := 6, nv := 8, upv := Vector3.UP) -> void:
	var d := dir.normalized()
	var side := d.cross(upv)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var nrm := side.cross(d).normalized()
	sheet(nu, nv, func(u: float, v: float) -> Vector3:
		var x := u * 2.0 - 1.0
		var w := width * pow(sin(PI * pow(v, shape)), 0.55) * 0.5
		var c := base + d * length * v + nrm * length * (rise * v - droop * v * v)
		var off := nrm * (cup * x * x * w + ruffle * width * pow(absf(x), 3.0) * sin(v * 23.0 + x * 3.0))
		return c + side * x * w + off, cf)


## Pieces piled in layers (bottom layer widest). piece(i) emits one piece at
## the current xf; base = centre height of the bottom layer, step = layer rise.
func heap(n: int, radius: float, base: float, step: float, piece: Callable, seed_i := 1, tilt := 25.0) -> void:
	var keep := xf
	var counts := [ceili(n * 0.55), ceili(n * 0.3), 0]
	counts[2] = maxi(0, n - counts[0] - counts[1])
	var i := 0
	for layer in 3:
		var m: int = counts[layer]
		var lr := radius * (1.0 - 0.38 * layer)
		for j in m:
			if i >= n:
				break
			var a := float(j) * 2.39996 + layer * 1.3 + h1(seed_i * 31 + i) * 0.5
			var rr := lr * sqrt((j + 0.5) / m)
			var y := base + step * layer
			var rot := Vector3(h1(i * 7 + seed_i) * tilt * 2.0 - tilt, h1(i * 13 + seed_i) * 360.0, h1(i * 17 + seed_i) * tilt * 2.0 - tilt)
			at(Vector3(cos(a) * rr, y, sin(a) * rr), rot, Vector3.ONE, keep)
			piece.call(i)
			i += 1
	xf = keep


## Merges another builder's geometry through transform t.
func append(o: MeshGen, t: Transform3D) -> void:
	var base := verts.size()
	var istart := idx.size()
	for p in o.verts:
		verts.append(t * p)
	cols.append_array(o.cols)
	uvs.append_array(o.uvs)
	uv2s.append_array(o.uv2s)
	for k in o.idx:
		idx.append(k + base)
	for pt in o._patches:
		_patches.append([pt[0] + base, pt[1], pt[2], pt[3] + istart, pt[4] + istart, pt[5]])


func aabb() -> AABB:
	if verts.is_empty():
		return AABB()
	var bb := AABB(verts[0], Vector3.ZERO)
	for p in verts:
		bb = bb.expand(p)
	return bb


# ------------------------------------------------------------------ output

func _normals() -> PackedVector3Array:
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	for pt in _patches:
		var istart: int = pt[3]
		var iend: int = pt[4]
		var k := istart
		while k < iend:
			var a := idx[k]
			var b := idx[k + 1]
			var c := idx[k + 2]
			var fnm := (verts[c] - verts[a]).cross(verts[b] - verts[a])
			nrm[a] += fnm
			nrm[b] += fnm
			nrm[c] += fnm
			k += 3
		var vb: int = pt[0]
		var cu: int = pt[1]
		var rows: int = pt[2]
		# collapsed rows (poles) share one averaged normal
		for row in [0, rows - 1]:
			var r0: int = vb + row * cu
			var p0 := verts[r0]
			var collapsed := true
			var sum := Vector3.ZERO
			for i in cu:
				sum += nrm[r0 + i]
				if verts[r0 + i].distance_squared_to(p0) > 1e-12:
					collapsed = false
			if collapsed:
				for i in cu:
					nrm[r0 + i] = sum
	for i in nrm.size():
		var l := nrm[i].length()
		nrm[i] = nrm[i] / l if l > 1e-12 else Vector3.UP
	return nrm


func empty() -> bool:
	return idx.is_empty()


## Appends this builder as a new surface of `mesh` with material `m`.
func commit(mesh: ArrayMesh, m: Material) -> void:
	if idx.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_NORMAL] = _normals()
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(mesh.get_surface_count() - 1, m)


## Highest vertex y within horizontal distance r of (x, z), or -1e9.
func top_at(x: float, z: float, r: float) -> float:
	var best := -1e9
	var r2 := r * r
	for p in verts:
		var dx := p.x - x
		var dz := p.z - z
		if dx * dx + dz * dz <= r2 and p.y > best:
			best = p.y
	return best
