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

#カレー
@export var finished_curry_mesh: Node3D

# --- 関数の定義 ---

func _ready():
	# 既存の処理
	bullet_scenes = [bullet_scene, red_bullet_scene, blue_bullet_scene, black_bullet_scene]
	update_count_display()
	
	# 【追記】フタを必ず「開いた位置」からスタートさせる
	if lid_node and lid_open_marker:
		lid_node.global_transform = lid_open_marker.global_transform
		
	# 【この一行を追加！】コントローラーの合図と、これから作る関数を結びつける
	PicoWController.seasoning_added.connect(_on_controller_shaken)
	#カレーの表示
	if finished_curry_mesh:
		finished_curry_mesh.visible = false

func _input(event):
	# 弾の切り替え
	if event.is_action_pressed("kirikae"):
		erabu = (erabu + 1) % bullet_scenes.size()
	
	# 弾の発射
	if event.is_action_pressed("shoot"):
		shoot_bullet()
	
	
	# Enterキーでフタを閉めるように変更
	if event.is_action_pressed("ui_accept"):
		carryscene()

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
		
func carryscene():
	await close_lid()
	await shake_pot()
	
	if finished_curry_mesh:
		finished_curry_mesh.visible = true

	await open_lid()
	
	# --- ここから下が確定コード ---
	
	# (1) 評価を計算する
	var evaluation = evaluate_curry()
	
	# (2) 計算した評価を、グローバルな場所にある ScoreManager の変数に保存する
	ScoreManager.curry_evaluation_text = evaluation
	await get_tree().create_timer(5.0).timeout
	# (3) リザルトシーンに移動する
	get_tree().change_scene_to_file("res://result.tscn")
	

func close_lid():
	if not (lid_node and lid_closed_marker): return
	var tween = create_tween()
	tween.tween_property(lid_node, "global_transform", lid_closed_marker.global_transform, 1.0)
	await tween.finished # アニメーションが終わるのを待つ
	
# フタを開ける
func open_lid():
	if not (lid_node and lid_open_marker):
		print("エラー: Lid NodeかLid Open Markerが設定されていません。")
		return

	var tween = create_tween()
	
	tween.tween_property(lid_node, "global_transform", lid_open_marker.global_transform, 1.0)
	await tween.finished 
	

#鍋を揺らすアニメーション
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
	
# コントローラーが振られた、という合図を受け取るための関数
func _on_controller_shaken(amount):
	print("コントローラーからの合図を受信！ 強さ: ", amount)
	
	# 既存の弾発射関数を呼び出す！
	shoot_bullet()
func evaluate_curry():
	var red = bullet_counts["赤"]
	var blue = bullet_counts["青"]
	var green = bullet_counts["緑"]
	var yellow = bullet_counts["黄"]
	
	if red > 10 && blue > 5:
		return "情熱と冷静さが生んだ\n奇跡のスパイシーカレー！"
	elif red > 15:
		return "辛さの向こう側を見た！\n超絶スパイシーカレー！"
	elif blue > 15:
		return "海の恵みを全て凝縮！\n濃厚シーフードカレー！"
	elif green > 0 && yellow > 0 && red == 0 && blue == 0:
		return "お野菜たっぷり！\nヘルシーで優しい味のカレー！"
	elif red == 0 && blue == 0 && green == 0 && yellow == 0:
		return "何も入れなかった…\nこれはただのベースです。"
	else:
		return "いろんな味がする…\n新時代のスタンダードカレー！"
