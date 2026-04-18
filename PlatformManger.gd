extends Node

const PLATFORM_THICKNESS = .2
const PLATFORM_MAX_WIDHT = 10
const PLATFORM_MAX_HEIGHT = 10

# Define semisphere size and orientation
var hemi_r = 2.0
var hemi_n = Vector3(0, 1, 0).normalized()  # Points upward

class IntersectionRect:
	var p0: Vector3
	var a: Vector3   # Width edge
	var b: Vector3  # Height edge 

	func _init(p0: Vector3, a: Vector3, b: Vector3):
		self.p0 = p0
		self.a = a
		self.b = b

class PlatformPos:
	var pos : Vector3
	var x_size: float
	var y_size: float
	
	func _init(pos: Vector3, x_size: float, y_size: float) -> void:
		self.pos = pos
		self.x_size = x_size
		self.y_size = y_size
		
	func get_corners() -> Array[Vector3]:
		return [
			pos + Vector3(x_size/2, PLATFORM_THICKNESS/2 , y_size/2 ),
			pos + Vector3(x_size/2, PLATFORM_THICKNESS/2, -y_size/2),
			pos + Vector3(-x_size/2, PLATFORM_THICKNESS/2,-y_size/2),
			pos + Vector3(-x_size/2, PLATFORM_THICKNESS/2,y_size/2),
		]
	
	func get_intersection_rect() -> IntersectionRect:
		var corner = pos + Vector3(-x_size/2, PLATFORM_THICKNESS/2 , -y_size/2 );
		return IntersectionRect.new(corner, corner + Vector3(x_size, 0, 0), corner + Vector3(0,0, y_size))	
		
	func _to_string() -> String:
		return "PlatformPos(pos=%s, x=%s, y=%s)" % [pos, x_size, y_size]
	
	
	
var start_platform = PlatformPos.new(Vector3(0,0,0), 3, 3)

func can_jump_to_platform(position: Vector3, platform: PlatformPos) -> bool:
	return true
	var rect = platform.get_intersection_rect()
	# Calculate percent of platform that's inside the sphere
	var percent = HemisphereRectIntersection.calculate_intersection_percent(
		position, hemi_r, hemi_n, rect.p0, rect.a, rect.b
	)
	return percent >= 10
	

func _ready() -> void:
	generate()

func generate()-> void:
	for e in get_children():
		self.remove_child(e)
	var current: PlatformPos = start_platform
	var num_platforms = 10
	var current_platforms = 0
	while current_platforms < num_platforms :
		print("Generate platform:", current_platforms)
		var corner = current.get_corners().pick_random()
		var w = randf_range(1, PLATFORM_MAX_WIDHT)
		var h = randf_range(1, PLATFORM_MAX_HEIGHT)
		var direction = (corner - current.pos).normalized().sign()
		direction.y = 1 #1 if bool(randi() & 1)  else -1
		var next = PlatformPos.new(
			current.pos + Vector3(randf_range(1+ current.x_size/2, hemi_r + current.x_size/2),randf_range(1, hemi_r),randf_range(1+ current.y_size/2, hemi_r+ current.y_size/2)) * direction,
			w, h)
		if can_jump_to_platform(corner, next):
			instantiate(next);
			current = next
			current_platforms += 1
		
	#var hemi_c = Vector3(0, 0, 0)
	#
	#var rect_p0 = Vector3(-1.5, 1.2, -1.0)
	#var rect_a  = Vector3(3.0, 0.5, 0.0)   # Width edge
	#var rect_b  = Vector3(0.0, -0.2, 0)  # Height edge (slightly tilted)
	#
		## Calculate
	#var percent = HemisphereRectIntersection.calculate_intersection_percent(
		#hemi_c, hemi_r, hemi_n, rect_p0, rect_a, rect_b
	#)
	## Spawn debug visuals
	#HemisphereRectIntersection.add_debug_visualization(
		#get_tree().current_scene, hemi_c, hemi_r, hemi_n, rect_p0, rect_a, rect_b, percent
	#)

const PlatformScene=preload("res://platform.tscn")

func instantiate(pp :PlatformPos)->void:
	var node:StaticBody3D=PlatformScene.instantiate()
	self.add_child(node)
	node.global_position=pp.pos
	node.scale = Vector3(pp.x_size, PLATFORM_THICKNESS , pp.y_size)
