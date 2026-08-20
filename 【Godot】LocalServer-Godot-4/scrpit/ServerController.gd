extends RefCounted
class_name ServerController

signal server_started(port: int)
signal server_stopped()

var data: ServerData
var _port: int = 0
var _work_dir: String = ""
var _stop_thread: Thread = null
var _is_stopping: bool = false


func _init():
	data = ServerData.new()
	_work_dir = ProjectSettings.globalize_path("user://")
	_work_dir = _work_dir.replace("\\", "/")
	if not _work_dir.ends_with("/"):
		_work_dir += "/"
	data.add_log("✦ 服务器控制器已初始化")
	data.add_log("📁 工作目录: %s" % _work_dir)


func _write_ps1(filename: String, content: String) -> String:
	var ps1_path = _work_dir + filename + ".ps1"
	var file = FileAccess.open(ps1_path, FileAccess.WRITE)
	var utf8_bytes = content.to_utf8_buffer()
	file.store_buffer(utf8_bytes)
	file.close()
	print("[ServerController] 已生成: %s" % ps1_path)
	return ps1_path


func _get_pid_path() -> String:
	return _work_dir + "server.pid"


func _delete_pid() -> void:
	var path = _get_pid_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[ServerController] ✅ server.pid 已删除")


func _thread_stop():
	print("[ServerController] 停止线程开始")
	var quit_path = _write_ps1("quit", ServerData.get_quit_ps1())
	OS.execute("powershell.exe", [
		"-ExecutionPolicy", "Bypass",
		"-File", quit_path
	], [], false)
	print("[ServerController] ✅ 停止线程执行完毕")
	_is_stopping = false


func start_server() -> bool:
	if data.is_running():
		data.add_log("⚠️ 服务器已在运行中")
		return false
	
	if _is_stopping:
		data.add_log("⏳ 正在停止中，请稍候...")
		return false
	
	if _stop_thread and _stop_thread.is_started():
		print("[ServerController] ⏳ 等待停止线程完成...")
		_stop_thread.wait_to_finish()
		_stop_thread = null
	
	var pid_path = _get_pid_path()
	if FileAccess.file_exists(pid_path):
		_delete_pid()
	
	_port = randi_range(8888, 9888)
	data.port = _port
	
	var ps1_path = _write_ps1("server", ServerData.get_server_ps1())
	
	var args = [
		"-ExecutionPolicy", "Bypass",
		"-Command",
		"Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File \"{0}\" -port {1}' -WindowStyle Hidden".format([ps1_path, _port])
	]
	
	print("[ServerController] 执行启动命令")
	OS.execute("powershell.exe", args, [], false)
	
	data.status = ServerData.Status.RUNNING
	data.add_log("🔄 正在启动服务器...")
	server_started.emit(_port)
	
	data.add_log("✅ 服务器启动命令已发送 - 端口: %d" % _port)
	return true


func stop_server() -> void:
	if not data.is_running():
		data.add_log("⚠️ 服务器未运行")
		return
	
	if _is_stopping:
		data.add_log("⏳ 已经在停止中...")
		return
	
	if _stop_thread and _stop_thread.is_started():
		print("[ServerController] ⏳ 等待停止线程完成...")
		_stop_thread.wait_to_finish()
		_stop_thread = null
	
	_is_stopping = true
	data.add_log("🔄 正在停止服务器...")
	
	_delete_pid()
	
	data.reset()
	server_stopped.emit()
	
	_stop_thread = Thread.new()
	_stop_thread.start(_thread_stop)
	
	data.add_log("✅ 服务器已停止")


func open_browser() -> void:
	if data.port <= 0:
		data.add_log("⚠️ 服务器未运行")
		return
	OS.shell_open("http://localhost:%d" % data.port)
	data.add_log("🌐 已打开浏览器: http://localhost:%d" % data.port)


func clear_logs() -> void:
	data.clear_logs()
	data.add_log("🗑️ 日志已清空")


func cleanup() -> void:
	data.add_log("🧹 开始清理资源...")
	
	if _stop_thread and _stop_thread.is_started():
		print("[ServerController] ⏳ 等待停止线程完成...")
		_stop_thread.wait_to_finish()
		_stop_thread = null
	
	if data.is_running():
		var quit_path = _work_dir + "quit.ps1"
		if FileAccess.file_exists(quit_path):
			OS.execute("powershell.exe", [
				"-ExecutionPolicy", "Bypass",
				"-File", quit_path
			], [], false)
		data.reset()
		server_stopped.emit()
	
	_delete_pid()
	_is_stopping = false
	
	data.add_log("🧹 资源已清理完成")
