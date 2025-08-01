extends Node3D

# --- 変数宣言 (UI関連をシンプル化) ---
@export var explosion_scene: PackedScene
@export var bullet_scene: PackedScene
@export var red_bullet_scene: PackedScene
@export var blue_bullet_scene: PackedScene
@export var black_bullet_scene: PackedScene
@export var bullet_speed: float = 20.0
@export var potato_scene: PackedScene
@export var carrot_scene: PackedScene
@export var chunk_scene: PackedScene
@export var info_label: Label # 【変更】UIラベルを1つに統合
@export var naan_scene: PackedScene
@export var naan_spawn_marker: Marker3D
@export var lid_node: Node3D
@export var lid_open_marker: Marker3D
@export var lid_closed_marker: Marker3D
@export var pot_body_node: Node3D
@export var finished_curry_mesh: Node3D
@export var shoot_sound_player :AudioStreamPlayer
@export var shoot_timer: Timer
@export var timer_label: Label

# --- 内部で使う変数 ---
var bullet_scenes = []
var erabu = 0
var bullet_names = ["赤", "青", "緑", "黄"]
var bullet_counts = {"赤": 0, "青": 0, "緑": 0, "黄": 0}

var is_cutting_phase: bool = true
var material_objects = []
var time_is_up: bool = false
var is_cooking: bool = false

# --- ▼▼▼【追加】カット用の新しい変数 ▼▼▼ ---
var cut_shake_count: int = 0      # 振った回数をカウント
const REQUIRED_SHAKES: int = 10  # 1つの材料を切るのに必要な振り回数
# --- ▲▲▲ 追加ここまで ▲▲▲ ---


# --- 関数の定義 ---

func _ready():
	bullet_scenes = [bullet_scene, red_bullet_scene, blue_bullet_scene, black_bullet_scene]
	
	if lid_node and lid_open_marker:
		lid_node.global_transform = lid_open_marker.global_transform
		
	# コントローラーからの合図を接続 (変更なし)
	PicoWController.cut_action_detected.connect(_on_cut_action_detected)
	PicoWController.button_pressed.connect(_on_button_pressed)
	PicoWController.seasoning_added.connect(_on_controller_shaken)
	
	if finished_curry_mesh:
		finished_curry_mesh.visible = false
		
	is_cutting_phase = true
	spawn_materials() # 材料を出現させ、UIを更新
	
	# ラベルの表示を初期化
	if info_label:
		info_label.visible = false
	if timer_label:
		timer_label.visible = false

# --- ▼▼▼【追加】デバッグ用のキー入力関数 ▼▼▼ ---
func _input(event):
	# カットフェーズ中で、"cut_material" (Cキー) が押されたら
	if is_cutting_phase and event.is_action_pressed("cut_material"):
		print("DEBUG: Cutting with 'C' key.")
		cut_one_material() # 10回振ったことにして、即座にカットする
# --- ▲▲▲ 追加ここまで ▲▲▲ ---


# --- ▼▼▼【ここから関数群を新仕様に合わせて変更・追加】▼▼▼ ---

# 【変更】「強い振り」の合図でシェイクカウントを増やす
func _on_cut_action_detected():
	# カットフェーズではない、または調理中なら何もしない
	if not is_cutting_phase or is_cooking:
		return
	
	# 材料が残っていればカウントを増やす
	if not material_objects.is_empty():
		cut_shake_count += 1
		print("Shake count: ", cut_shake_count)
		
		# もし必要な回数だけ振ったら...
		if cut_shake_count >= REQUIRED_SHAKES:
			cut_one_material() # 実際にカットする
			cut_shake_count = 0 # カウンターをリセット
		
		# UIを更新して、残り回数を表示
		update_info_label()

# 【新設】材料を1つカットする共通処理
func cut_one_material():
	# 材料が残っていなければ何もしない
	if material_objects.is_empty():
		return
		
	var material_to_cut = material_objects.pop_back()
	var cut_position = material_to_cut.global_position
	material_to_cut.queue_free()

	if chunk_scene:
		for i in range(8):
			var chunk = chunk_scene.instantiate()
			add_child(chunk)
			chunk.global_transform.origin = cut_position
			var random_dir = Vector3(randf_range(-1, 1), randf_range(1.2, 2.0), randf_range(-1, 1)).normalized()
			chunk.apply_central_impulse(random_dir * randf_range(0.5, 2))
	
	# もし、これで全ての材料を切り終えたら
	if material_objects.is_empty():
		is_cutting_phase = false
		
		# UIを「調味料モード」に切り替え
		update_info_label()
		
		# タイマーを開始
		if shoot_timer:
			shoot_timer.start(30.0)
		if timer_label:
			timer_label.visible = true
	else:
		# まだ材料が残っているならUIを更新
		update_info_label()

# 【新設】「ボタン押し」の合図で調味料を切り替える関数
func _on_button_pressed():
	# カットフェーズ中、または調理中なら何もしない
	if is_cutting_phase or is_cooking:
		return
	
	# 調味料を切り替える
	erabu = (erabu + 1) % bullet_scenes.size()
	# UIを更新
	update_info_label()
	print("Seasoning changed to: ", bullet_names[erabu])

# 【変更】「普通の振り」の合図で調味料を発射する関数
func _on_controller_shaken(amount):
	# カットフェーズ中、または調理中なら何もしない
	if is_cutting_phase or is_cooking:
		return

	# shoot_bullet関数を呼び出す
	shoot_bullet(amount)

# UIラベルの表示をまとめて更新する新しい関数
func update_info_label():
	if not info_label:
		return
	
	info_label.visible = true
	
	if is_cutting_phase:
		# 【変更】表示内容をシェイクカウントに合わせる
		if not material_objects.is_empty():
			var remaining_shakes = REQUIRED_SHAKES - cut_shake_count
			info_label.text = "振ってカット！ (あと %d 回)" % remaining_shakes
		else:
			# 全てカットし終わった直後の表示
			info_label.text = "カット完了！"
	else:
		info_label.text = "種類: " + bullet_names[erabu]

