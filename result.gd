# result.tscn の Control ノードにアタッチするスクリプト
extends Control

# ↓ここの「$Label」の部分は、あなたの実際のLabelノードの名前に合わせる
@onready var label_node = $ResultLabel

func _ready():
	# ↓ここで「=」の右側に ScoreManager が来ているか確認！
	label_node.text = ScoreManager.curry_evaluation_text
