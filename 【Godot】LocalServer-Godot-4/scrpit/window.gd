extends Node

## 窗口管理 - 自动加载单例

# ============================================================
# 可调参数（在这里修改）
# ============================================================
const MIN_WIDTH: int = 600
const MIN_HEIGHT: int = 950
const WINDOW_TITLE: String = "本地服务器控制器"
const CENTER_ON_START: bool = true


func _ready():
	var window = get_window()
	
	# 设置最小尺寸
	window.min_size = Vector2i(MIN_WIDTH, MIN_HEIGHT)
	
	# 确保当前窗口不小于最小值
	var current_size = window.size
	if current_size.x < MIN_WIDTH or current_size.y < MIN_HEIGHT:
		window.size = Vector2i(max(current_size.x, MIN_WIDTH), max(current_size.y, MIN_HEIGHT))
	
	# 设置标题
	window.title = WINDOW_TITLE
	
	# 居中
	if CENTER_ON_START:
		window.position = Vector2i(
			(DisplayServer.screen_get_size().x - window.size.x) / 2,
			(DisplayServer.screen_get_size().y - window.size.y) / 2
		)
	
	print(
		"[WindowManager] 窗口: %dx%d, 标题: %s" % 
		[MIN_WIDTH, MIN_HEIGHT, WINDOW_TITLE]
		)
