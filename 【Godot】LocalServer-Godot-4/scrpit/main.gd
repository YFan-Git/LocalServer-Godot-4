extends Control

@onready var status_label: Label = $Panel4/status
@onready var status_detail: Label = $Panel4/status2
@onready var log_view: RichTextLabel = $Panel3/RichTextLabel
@onready var btn_start: Button = $Panel5/clearn
@onready var btn_stop: Button = $Panel5/stop
@onready var btn_browser: Button = $Panel5/browser
@onready var btn_clear: Button = $Panel5/star

var controller: ServerController


func _ready():
	controller = ServerController.new()
	
	controller.server_started.connect(_on_server_started)
	controller.server_stopped.connect(_on_server_stopped)
	
	btn_start.pressed.connect(_on_start_pressed)
	btn_stop.pressed.connect(_on_stop_pressed)
	btn_browser.pressed.connect(_on_browser_pressed)
	btn_clear.pressed.connect(_on_clear_pressed)
	
	_update_ui()
	_add_log("✦ 本地服务器 已就绪...")


func _update_ui():
	print("_update_ui 被调用，is_running:", controller.data.is_running())
	print("btn_start 节点:", btn_start)  # 看看是不是 null  
	if controller.data.is_running():
		status_label.text = "◉ 运行中"
		status_label.label_settings.font_color = Color(0.17647, 0.8, 0.43922)
		status_detail.text = "◉ 端口 - localhost: %d" % controller.data.port
		status_detail.visible = true
		btn_start.disabled = true
		btn_stop.disabled = false
		btn_browser.disabled = false
		print("按钮已禁用")
	else:
		status_label.text = "◉ 未启动"
		status_label.label_settings.font_color = Color(0.557, 0.557, 0.557)
		status_detail.visible = false
		btn_start.disabled = false
		btn_stop.disabled = true
		btn_browser.disabled = true


func _add_log(message: String):
	var time = Time.get_time_string_from_system()
	log_view.text += "[%s] %s\n" % [time, message]
	log_view.scroll_to_line(log_view.get_line_count() - 1)


func _on_server_started(port: int):
	print("✅ _on_server_started 被调用，端口:", port)
	_add_log("✅ 服务器启动成功 - 端口: %d" % port)
	_update_ui()


func _on_server_stopped():
	_add_log("❌ 服务器已停止")
	_update_ui()


func _on_start_pressed():
	_add_log("🚀 正在启动服务器...")
	controller.start_server()


func _on_stop_pressed():
	_add_log("🚫 正在停止服务器...")
	controller.stop_server()


func _on_browser_pressed():
	controller.open_browser()


func _on_clear_pressed():
	log_view.text = ""
	controller.clear_logs()
	_add_log("♻︎ 日志已清空")


func _exit_tree():
	if controller:
		controller.cleanup()


func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if controller and controller.data.is_running():
			controller.stop_server()
		get_tree().quit()
