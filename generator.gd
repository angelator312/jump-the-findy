extends Node3D

const RANDOMS = preload("uid://ceasjwtr4lu7w")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var files:Array[String]
	files.assign(DirAccess.open("res://randoms").get_files())
	print(files)
	files=files.filter(func(e:String):return !e.ends_with(".import"))
	var file=files[randi_range(0,files.size()-1)]
	print(files)
	var e:Node3D= load("res://randoms/"+file).instantiate()
	self.add_child(e)
