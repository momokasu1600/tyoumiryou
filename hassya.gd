extends Node3D

# --- 変数宣言 ---
@export var explosion_scene: PackedScene
# 弾の発射用
@export var bullet_scene: PackedScene
@export var red_bullet_scene: PackedScene
@export var blue_bullet_scene: PackedScene
@export var black_bullet_scene: PackedScene
@export var bullet_speed: float = 20.0

# 材料シーンとカケラシーン
@export var potato_scene: PackedScene
@export var carrot_scene: PackedScene
@export var chunk_scene: PackedScene

# UIラベル用
@export var cutting_label: Label
@export var normal_label: Label
@export var red_label: Label
@export var blue_label: Label
@export var black_label: Label

# ナーン用
@export var naan_scene: PackedScene
@export var naan_spawn_marker: Marker3D

# フタ用
@export var lid_node: Node3D
@export var lid_open_marker: Marker3D
@export var lid_closed_marker: Marker3D

# 鍋本体とカレー用
@export var pot_body_node: Node3D
@export var finished_curry_mesh: Node3D

# --- 内部で使う変数 ---
var bullet_scenes = []
var erabu = 0
var bullet_names = ["赤", "青", "緑", "黄"]
var bullet_counts = {"赤": 0, "青": 0, "緑": 0, "黄": 0}

# 今が「切るフェーズ」かどうかを管理する変数
var is_cutting_phase: bool = true
# 出現させた材料オブジェクトを覚えておく配列
var material_objects = []

# --- 関数の定義 ---

func _ready():
	# 既存の処理
	bullet_scenes = [bullet_scene, red_bullet_scene, blue_bullet_scene, black_bullet_scene]
	
	# 【追記】フタを必ず「開いた位置」からスタートさせる
	if lid_node and lid_open_marker:
		lid_node.global_transform = lid_open_marker.global_transform
		
	# 【この一行を追加！】コントローラーの合図と、これから作る関数を結びつける
	PicoWController.seasoning_added.connect(_on_controller_shaken)
	#カレーの表示
	if finished_curry_mesh:
		finished_curry_mesh.visible = false
		
	is_cutting_phase = true
	spawn_materials() # 材料を出現させる
	
	# ラベルの表示を初期化
	if cutting_label:
		cutting_label.visible = true
	if normal_label:
		normal_label.visible = false

func _input(event):
	if is_cutting_phase:
		if event.is_action_pressed("cut_material"): # Cキーが押されたら
			# 材料がまだ残っているかチェック
			if not material_objects.is_empty():
				# 配列の最後から材料を一つ取り出す
				var material_to_cut = material_objects.pop_back()
				var cut_position = material_to_cut.global_position
				material_to_cut.queue_free() # 元の材料を消す

				# カケラを生成して飛び散らせる
				if chunk_scene:
					for i in range(8): # 8個のカケラを生成
						var chunk = chunk_scene.instantiate()
						add_child(chunk)
						chunk.global_transform.origin = cut_position
						var random_dir = Vector3(randf_range(-1, 1), randf_range(1.2, 2.0), randf_range(-1, 1)).normalized()
						chunk.apply_central_impulse(random_dir * randf_range(0.5, 2))
				
				# UIを更新
				if cutting_label:
					cutting_label.text = "Cキーで材料を切ろう！ (残り %d 個)" % material_objects.size()
			
			# もし、もう切るべき材料が残っていなければ…
			if material_objects.is_empty():
				is_cutting_phase = false # フェーズを発射モードに切り替える！
				if cutting_label:
					cutting_label.text = "発射OK！"
					await get_tree().create_timer(1.5).timeout
					cutting_label.visible = false
				if normal_label:
					normal_label.visible = true # 弾数ラベルを表示
	else:				
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
	
	
	var bullet: RigidBody3D = bullet_scenes[erabu].instantiate()

	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = self.global_transform
	bullet.apply_central_impulse(Vector3.FORWARD.rotated(Vector3.UP, global_rotation.y) * bullet_speed)

		
