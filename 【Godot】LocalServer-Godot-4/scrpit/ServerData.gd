extends RefCounted
class_name ServerData

enum Status {
	STOPPED,
	RUNNING,
	ERROR
}

var port: int = 0
var status: Status = Status.STOPPED
var logs: Array[String] = []

const SERVER_PS1 = """
param([int]$port)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Start-Process "http://localhost:$port"

Write-Host "✅ 服务器已启动: http://localhost:$port" -ForegroundColor Green
Write-Host "📂 目录: $PWD" -ForegroundColor Gray

while ($true) {
    try {
        # ===== 同步等待连接（不会断连） =====
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $rawUrl = $request.RawUrl
        $path = $rawUrl.TrimStart('/')
		if ([string]::IsNullOrEmpty($path)) { $path = "." }
        
        $fullPath = [System.IO.Path]::Combine($PWD.Path, $path)
        $fullPath = [System.IO.Path]::GetFullPath($fullPath)

        if (-not $fullPath.StartsWith($PWD.Path)) {
			$html = "<h1>403 - 禁止访问</h1>"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.StatusCode = 403
            $response.ContentLength64 = $buffer.Length
			$response.ContentType = "text/html; charset=utf-8"
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
            continue
        }

        if ([System.IO.Directory]::Exists($fullPath)) {
			$indexPath = [System.IO.Path]::Combine($fullPath, "index.html")
            if ([System.IO.File]::Exists($indexPath)) {
                $content = [System.IO.File]::ReadAllBytes($indexPath)
                $response.ContentLength64 = $content.Length
				$response.ContentType = "text/html; charset=utf-8"
                $response.OutputStream.Write($content, 0, $content.Length)
                $response.OutputStream.Close()
                continue
            }
            
            $items = Get-ChildItem $fullPath
            $html = @"
<html>
<head>
	<meta charset="UTF-8">
	<title>📂 目录: $rawUrl</title>
	<style>
		body { font-family: Consolas, monospace; padding: 20px; background: #f5f5f5; max-width: 900px; margin: 0 auto; }
		h1 { color: #333; font-size: 20px; border-bottom: 2px solid #ddd; padding-bottom: 10px; }
		a { text-decoration: none; color: #0066cc; }
		a:hover { text-decoration: underline; }
		ul { list-style: none; padding: 0; }
		li { padding: 4px 0; border-bottom: 1px solid #eee; }
		.size { color: #888; font-size: 12px; }
		.dir { color: #0066cc; font-weight: bold; }
		.footer { color: #aaa; font-size: 12px; margin-top: 20px; border-top: 1px solid #ddd; padding-top: 10px; }
	</style>
</head>
<body>
	<h1>📂 $rawUrl</h1>
	<ul>
"@
			if ($rawUrl -ne "/" -and $rawUrl -ne "") {
				$html += "<li><a href='..' class='dir'>📂 ../</a></li>"
            }
            foreach ($item in $items) {
                $href = [System.Uri]::EscapeDataString($item.Name)
                if ($item.PSIsContainer) {
					$html += "<li><a href='$href/' class='dir'>📁 $($item.Name)/</a></li>"
                } else {
					$size = if ($item.Length -gt 1048576) { "{0:N2} MB" -f ($item.Length / 1048576) } 
							elseif ($item.Length -gt 1024) { "{0:N1} KB" -f ($item.Length / 1024) } 
							else { "$($item.Length) B" }
					$html += "<li><a href='$href'>📄 $($item.Name)</a> <span class='size'>($size)</span></li>"
                }
            }
            $html += @"
	</ul>
	<div class="footer">PowerShell 目录服务器 | $PWD</div>
</body>
</html>
"@
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentLength64 = $buffer.Length
			$response.ContentType = "text/html; charset=utf-8"
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
            continue
        }

        if ([System.IO.File]::Exists($fullPath)) {
            $content = [System.IO.File]::ReadAllBytes($fullPath)
            $response.ContentLength64 = $content.Length
            $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
            $mime = @{
				".html" = "text/html; charset=utf-8"
				".htm"  = "text/html; charset=utf-8"
				".css"  = "text/css"
				".js"   = "application/javascript"
				".png"  = "image/png"
				".jpg"  = "image/jpeg"
				".jpeg" = "image/jpeg"
				".gif"  = "image/gif"
				".svg"  = "image/svg+xml"
				".json" = "application/json"
				".txt"  = "text/plain; charset=utf-8"
            }
            if ($mime.ContainsKey($ext)) {
                $response.ContentType = $mime[$ext]
            } else {
				$response.ContentType = "application/octet-stream"
            }
            $response.OutputStream.Write($content, 0, $content.Length)
            $response.OutputStream.Close()
            continue
        }

		$html = "<h1>404 - 找不到文件或目录</h1>"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $response.StatusCode = 404
        $response.ContentLength64 = $buffer.Length
		$response.ContentType = "text/html; charset=utf-8"
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.OutputStream.Close()

    } catch {
		Write-Host "⚠️ 连接错误，继续等待..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500
    }
}
"""

const QUIT_PS1 = """
Get-Process -Name powershell -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $pid } | Stop-Process -Force
"""

static func get_server_ps1() -> String:
	return SERVER_PS1

static func get_quit_ps1() -> String:
	return QUIT_PS1

func reset() -> void:
	port = 0
	status = Status.STOPPED

func is_running() -> bool:
	return status == Status.RUNNING

func add_log(message: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	logs.append("[%s] %s" % [timestamp, message])
	if logs.size() > 1000:
		logs.remove_at(0)

func clear_logs() -> void:
	logs.clear()
