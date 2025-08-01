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
@export var futa_close_player :AudioStreamPlayer
@export var cut_sound_player :AudioStreamPlayer
@export var shoot_timer: Timer
@export var timer_label: Label
@export var gauges_container: Control
@export var red_percent_label: Label
@export var blue_percent_label: Label
@export var green_percent_label: Label
@export var yellow_percent_label: Label
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
	# 調理中は何もしない
	if is_cooking:
		return

	# --- 材料を切るフェーズの処理 ---
	if is_cutting_phase:
		# is_action_just_pressed が Godot 4 の機能なので、古いバージョンのために is_action と is_pressed を使います
		if event.is_action("cut_material") and event.is_pressed():
			
			if not material_objects.is_empty():
				cut_shake_count += 1
				
				var remaining_shakes = REQUIRED_SHAKES - cut_shake_count
				if info_label:
					info_label.text = "振ってカット！ (あと %d 回)" % remaining_shakes

				if cut_shake_count >= REQUIRED_SHAKES:
					cut_one_material()
					cut_shake_count = 0
	
	# --- 発射フェーズの処理 (変更なし) ---
	else: 
		if time_is_up:
			return
		# ボタンでの調味料切り替えはPicoWControllerからの信号で行うため、ここでは不要
		# shootも同様
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
		cut_sound_player.play()
		# UIを更新して、残り回数を表示
		update_info_label()

