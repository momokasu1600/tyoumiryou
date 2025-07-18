# result.tscn の Control ノードにアタッチするスクリプト
extends Control

# 【追加】↓あなたのプロジェクトの「スタート画面」のパスに書き換えてください
const START_SCENE_PATH = "res://control.tscn" 

# ↓ここの「$ResultLabel」の部分は、あなたの実際のLabelノードの名前に合わせてください
@onready var label_node = $ResultLabel

func _ready():
	# ↓ここで「=」の右側に ScoreManager が来ているか確認！
	if ScoreManager and not ScoreManager.curry_evaluation_text.is_empty():
		label_node.text = ScoreManager.curry_evaluation_text
	else:
		label_node.text = "評価がありません" # ScoreManagerから評価を取れなかった場合の表示


# 【追加】エンターキーが押されたときの処理
func _unhandled_input(event):
	# "ui_accept" アクション（デフォルトでEnterキーやSpaceキー）が押されたかをチェック
	if event.is_action_pressed("ui_accept"):
		
		# 他のノードで入力が重複して処理されないようにする
		get_tree().get_root().set_input_as_handled()
		
		# スタート画面にシーンを切り替える
		var error = get_tree().change_scene_to_file(START_SCENE_PATH)
		
		# もしシーンの読み込みに失敗したらエラーメッセージを出す
		if error != OK:
			print("エラー: スタート画面の読み込みに失敗しました。パスを確認してください: ", START_SCENE_PATH)
