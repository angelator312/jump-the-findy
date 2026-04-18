extends Node

func _ready() -> void:
	instantiate(Vector3(0,10,0),Vector3(1,.2,1));
	instantiate(Vector3(2,1,3),Vector3(1,.2,1));
	instantiate(Vector3(1,3,0),Vector3(1,.2,1));
	instantiate(Vector3(0,5,0),Vector3(1,.2,1));

const PlatformScene=preload("res://platform.tscn")

func instantiate(pos:Vector3,sz:Vector3)->void:
	var node:StaticBody3D=PlatformScene.instantiate()
	get_tree().current_scene.add_child(node)
	node.global_position=pos
	node.scale=sz