func carryscene():
	# --- ナーンの処理 (変更なし) ---
	if naan_scene and naan_spawn_marker:
		var naan_instance = naan_scene.instantiate()
		get_tree().current_scene.add_child(naan_instance)
		naan_instance.global_transform = naan_spawn_marker.global_transform
		
	await close_lid()
	await shake_pot()
	
	if finished_curry_mesh:
		# --- 色の計算 (変更なし) ---
		var r_val = float(bullet_counts["赤"] + bullet_counts["黄"])
		var g_val = float(bullet_counts["緑"] + bullet_counts["黄"])
		var b_val = float(bullet_counts["青"])
		
		var final_color: Color
		var total_val = r_val + g_val + b_val

		if total_val > 0:
			final_color = Color(r_val / total_val, g_val / total_val, b_val / total_val)
		else:
			final_color = Color("8B4513")

		print("完成したカレーの色: ", final_color)

		# ★★★★★ ここからが最終修正コード ★★★★★
		
		# 1. まず、色を塗りたい「カレーの土台」のノード名を変数に入れます。
		#    下の "ここに土台のノード名を入力" の部分を、
		#    手順1で確認した実際のノード名に書き換えてください。
		var curry_base_node_name = "base" 
		
		# 2. 親ノード(finished_curry_mesh)の中から、その名前の子ノードを探します
		var curry_base_node = finished_curry_mesh.get_node_or_null(curry_base_node_name)

		# 3. ノードが見つかり、それがMeshInstance3Dだった場合のみ色を変更します
		if curry_base_node and curry_base_node is MeshInstance3D:
			print("デバッグ: カレーの土台 (", curry_base_node.name, ") を見つけました。")
			
			var base_material = curry_base_node.get_surface_override_material(0)
			if not base_material and curry_base_node.mesh:
				base_material = curry_base_node.mesh.surface_get_material(0)

			if base_material:
				var unique_material = base_material.duplicate()
				if unique_material is StandardMaterial3D:
					unique_material.albedo_color = final_color
					curry_base_node.set_surface_override_material(0, unique_material)
					print("デバッグ: 土台のマテリアルを更新しました。")
				else:
					print("警告: 土台のマテリアルはStandardMaterial3Dではありません。")
			else:
				print("警告: 土台のメッシュにベースマテリアルが見つかりません。")
		else:
			print("エラー: '", curry_base_node_name, "' という名前のMeshInstance3Dが見つかりませんでした。ノード名が正しいか、種類がMeshInstance3Dか確認してください。")
		
		# ★★★★★ 修正コードここまで ★★★★★
		
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
	await tween.finished # アニメーションが終わるのを待つ
	
# フタを開ける
func open_lid():
	if not (lid_node and lid_open_marker):
		print("エラー: Lid NodeかLid Open Markerが設定されていません。")
		return

	var tween = create_tween()
	
	tween.tween_property(lid_node, "global_transform", lid_open_marker.global_transform, 1.0)
	await tween.finished
	
	# 色変更の処理を削除し、爆発のインスタンス化だけを行う
	if explosion_scene:
		var explosion_instance = explosion_scene.instantiate()
		if pot_body_node:
			explosion_instance.global_position = pot_body_node.global_position
		
		add_child(explosion_instance)

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

#斬
func spawn_materials():
	# 前の材料が残っていたら消す
	for mat in material_objects:
		mat.queue_free()
	material_objects.clear()

	# ジャガイモを生成
	if potato_scene:
		var potato = potato_scene.instantiate()
		add_child(potato)
		potato.position = Vector3(0.2,3, -3)
		material_objects.append(potato)

	# ニンジンを生成
	if carrot_scene:
		var carrot = carrot_scene.instantiate()
		add_child(carrot)
		carrot.position = Vector3(0.3, 3, -3)
		material_objects.append(carrot)

	# UIを更新
	if cutting_label:
		cutting_label.text = "Cキーで材料を切ろう！ (残り %d 個)" % material_objects.size()
