extends Node3D

@export var image_sprite: Sprite3D #

@export var bullet_scene: PackedScene
@export var red_bullet_scene: PackedScene
@export var blue_bullet_scene: PackedScene
@export var black_bullet_scene: PackedScene
@export var bullet_speed: float = 20.0

@export var normal_label: Label
@export var red_label: Label
@export var blue_label: Label
@export var black_label: Label

var bullet_scenes = []
var erabu = 0

var bullet_names = ["赤", "青", "緑", "黄"]

var bullet_counts = {"赤": 0,"青": 0,"緑": 0,"黄": 0}

func _ready():
	bullet_scenes = [bullet_scene,red_bullet_scene, blue_bullet_scene, black_bullet_scene]
	update_count_display()
func _input(event):
	if event.is_action_pressed("kirikae"):
		erabu = (erabu+1) % bullet_scenes.size()                      
	if event.is_action_pressed("shoot"):
		shoot_bullet()
	if event.is_action_pressed("kettei"):
		print("「kettei」キーが押されました！")
		hyouji()
func shoot_bullet():
	var current_bullet_name = bullet_names[erabu]
	bullet_counts[current_bullet_name] += 1
	
	# UIの表示を更新する
	update_count_display()
	var bullet : RigidBody3D= bullet_scenes[erabu].instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = self.global_transform
	bullet.apply_impulse(Vector3.FORWARD * bullet_speed)

func update_count_display():
	# 各ラベルのテキストを現在のカウント数で更新する
	if normal_label:
		normal_label.text = "赤弾: " + str(bullet_counts["赤"])
	if red_label:
		red_label.text = "青弾: " + str(bullet_counts["青"])
	if blue_label:
		blue_label.text = "緑弾: " + str(bullet_counts["緑"])
	if black_label:
		black_label.text = "黄弾: " + str(bullet_counts["黄"])

func hyouji():
	
	
	if image_sprite:
		
		image_sprite.visible = not image_sprite.visible # 表示・非表示を切り替え
		