# 【新設】材料を1つカットする共通処理
# cut_one_material 関数をまるごと置き換えてください
func cut_one_material():
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
			
		# 【ここからテキストの初期化処理を追加】
		if gauges_container:
			gauges_container.visible = true

		if red_percent_label:
			red_percent_label.text = "ニンニク: 0%"
			red_percent_label.visible = true
		if blue_percent_label:
			blue_percent_label.text = "カルダモン: 0%"
			blue_percent_label.visible = true
		if green_percent_label:
			green_percent_label.text = "シナモン: 0%"
			green_percent_label.visible = true
		if yellow_percent_label:
			yellow_percent_label.text = "しょうが: 0%"
			yellow_percent_label.visible = true
	else:
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
# shoot_bullet 関数をまるごと置き換えてください
func shoot_bullet(amount):
	var current_bullet_name = bullet_names[erabu]
	bullet_counts[current_bullet_name] += 1
	
	# 【ここからパーセント表示更新処理】
	match current_bullet_name:
		"赤":
			if red_percent_label:
				var ideal_red = 125.0 # 合計600個の場合の理想値
				var percent = int( (bullet_counts["赤"] / ideal_red) * 100.0 )
				red_percent_label.text = "ニンニク: %d%%" % percent # %%で%記号を表示
				if percent >= 70:
					red_percent_label.visible = false
		"青":
			if blue_percent_label:
				var ideal_blue = 38.0
				var percent = int( (bullet_counts["青"] / ideal_blue) * 100.0 )
				blue_percent_label.text = "カルダモン: %d%%" % percent
				if percent >= 70:
					blue_percent_label.visible = false
		"緑":
			if green_percent_label:
				var ideal_green = 63.0
				var percent = int( (bullet_counts["緑"] / ideal_green) * 100.0 )
				green_percent_label.text = "シナモン: %d%%" % percent
				if percent >= 70:
					green_percent_label.visible = false
		"黄":
			if yellow_percent_label:
				var ideal_yellow = 375.0
				var percent = int( (bullet_counts["黄"] / ideal_yellow) * 100.0 )
				yellow_percent_label.text = "しょうが: %d%%" % percent
				if percent >= 70:
					yellow_percent_label.visible = false
	# 【パーセント表示更新ここまで】

	var bullet: RigidBody3D = bullet_scenes[erabu].instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = self.global_transform
	bullet.apply_central_impulse(Vector3.FORWARD.rotated(Vector3.UP, global_rotation.y) * bullet_speed)
	shoot_sound_player.play()
		
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
	# 【追加】理想値テキストのコンテナを隠す
	if gauges_container:
		gauges_container.visible = false
		
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
	futa_close_player.play()
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
	var red = float(bullet_counts["赤"])      # ニンニク (パンチ)
	var blue = float(bullet_counts["青"])     # カルダモン (爽やか)
	var green = float(bullet_counts["緑"])    # シナモン (甘み)
	var yellow = float(bullet_counts["黄"])   # しょうが (温かさ)
	var total = red + blue + green + yellow
	
	# --- 基本的な評価 ---
	if total == 0:
		return "何も入れなかった…\nこれはただのベースです。"
	if total < 30:
		return "もっと調味料が欲しい！\n味が薄すぎる、だし汁のようなカレー。"

	# --- 黄金比の評価 (最上級) ---
	# 理想の比率を設定
	var ideal_red_ratio = 0.208
	var ideal_blue_ratio = 0.063
	var ideal_green_ratio = 0.104
	var ideal_yellow_ratio = 0.625
	# 許容誤差 (例: ±10%)
	var tolerance = 0.1
	
	# 各調味料が理想の比率の範囲内にあるかチェック
	if red >= total * (ideal_red_ratio - tolerance) and red <= total * (ideal_red_ratio + tolerance) and \
	   blue >= total * (ideal_blue_ratio - tolerance) and blue <= total * (ideal_blue_ratio + tolerance) and \
	   green >= total * (ideal_green_ratio - tolerance) and green <= total * (ideal_green_ratio + tolerance) and \
	   yellow >= total * (ideal_yellow_ratio - tolerance) and yellow <= total * (ideal_yellow_ratio + tolerance):
		return "まさに黄金比！\n全ての味が調和した、神々のカレー！"
	# --- 特殊な組み合わせの評価 ---
	# パワー系コンビ
	if red > total * 0.4 and yellow > total * 0.4 and blue < total * 0.05 and green < total * 0.05:
		return "ニンニクとショウガの最強タッグ！\n力がみなぎるエナジーカレー！"
	# スイーツ系コンビ
	if green > total * 0.4 and blue > total * 0.4 and red < total * 0.05 and yellow < total * 0.05:
		return "爽やかさと甘さの二重奏！\nチャイを彷彿とさせるリラックスカレー！"
	# パンチ＆スイート
	if red > total * 0.4 and green > total * 0.4 and blue < total * 0.05 and yellow < total * 0.05:
		return "禁断の出会い…ニンニクとシナモン！\n意外とやみつきになる、挑戦者のカレー。"
	# ウォーム＆リフレッシュ
	if yellow > total * 0.4 and blue > total * 0.4 and red < total * 0.05 and green < total * 0.05:
		return "ポカポカなのに、後味さっぱり！\n新しい扉を開いた革命的カレー。"
		
	# --- 極端な配合の評価 ---
	if red / total > 0.8:
		return "ニンニク！ニンニク！ニンニク！\nもはやカレーではなく、ニンニクそのものだ！"
	if blue / total > 0.8:
		return "爽やかすぎて歯磨き粉みたい！？\nミント香る（？）超絶クリアカレー。"
	if green / total > 0.8:
		return "甘い！とにかく甘い！\nこれはもう、カレーの国のアップルパイだ！"
	if yellow / total > 0.8:
		return "ショウガの熱量で宇宙が見える！\n燃えるようなジンジャーカレー！"

	# --- 主要な調味料が欠けている場合の評価 ---
	if yellow < total * 0.1:
		return "何か物足りない…そうか、ショウガが足りない！\n体の芯が温まらない、ちょっぴり寂しいカレー。"
	if red < total * 0.1:
		return "パンチが足りない！\n優しすぎて、逆に眠くなってしまうカレー。"

	# --- 各調味料が優勢な場合の評価 ---
	if red > blue and red > green and red > yellow:
		if blue > 0:
			return "ニンニクのパンチに、カルダモンの涼しい風。\n荒々しさと知性を感じる、策士のカレー。"
		else:
			return "ニンニクのストレートな衝撃！\n小細工なし、直球勝負の漢気カレー。"
			
	if blue > red and blue > green and blue > yellow:
		if yellow > 0:
			return "爽やかな風が吹いた後、体がポカポカ。\nまるでサウナのような、整えるカレー。"
		else:
			return "ひたすらに爽やか！\n気分をリフレッシュしたい時に食べるカレー。"

	if green > red and green > blue and green > yellow:
		if red > 0:
			return "甘い香りの奥に潜む、ガツンとくる刺激。\nツンデレのような、ギャップ萌えカレー。"
		else:
			return "独特の甘みが、心を優しく包み込む。\nおばあちゃんの笑顔を思い出すカレー。"

	if yellow > red and yellow > blue and yellow > green:
		if green > 0:
			return "体の芯から温まる中に、ふわりと香る甘み。\n冬の暖炉の前で食べたい、幸せのカレー。"
		else:
			return "ショウガの力が体に染み渡る！\n風邪をひきそうな時に食べたい、養生カレー。"

	# --- 上記のどれにも当てはまらない、一般的な評価 ---
	return "いろんな味がする…\n新時代のスタンダードカレー！"

# 【変更】spawn_materialsに関数を追加
func spawn_materials():
	for mat in material_objects:
		mat.queue_free()
	material_objects.clear()

	if potato_scene:
		var potato = potato_scene.instantiate()
		add_child(potato)
		potato.position = Vector3(0.2,3, -10)
		material_objects.append(potato)

	if carrot_scene:
		var carrot = carrot_scene.instantiate()
		add_child(carrot)
		carrot.position = Vector3(0.3, 3, -8)
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
