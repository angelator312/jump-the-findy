## Computes exact intersection percentage between a 3D hemisphere and an arbitrarily oriented rectangle.
## Includes debug visualization tools for runtime inspection.
class_name HemisphereRectIntersection
extends RefCounted

## Main entry point. Returns intersection as a percentage (0.0 to 100.0).
static func calculate_intersection_percent(
	hemi_center: Vector3, hemi_radius: float, hemi_normal: Vector3,
	rect_corner: Vector3, rect_edge_a: Vector3, rect_edge_b: Vector3
) -> float:
	if hemi_radius <= 0.0 or rect_edge_a.length_squared() < 1e-10 or rect_edge_b.length_squared() < 1e-10:
		return 0.0

	var rect_normal = rect_edge_a.cross(rect_edge_b).normalized()
	var d_plane = abs((rect_corner - hemi_center).dot(rect_normal))
	if d_plane >= hemi_radius:
		return 0.0

	var r_circle = sqrt(max(0.0, hemi_radius * hemi_radius - d_plane * d_plane))
	var circle_center_3d = hemi_center + ((rect_corner - hemi_center).dot(rect_normal)) * rect_normal

	var w = rect_edge_a.length()
	var h = rect_edge_b.length()
	var u = rect_edge_a / w
	var v = rect_normal.cross(u).normalized()

	var cx = (circle_center_3d - rect_corner).dot(u)
	var cy = (circle_center_3d - rect_corner).dot(v)
	var circle_center_2d = Vector2(cx, cy)

	var A = u.dot(hemi_normal)
	var B = v.dot(hemi_normal)
	var D = (rect_corner - hemi_center).dot(hemi_normal)

	# FIX: Explicitly build typed array to avoid GDScript parser mismatch
	var rect_2d: Array[Vector2] = []
	rect_2d.append(Vector2(0.0, 0.0))
	rect_2d.append(Vector2(w, 0.0))
	rect_2d.append(Vector2(w, h))
	rect_2d.append(Vector2(0.0, h))

	var clipped = _clip_polygon_by_halfplane(rect_2d, A, B, D)
	if clipped.is_empty():
		return 0.0

	var intersect_area = _circle_polygon_intersection_area(clipped, circle_center_2d, r_circle)
	var rect_area = w * h
	return clampf((intersect_area / rect_area) * 100.0, 0.0, 100.0)

## Adds debug meshes to `parent` showing the hemisphere, rectangle, and intersection area.
static func add_debug_visualization(
	parent: Node3D,
	hemi_center: Vector3, hemi_radius: float, hemi_normal: Vector3,
	rect_corner: Vector3, rect_edge_a: Vector3, rect_edge_b: Vector3,
	intersection_percent: float
) -> Node3D:
	var debug = Node3D.new()
	debug.name = "HemisphereRectDebug"
	parent.add_child(debug)

	# 1. Hemisphere Mesh (procedural)
	var hemi_mesh = _create_hemisphere_mesh(hemi_radius, 32)
	var hemi_mi = MeshInstance3D.new()
	hemi_mi.mesh = hemi_mesh
	hemi_mi.position = hemi_center
	
	var y_axis = hemi_normal.normalized()
	var x_axis = Vector3(0, 1, 0).cross(y_axis)
	if x_axis.length() < 1e-5: x_axis = Vector3(1, 0, 0)
	x_axis = x_axis.normalized()
	var z_axis = y_axis.cross(x_axis)
	hemi_mi.transform.basis = Basis(x_axis, y_axis, z_axis)
	
	var hemi_mat = StandardMaterial3D.new()
	hemi_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.25)
	hemi_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hemi_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hemi_mi.material_override = hemi_mat
	debug.add_child(hemi_mi)

	# 2. Rectangle & Intersection Polygon via ImmediateMesh
	var imm = ImmediateMesh.new()
	var rect_normal = rect_edge_a.cross(rect_edge_b).normalized()
	var w = rect_edge_a.length()
	var h = rect_edge_b.length()
	var u = rect_edge_a / w
	var v = rect_normal.cross(u).normalized()

	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	imm.surface_set_color(Color(1.0, 1.0, 0.2, 0.8))
	for i in 4:
		var c = Vector2(w * (i & 1), h * ((i >> 1) & 1))
		var n = Vector2(w * ((i + 1) & 1), h * (((i + 1) >> 1) & 1))
		imm.surface_add_vertex(rect_corner + c.x * u + c.y * v)
		imm.surface_add_vertex(rect_corner + n.x * u + n.y * v)
	imm.surface_end()

	var A = u.dot(hemi_normal)
	var B = v.dot(hemi_normal)
	var D = (rect_corner - hemi_center).dot(hemi_normal)
	
	var rect_2d: Array[Vector2] = []
	rect_2d.append(Vector2(0.0, 0.0))
	rect_2d.append(Vector2(w, 0.0))
	rect_2d.append(Vector2(w, h))
	rect_2d.append(Vector2(0.0, h))
	
	var clipped = _clip_polygon_by_halfplane(rect_2d, A, B, D)

	if clipped.size() >= 3:
		imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		imm.surface_set_color(Color(0.2, 0.9, 0.4, 0.65))
		var p0 = rect_corner + clipped[0].x * u + clipped[0].y * v
		for i in range(1, clipped.size() - 1):
			var p1 = rect_corner + clipped[i].x * u + clipped[i].y * v
			var p2 = rect_corner + clipped[i+1].x * u + clipped[i+1].y * v
			imm.surface_add_vertex(p0)
			imm.surface_add_vertex(p1)
			imm.surface_add_vertex(p2)
		imm.surface_end()

	var imm_mat = StandardMaterial3D.new()
	imm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	imm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	imm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var imm_mi = MeshInstance3D.new()
	imm_mi.mesh = imm
	imm_mi.material_override = imm_mat
	debug.add_child(imm_mi)

	# 3. Percentage Label
	var label = Label3D.new()
	label.text = "%.1f%%" % intersection_percent
	label.outline_size = 1
	label.outline_modulate = Color.BLACK  # ✅ FIXED: Godot 4 uses 'outline_modulate'
	label.font_size = 28
	label.position = rect_corner + rect_edge_a * 0.5 + rect_edge_b * 0.5 + rect_normal * 0.3
	debug.add_child(label)

	return debug

