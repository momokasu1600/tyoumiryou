extends Control

func _on_button_pressed():
	get_tree().change_scene_to_file("res://node_3d.tscn")


func _input(event):
	# もし押されたキーがEnterキーだったら
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		# ゲームシーンに切り替える
		get_tree().change_scene_to_file("res://node_3d.tscn")
