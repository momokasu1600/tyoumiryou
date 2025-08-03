# ==============================================================================
# Pico W コントローラー用 受信スクリプト (新仕様)
# ==============================================================================
# 概要:
# PicoWから加速度・ボタンデータを受信し、以下のアクションを検出して合図を送る。
# 1. カット用の強い振り (cut_action_detected)
# 2. 調味料用の振り (seasoning_added)
# 3. ボタン押し (button_pressed)
# ==============================================================================
extends Node

# --- ▼▼▼【変更】合図(シグナル)の定義 ▼▼▼ ---
signal cut_action_detected    # カット用の強い振りを検出した時の合図
signal button_pressed         # ボタンが押された瞬間の合図
signal seasoning_added(amount) # 調味料を投入する時の合図 (これは変更なし)
# --- ▲▲▲ 変更ここまで ▲▲▲ ---

# ------------------------------------------------------------------------------
# ネットワーク設定
# ------------------------------------------------------------------------------
const UDP_PORT = 4242
var peer = PacketPeerUDP.new()

# ------------------------------------------------------------------------------
# ゲームバランス調整用の定数
# ------------------------------------------------------------------------------
# 【変更なし】傾きの判定
const TILT_XY_THRESHOLD = 2.8
# 【変更なし】振ったと判定する最低限の強さ
const POUR_Z_THRESHOLD = 2.0
# 【変更なし】振りの強さをゲーム内の量に変換する係数
const AMOUNT_SCALING_FACTOR = 0.05

# --- ▼▼▼【追加】カット判定用の新しい定数 ▼▼▼ ---
# この値を超えたら「カットアクション」として認定する、振りの強さの合計値。
# この値を大きくすると、もっと激しく振らないと切れなくなる。
const CUT_SHAKE_THRESHOLD = 0.15


# 振りの強さを合計する時間（秒）。仕様書通り0.4秒に設定。
const CUT_WINDOW_DURATION = 0.1
# --- ▲▲▲ 追加ここまで ▲▲▲ ---

# ------------------------------------------------------------------------------
# 状態を保存する変数
# ------------------------------------------------------------------------------
var final_acceleration = Vector3.ZERO
var was_button_pressed_flag: bool = false # ボタンが押された瞬間を判定するため

# --- ▼▼▼【追加】カット判定用の新しい変数 ▼▼▼ ---
var cut_shake_accumulator = 0.0 # 振りの強さを蓄積する変数
var cut_window_timer = 0.0      # 時間を計るタイマー
# --- ▲▲▲ 追加ここまで ▲▲▲ ---

# ==============================================================================
# Godotエンジンのライフサイクル関数
# ==============================================================================

func _ready():
	var error = peer.bind(UDP_PORT)
	if error != OK:
		print("Error: Could not bind UDP port. Error code: ", error)
	else:
		print("UDP port bound successfully on port ", UDP_PORT)
		print("Waiting for data from Raspberry Pi Pico W...")

func _exit_tree():
	peer.close()
	print("UDP peer closed.")

# 毎フレーム呼ばれる関数
func _process(delta):
	# --- ▼▼▼【全面変更】カット判定ロジック ▼▼▼ ---
	# 1. 毎フレーム、タイマーを進める
	cut_window_timer += delta

	# 2. もし計測時間が0.4秒を超えたら...
	if cut_window_timer >= CUT_WINDOW_DURATION:
		# 3. 蓄積された振りの強さが、カットに必要な強さを超えているかチェック
		if cut_shake_accumulator >= CUT_SHAKE_THRESHOLD:
			# 4. 条件クリア！「カットせよ！」という合図を送る
			cut_action_detected.emit()
			print(">>> Cut Action Detected! Total Shake Power: ", cut_shake_accumulator)
		
		# 5. 次の計測のために、蓄積値とタイマーをリセットする
		cut_shake_accumulator = 0.0
		cut_window_timer = 0.0
	# --- ▲▲▲ 変更ここまで ▲▲▲ ---

	# データ受信処理を呼び出す
	receive_and_map_data()


# ==============================================================================
# 個別の処理をまとめた関数群
# ==============================================================================

# Pico Wからデータを受け取って、各種判定を行う命令
func receive_and_map_data():
	while peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		var message = packet.get_string_from_utf8()
		var parts = message.split(",")
		
		if parts.size() == 4:
			# 加速度データのマッピング (変更なし)
			var raw_ax = parts[0].to_float()
			var raw_ay = parts[1].to_float()
			var raw_az = parts[2].to_float()
			var real_x = raw_ay
			var real_y = -raw_az
			var real_z = -raw_ax
			var mapped_x = real_x
			var mapped_y = - real_z
			var mapped_z = - real_y
			final_acceleration = Vector3(mapped_x, mapped_y, mapped_z)

			# --- ▼▼▼【変更】ボタン入力の判定 (シンプル版) ▼▼▼ ---
			var button_state = parts[3].to_int()
			var is_pressed_now = (button_state == 1)
			
			# ボタンが「押された瞬間」だけを検出 (離した時や押しっぱなしは無視)
			if is_pressed_now and not was_button_pressed_flag:
				button_pressed.emit()
				print(">>> Button Pressed! <<<")
			
			# 現在の状態を保存して、次のフレームの判定に使う
			was_button_pressed_flag = is_pressed_now
			# --- ▲▲▲ 変更ここまで ▲▲▲ ---

			# --- ▼▼▼【変更】振りの検出と処理 ▼▼▼ ---
			var is_tilted = abs(final_acceleration.x) > TILT_XY_THRESHOLD or \
							abs(final_acceleration.z) > TILT_XY_THRESHOLD

			if not is_tilted:
				# 上下に振られているか？
				if abs(final_acceleration.y) > POUR_Z_THRESHOLD:
					var pour_speed = abs(final_acceleration.y) - POUR_Z_THRESHOLD
					# 0.1は固定のデルタタイム。受信間隔のブレをなくし安定させるため。
					var amount = pour_speed * 0.1 * AMOUNT_SCALING_FACTOR

					# 【重要】検出した振りの強さを2つの目的に使う
					# 目的1: カット判定のために、振りの強さを蓄積する
					cut_shake_accumulator += amount
					
					# 目的2: 調味料投入のために、そのまま合図を送る
					seasoning_added.emit(amount)
					
					# デバッグ表示
					print("Shake detected. Amount: %.2f | Cut Accumulator: %.2f" % [amount, cut_shake_accumulator])
				else:
					# 静止状態
					pass # print("State: Upright, not shaking.")
			else:
				# 傾いている状態
				pass # print("State: Tilted.")
			# --- ▲▲▲ 変更ここまで ▲▲▲ ---
