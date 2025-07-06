# ==============================================================================
# Pico W コントローラー用 受信スクリプト (料理ゲーム仕様)
# ==============================================================================
# 概要:
# Wi-Fi(UDP)経由でRaspberry Pi Pico Wから加速度データを受信し、
# 「傾けずに振る」というアクションを検出して、調味料の量を計算する。
# ==============================================================================
extends Node

signal seasoning_added(amount) # 「seasoning_added」という名前の合図を作ると宣言

# ------------------------------------------------------------------------------
# ネットワーク設定
# ------------------------------------------------------------------------------
const UDP_PORT = 4242
var peer = PacketPeerUDP.new()

# ------------------------------------------------------------------------------
# 物理計算のタイミング設定
# ------------------------------------------------------------------------------
# 計算を実行する固定の時間間隔 (秒)。
# この値を小さくすると反応は敏感になるが、PCへの負荷は少し上がる。
const FIXED_DELTA_T = 0.1
var time_accumulator = 0.0

# ------------------------------------------------------------------------------
# ゲームバランス調整用の定数 (ここを調整してゲームの操作感を変更する)
# ------------------------------------------------------------------------------
# 【重要】「傾いている」と判定するための、X軸・Y軸の加速度のしきい値。
# センサーのXかYの加速度の絶対値がこの値を超えたら、「傾いている」と見なす。
# この値を大きくすると、多少の傾きは許容されるようになる。
const TILT_XY_THRESHOLD = 2.8

# 「傾いていない」状態で、「振っている」と判定するためのZ軸加速度のしきい値。
# 安定している状態で、Z軸の加速度の絶対値がこの値を超えたら「振っている」アクションとして認識。
# この値を大きくするほど、より強く振らないと反応しなくなる。
const POUR_Z_THRESHOLD = 2.0

# 物理的な意味を持つ係数 (加速度の値を、ゲーム内の「量」に変換する)
# この値を大きくすると、同じ振り方でも調味料がたくさん出るようになる。
const AMOUNT_SCALING_FACTOR = 1.0

# ------------------------------------------------------------------------------
# ゲームの状態を保存する変数
# ------------------------------------------------------------------------------
var total_seasoning_amount = 0.0 # 調味料の総量
var final_acceleration = Vector3.ZERO # 最新の加速度データ

# ==============================================================================
# Godotエンジンのライフサイクル関数
# ==============================================================================

# シーン開始時に一度だけ呼ばれる関数
func _ready():
	var error = peer.bind(UDP_PORT)
	if error != OK:
		print("Error: Could not bind UDP port. Error code: ", error)
	else:
		print("UDP port bound successfully on port ", UDP_PORT)
		print("Waiting for data from Raspberry Pi Pico W...")

# シーン終了時に一度だけ呼ばれる関数
func _exit_tree():
	peer.close()
	print("UDP peer closed.")

# PicoWController.gd の中の _process 関数
# 毎フレーム、少しずつ時間をためて、一定時間ごとに通信を確認する命令
func _process(delta):
	time_accumulator += delta
	while time_accumulator >= FIXED_DELTA_T:
		receive_and_map_data()
		time_accumulator -= FIXED_DELTA_T

# ==============================================================================
# 個別の処理をまとめた関数群
# ==============================================================================

# PicoWController.gd の中の receive_and_map_data 関数
# Pico Wからデータを受け取って、振られたかどうかを判断する命令
func receive_and_map_data():
	while peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		var message = packet.get_string_from_utf8()
		var parts = message.split(",")
		if parts.size() == 3:
			var raw_ax = parts[0].to_float()
			var raw_ay = parts[1].to_float()
			var raw_az = parts[2].to_float()

			# 物理センサとリアル世界(デカルト座標系)の対応
			var real_x = raw_ay
			var real_y = -raw_az
			var real_z = -raw_ax
			
			# デカルト座標系とGodot座標系の対応
			var mapped_x = real_x
			var mapped_y = real_z
			var mapped_z = - real_y
			
			# ゲーム内の加速度として、新しい座標の値を使用する
			final_acceleration = Vector3(mapped_x, mapped_y, mapped_z)

			# --- 判定ロジック（新しい座標に合わせて判定） ---
			# 1. 傾いている？ (現実世界のX軸とZ軸、つまり左右と前後への傾きをチェック)
			var is_tilted = abs(final_acceleration.x) > TILT_XY_THRESHOLD or \
							abs(final_acceleration.z) > TILT_XY_THRESHOLD

			var accel_string = " | Accel: X=%.2f, Y=%.2f, Z=%.2f" % [final_acceleration.x, final_acceleration.y, final_acceleration.z]

			# 2. もし傾いていなかったら…
			if not is_tilted:
				# 3. さらに、上下（現実世界のY軸）に振られているか？
				if abs(final_acceleration.y) > POUR_Z_THRESHOLD:
					# 4. 条件クリア！振られた量を計算
					var pour_speed = abs(final_acceleration.y) - POUR_Z_THRESHOLD
					var amount_to_add = pour_speed * FIXED_DELTA_T * AMOUNT_SCALING_FACTOR
					total_seasoning_amount += amount_to_add
					
					# 5. 「振られたよ！」と合図を送る
					seasoning_added.emit(amount_to_add)
					
					print("POURING! | Total: %.2f" % [total_seasoning_amount] + accel_string)
				else:
					print("State: Upright, not shaking." + accel_string)
			else:
				print("State: Tilted. Y-data ignored." + accel_string)
