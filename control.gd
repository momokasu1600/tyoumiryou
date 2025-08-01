extends Control

func _ready():
	# 外部コントローラー（Pico W）のボタン入力を接続
	PicoWController.button_pressed.connect(_on_controller_button_pressed)
	print("Start screen ready. Waiting for input...")

# 外部コントローラーのボタンが押された時の処理
func _on_controller_button_pressed():
	print("Controller button pressed! Starting game...")
	start_game()

# キー入力を処理する関数（テスト用）
func _input(event):
	# Enterキーが押された時の処理
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		print("Enter key pressed! Starting game...")
		start_game()

# ゲーム開始の共通処理
func start_game():
	# シーン遷移
	get_tree().change_scene_to_file("res://node_3d.tscn")