# ------------------------------------------------------------------
# Internal Geometry Helpers
# ------------------------------------------------------------------
static func _clip_polygon_by_halfplane(poly: Array[Vector2], A: float, B: float, D: float) -> Array[Vector2]:
	var output: Array[Vector2] = []
	var n = poly.size()
	if n == 0: return output
	for i in range(n):
		var curr = poly[i]
		var prev = poly[(i - 1 + n) % n]
		var cv = A * curr.x + B * curr.y + D
		var pv = A * prev.x + B * prev.y + D
		if cv >= 0.0:
			if pv < 0.0:
				var t = pv / (pv - cv)
				output.append(prev + t * (curr - prev))
			output.append(curr)
		elif pv >= 0.0:
			var t = pv / (pv - cv)
			output.append(prev + t * (curr - prev))
	return output

static func _circle_polygon_intersection_area(poly: Array[Vector2], center: Vector2, r: float) -> float:
	var area = 0.0; var r2 = r * r; var n = poly.size()
	for i in range(n):
		var p1 = poly[i] - center; var p2 = poly[(i + 1) % n] - center
		var da = p1.length_squared(); var db = p2.length_squared()
		var cross = p1.x * p2.y - p1.y * p2.x; var dot = p1.x * p2.x + p1.y * p2.y
		if da <= r2 and db <= r2:
			area += cross * 0.5; continue
		var seg_len2 = (p2 - p1).length_squared()
		if seg_len2 < 1e-12: continue
		var t = -dot / seg_len2; var closest = p1 + t * (p2 - p1)
		if closest.length_squared() >= r2:
			area += 0.5 * r2 * atan2(cross, dot); continue
		var dx = p2.x - p1.x; var dy = p2.y - p1.y
		var Ac = dx*dx + dy*dy; var Bc = 2.0*(p1.x*dx + p1.y*dy); var Cc = p1.x*p1.x + p1.y*p1.y - r2
		var disc = Bc*Bc - 4.0*Ac*Cc
		if disc < 0.0: area += 0.5 * r2 * atan2(cross, dot); continue
		var sd = sqrt(disc)
		var t1 = (-Bc - sd) / (2.0*Ac); var t2 = (-Bc + sd) / (2.0*Ac)
		var i1 = p1 + t1*(p2-p1); var i2 = p1 + t2*(p2-p1)
		if t1 > t2: var tmp = i1; i1 = i2; i2 = tmp
		area += 0.5*(p1.x*i1.y - p1.y*i1.x)
		area += 0.5*r2*atan2(i1.x*i2.y - i1.y*i2.x, i1.x*i2.x + i1.y*i2.y)
		area += 0.5*(i2.x*p2.y - i2.y*p2.x)
	return abs(area)

static func _create_hemisphere_mesh(radius: float, segments: int) -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tau = 2.0 * PI
	for j in range(segments):
		for i in range(segments):
			var t1 = float(i) / segments * tau
			var t2 = float(i + 1) / segments * tau
			var p1 = float(j) / segments * PI * 0.5
			var p2 = float(j + 1) / segments * PI * 0.5
			var v1 = Vector3(sin(p1)*cos(t1), cos(p1), sin(p1)*sin(t1)) * radius
			var v2 = Vector3(sin(p1)*cos(t2), cos(p1), sin(p1)*sin(t2)) * radius
			var v3 = Vector3(sin(p2)*cos(t1), cos(p2), sin(p2)*sin(t1)) * radius
			var v4 = Vector3(sin(p2)*cos(t2), cos(p2), sin(p2)*sin(t2)) * radius
			st.add_vertex(v1); st.add_vertex(v3); st.add_vertex(v2)
			st.add_vertex(v2); st.add_vertex(v3); st.add_vertex(v4)
	# Base cap
	for i in range(segments):
		var t1 = float(i) / segments * tau
		var t2 = float(i + 1) / segments * tau
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(t1), 0.0, sin(t1)) * radius)
		st.add_vertex(Vector3(cos(t2), 0.0, sin(t2)) * radius)
	st.generate_normals()
	return st.commit()