# 【変更】shoot_bullet関数は、振りの強さ(amount)を受け取るようにする（将来的な拡張のため）
func shoot_bullet(amount):
	var current_bullet_name = bullet_names[erabu]
	bullet_counts[current_bullet_name] += 1
	
	var bullet: RigidBody3D = bullet_scenes[erabu].instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = self.global_transform
	bullet.apply_central_impulse(Vector3.FORWARD.rotated(Vector3.UP, global_rotation.y) * bullet_speed)
	shoot_sound_player.play()

# (以下、carryscene, close_lid, open_lid, shake_pot, evaluate_curry は変更なし)
# ... (変更のない関数は省略) ...
		
func carryscene():
	if is_cooking:
		return
	is_cooking = true
	
	if shoot_timer and not shoot_timer.is_stopped():
		shoot_timer.stop()
	
	if timer_label:
		timer_label.visible = false
	if info_label:
		info_label.visible = false
		
	if naan_scene and naan_spawn_marker:
		var naan_instance = naan_scene.instantiate()
		get_tree().current_scene.add_child(naan_instance)
		naan_instance.global_transform = naan_spawn_marker.global_transform
		
	await close_lid()
	await shake_pot()
	
	if finished_curry_mesh:
		var r_val = float(bullet_counts["赤"] + bullet_counts["黄"])
		var g_val = float(bullet_counts["緑"] + bullet_counts["黄"])
		var b_val = float(bullet_counts["青"])
		
		var final_color: Color
		var total_val = r_val + g_val + b_val

		if total_val > 0:
			final_color = Color(r_val / total_val, g_val / total_val, b_val / total_val)
		else:
			final_color = Color("8B4513")

		var curry_base_node_name = "base"
		var curry_base_node = finished_curry_mesh.get_node_or_null(curry_base_node_name)

		if curry_base_node and curry_base_node is MeshInstance3D:
			var base_material = curry_base_node.get_surface_override_material(0)
			if not base_material and curry_base_node.mesh:
				base_material = curry_base_node.mesh.surface_get_material(0)

			if base_material:
				var unique_material = base_material.duplicate()
				if unique_material is StandardMaterial3D:
					unique_material.albedo_color = final_color
					curry_base_node.set_surface_override_material(0, unique_material)
		
		finished_curry_mesh.visible = true

	await open_lid()
	
	var evaluation = evaluate_curry()
	ScoreManager.curry_evaluation_text = evaluation
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://result.tscn")

func close_lid():
	if not (lid_node and lid_closed_marker): return
	var tween = create_tween()
	tween.tween_property(lid_node, "global_transform", lid_closed_marker.global_transform, 1.0)
	await tween.finished

func open_lid():
	if not (lid_node and lid_open_marker): return
	var tween = create_tween()
	tween.tween_property(lid_node, "global_transform", lid_open_marker.global_transform, 1.0)
	await tween.finished
	
	if explosion_scene:
		var explosion_instance = explosion_scene.instantiate()
		if pot_body_node:
			explosion_instance.global_position = pot_body_node.global_position
		add_child(explosion_instance)

func shake_pot():
	if not pot_body_node: return
	var i=0
	var tween = create_tween()
	tween.set_loops(30)
	i=i+5
	tween.tween_property(pot_body_node, "rotation_degrees:z", 2.0+i, 0.05)
	tween.tween_property(pot_body_node, "rotation_degrees:z", -2.0-i, 0.05)
	
	await tween.finished
	pot_body_node.rotation_degrees.z = 0
	
func evaluate_curry():
	var red = bullet_counts["赤"]
	var blue = bullet_counts["青"]
	var green = bullet_counts["緑"]
	var yellow = bullet_counts["黄"]
	
	print(bullet_counts)
	
	if red > 30 && blue > 30&& green > 30&& red > 30:
		return "もっと調味料が欲しい\n無味のコクなしカレー！"
	elif red > 300:
		return "辛さの向こう側を見た！\n超絶スパイシーカレー！"
	elif blue > 200:
		return "海の恵みを全て凝縮！\n濃厚シーフードカレー！"
	elif green > 0 && yellow > 0 && red == 0 && blue == 0:
		return "お野菜たっぷり！\nヘルシーで優しい味のカレー！"
	elif red == 0 && blue == 0 && green == 0 && yellow == 0:
		return "何も入れなかった…\nこれはただのベースです。"
	else:
		return "いろんな味がする…\n新時代のスタンダードカレー！"

# 【変更】spawn_materialsに関数を追加
func spawn_materials():
	for mat in material_objects:
		mat.queue_free()
	material_objects.clear()

	if potato_scene:
		var potato = potato_scene.instantiate()
		add_child(potato)
		potato.position = Vector3(0.2,3, -3)
		material_objects.append(potato)

	if carrot_scene:
		var carrot = carrot_scene.instantiate()
		add_child(carrot)
		carrot.position = Vector3(0.3, 3, -3)
		material_objects.append(carrot)

	# 【追加】新しい材料を出すときに、シェイクカウントをリセット
	cut_shake_count = 0

	# UIを更新
	update_info_label()

func _process(delta):
	if not is_cutting_phase and shoot_timer and not shoot_timer.is_stopped():
		if timer_label:
			timer_label.text = "残り時間: %.1f" % shoot_timer.time_left
			
func _on_timer_timeout() -> void:
	print("時間切れ！")
	time_is_up = true
	
	if timer_label:
		timer_label.text = "時間切れ！"
	
	carryscene()
