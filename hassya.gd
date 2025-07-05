extends Node3D

# --- 変数宣言（すべてここにまとめる） ---

# 画像表示用
@export var image_sprite: Sprite3D

# 弾の発射用
@export var bullet_scene: PackedScene
@export var red_bullet_scene: PackedScene
@export var blue_bullet_scene: PackedScene
@export var black_bullet_scene: PackedScene
@export var bullet_speed: float = 20.0

# UIラベル用
@export var normal_label: Label
@export var red_label: Label
@export var blue_label: Label
@export var black_label: Label

# 【追記】フタの開閉用
@export var lid_node: Node3D
@export var lid_open_marker: Marker3D
@export var lid_closed_marker: Marker3D

# 内部で使う変数
var bullet_scenes = []
var erabu = 0
var bullet_names = ["赤", "青", "緑", "黄"]
var bullet_counts = {"赤": 0, "青": 0, "緑": 0, "黄": 0}

#鍋震え
@export var pot_body_node: Node3D

# --- 関数の定義 ---

func _ready():
	# 既存の処理
	bullet_scenes = [bullet_scene, red_bullet_scene, blue_bullet_scene, black_bullet_scene]
	update_count_display()
	
	# 【追記】フタを必ず「開いた位置」からスタートさせる
	if lid_node and lid_open_marker:
		lid_node.global_transform = lid_open_marker.global_transform

func _input(event):
	# 弾の切り替え
	if event.is_action_pressed("kirikae"):
		erabu = (erabu + 1) % bullet_scenes.size()
	
	# 弾の発射
	if event.is_action_pressed("shoot"):
		shoot_bullet()
	
	
	# 【修正】Enterキーでフタを閉めるように変更
	if event.is_action_pressed("ui_accept"):
		close_lid()

func shoot_bullet():
	var current_bullet_name = bullet_names[erabu]
	bullet_counts[current_bullet_name] += 1
	
	update_count_display()
	
	var bullet: RigidBody3D = bullet_scenes[erabu].instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = self.global_transform
	bullet.apply_central_impulse(Vector3.FORWARD.rotated(Vector3.UP, global_rotation.y) * bullet_speed)

func update_count_display():
	if normal_label:
		normal_label.text = "赤弾: " + str(bullet_counts["赤"])
	if red_label:
		red_label.text = "青弾: " + str(bullet_counts["青"])
	if blue_label:
		blue_label.text = "緑弾: " + str(bullet_counts["緑"])
	if black_label:
		black_label.text = "黄弾: " + str(bullet_counts["黄"])

# 【追記】フタを閉めるアニメーションを実行する関数
func close_lid():
	# 必要なノードが設定されているか確認
	if not (lid_node and lid_closed_marker):
		print("エラー: Lid NodeかLid Closed Markerがインスペクターで設定されていません。")
		return

	# 新しいTween（アニメーション）を作成
	var tween = create_tween()
	# 位置と回転のアニメーションを並行して実行
	tween.set_parallel(true)
	
	# 位置を目標マーカーの位置まで1秒かけて動かす
	tween.tween_property(lid_node, "global_position", lid_closed_marker.global_position, 1.0)
	# 回転を目標マーカーの回転まで1秒かけて動かす
	tween.tween_property(lid_node, "global_rotation", lid_closed_marker.global_rotation, 1.0)
	await tween.finished
	await shake_pot()
	hyouji()
	
func hyouji():
	if image_sprite:
		image_sprite.visible = not image_sprite.visible

# 【追記】鍋を揺らすアニメーションを実行する関数
func shake_pot():
	# 鍋本体が設定されていなければ何もしない
	if not pot_body_node:
		print("エラー: Pot Body Nodeが設定されていません。")
		return
	var i=0
	# 新しいTweenを作成
	var tween = create_tween()
	# ループ回数を設定（例：5回ガタガタさせる）
	tween.set_loops(30)
	i=i+5
	# 0.05秒かけて少し右に傾ける
	tween.tween_property(pot_body_node, "rotation_degrees:z", 2.0+i, 0.05)
	# 0.05秒かけて少し左に傾ける
	tween.tween_property(pot_body_node, "rotation_degrees:z", -2.0-i, 0.05)
	
	# ↑これを5回繰り返す

	# アニメーションが終わるのを待つ
	await tween.finished
	
	# 最後に鍋の傾きをまっすぐに戻す
	pot_body_node.rotation_degrees.z = 0
