extends Node3D

@export var bullet_scene: PackedScene
@export var red_bullet_scene: PackedScene
@export var blue_bullet_scene: PackedScene
@export var black_bullet_scene: PackedScene
@export var bullet_speed: float = 20.0

var bullet_scenes = []
var erabu = 0

func _ready():
	bullet_scenes = [bullet_scene,red_bullet_scene, blue_bullet_scene, black_bullet_scene]

func _input(event):
	if event.is_action_pressed("kirikae"):
		erabu = (erabu+1) % bullet_scenes.size()                      
	if event.is_action_pressed("shoot"):
		shoot_bullet()

func shoot_bullet():
	var bullet : RigidBody3D= bullet_scenes[erabu].instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = self.global_transform
	bullet.apply_impulse(Vector3.FORWARD * bullet_speed)

	
