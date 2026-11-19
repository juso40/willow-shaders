class_name BrowserImageDrop
extends Node
## Browser links are image candidates, never local model or state paths.

signal link_dropped(value: String)
signal notice(message: String)
const MAX_BYTES := 16 * 1024 * 1024
const MAX_PIXELS := 16 * 1024 * 1024
const NO_IMAGE := "No usable image in this drop. Drag the original PNG, JPEG or WebP image, or save it and drop the file."
var _request: HTTPRequest
var _drag_callback: JavaScriptObject
var _drop_callback: JavaScriptObject

func _ready() -> void:
	if not OS.has_feature("web"): return
	var window := JavaScriptBridge.get_interface("window")
	_drag_callback = JavaScriptBridge.create_callback(_on_web_drag)
	_drop_callback = JavaScriptBridge.create_callback(_on_web_drop)
	# Intercept non-file drops before Godot consumes the canvas event.
	window.addEventListener("dragover", _drag_callback, true)
	window.addEventListener("drop", _drop_callback, true)

func _exit_tree() -> void:
	cancel()
	if _drop_callback:
		var window := JavaScriptBridge.get_interface("window")
		window.removeEventListener("dragover", _drag_callback, true)
		window.removeEventListener("drop", _drop_callback, true)

func _on_web_drag(args: Array) -> void:
	var event: JavaScriptObject = args[0]
	if event.target.tagName != "CANVAS": return
	event.preventDefault()
	event.dataTransfer.dropEffect = "copy"

func _on_web_drop(args: Array) -> void:
	var event: JavaScriptObject = args[0]
	if event.target.tagName != "CANVAS": return
	var data: JavaScriptObject = event.dataTransfer
	if data.files.length > 0: return # Godot already handles actual files.
	event.preventDefault()
	event.stopImmediatePropagation()
	var uri := first_uri(data.getData("text/uri-list"))
	if uri.is_empty(): uri = first_uri(data.getData("text/x-moz-url"))
	var url := wrapper_image(uri)
	if url.is_empty():
		# An image inside a link often supplies a page URL and a separate img src.
		# A detached template parses attributes without running the dropped HTML.
		var html: String = data.getData("text/html")
		if not html.is_empty():
			var template := JavaScriptBridge.get_interface("document").createElement("template") as JavaScriptObject
			template.innerHTML = html
			var anchor: JavaScriptObject = template.content.querySelector("a[href]")
			if anchor: url = wrapper_image(anchor.getAttribute("href"))
			if url.is_empty():
				var img: JavaScriptObject = template.content.querySelector("img[src]")
				if img: url = image_url(img.getAttribute("src"))
	if url.is_empty(): url = image_url(uri)
	if url.is_empty(): url = image_url(first_uri(data.getData("text/plain")))
	link_dropped.emit(url)

static func first_uri(text: String) -> String:
	for line in text.split("\n", false):
		var value := line.strip_edges()
		if not value.is_empty() and not value.begins_with("#"): return value
	return ""

static func _http(value: String) -> bool:
	return value.begins_with("https://") or value.begins_with("http://")

static func wrapper_image(value: String) -> String:
	if not _http(value) or not value.contains("?"): return ""
	for pair in value.split("?", true, 1)[1].get_slice("#", 0).split("&", false):
		var key := pair.get_slice("=", 0)
		if key not in ["imgurl", "mediaurl"]: continue
		var target := pair.substr(key.length() + 1)
		if not _http(target): target = target.uri_decode()
		if _http(target): return target
	return ""

static func image_url(value: String) -> String:
	value = value.strip_edges()
	if value.begins_with("data:image/"): return value
	if not _http(value): return ""
	var target := wrapper_image(value)
	return value if target.is_empty() else target

static func label(url: String) -> String:
	return "embedded browser image" if url.begins_with("data:") else url.split("://", true, 1)[1].get_slice("/", 0).get_slice("?", 0).left(100)

func cancel() -> void:
	if _request:
		_request.cancel_request()
		_request.queue_free()
		_request = null

func load_image(url: String, deliver: Callable) -> void:
	cancel()
	if url.begins_with("data:image/"):
		var comma := url.find(",")
		if comma < 0 or not url.left(comma).ends_with(";base64"):
			notice.emit(NO_IMAGE)
			return
		if url.length() - comma - 1 > 4 * ceili(MAX_BYTES / 3.0):
			notice.emit("Dropped image exceeds the 16 MiB limit")
			return
		_decode(Marshalls.base64_to_raw(url.substr(comma + 1)), deliver)
		return
	if not _http(url):
		notice.emit(NO_IMAGE)
		return
	_request = HTTPRequest.new()
	add_child(_request)
	_request.body_size_limit = MAX_BYTES
	_request.timeout = 20.0
	_request.max_redirects = 4
	_request.request_completed.connect(_on_download.bind(_request, deliver), CONNECT_ONE_SHOT)
	var err := _request.request(url)
	if err != OK:
		cancel()
		notice.emit("Cannot open the dropped image URL: " + error_string(err))

func _on_download(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, job: HTTPRequest, deliver: Callable) -> void:
	if job != _request: return
	_request = null
	job.queue_free()
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		notice.emit("Dropped image exceeds the 16 MiB limit")
	elif result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		var reason := "HTTP %d" % status if status > 0 else "network error"
		var hint := " The site may block cross-origin reads (CORS)." if OS.has_feature("web") else ""
		notice.emit("Image download failed (%s).%s Save the image and drop the file instead." % [reason, hint])
	else:
		_decode(body, deliver)

func _decode(body: PackedByteArray, deliver: Callable) -> void:
	if body.size() > MAX_BYTES:
		notice.emit("Dropped image exceeds the 16 MiB limit")
		return
	var image := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	# URLs need not have extensions, and image searches often return HTML instead.
	if body.size() >= 12:
		var size := _dimensions(body)
		if size.x < 1 or size.y < 1:
			notice.emit(NO_IMAGE)
			return
		if size.x > 16384 or size.y > 16384 or size.x * size.y > MAX_PIXELS:
			notice.emit("Dropped image exceeds the 16 megapixel or 16384 pixels per side limit")
			return
		if body[0] == 0x89: err = image.load_png_from_buffer(body)
		elif body[0] == 0xff: err = image.load_jpg_from_buffer(body)
		else: err = image.load_webp_from_buffer(body)
	if err != OK or image.is_empty():
		notice.emit(NO_IMAGE)
		return
	image.generate_mipmaps()
	deliver.call(ImageTexture.create_from_image(image))

# Check encoded dimensions before a short network response can allocate an
# oversized bitmap. The image loader still validates the complete bitstream.
static func _dimensions(b: PackedByteArray) -> Vector2i:
	if b.size() >= 24 and b.slice(0, 8).hex_encode() == "89504e470d0a1a0a":
		var header := StreamPeerBuffer.new()
		header.big_endian = true
		header.data_array = b.slice(16, 24)
		return Vector2i(header.get_u32(), header.get_u32())
	if b.size() >= 30 and b.slice(0, 4).get_string_from_ascii() == "RIFF" and b.slice(8, 12).get_string_from_ascii() == "WEBP":
		match b.slice(12, 16).get_string_from_ascii():
			"VP8X": return Vector2i(1 + (b.decode_u32(24) & 0xffffff), 1 + (b.decode_u16(27) | (b[29] << 16)))
			"VP8L": return Vector2i(1 + (b.decode_u16(21) & 0x3fff), 1 + ((b.decode_u32(21) >> 14) & 0x3fff))
			"VP8 ": return Vector2i(b.decode_u16(26) & 0x3fff, b.decode_u16(28) & 0x3fff)
	if b[0] == 0xff and b[1] == 0xd8:
		var pos := 2
		while pos + 8 < b.size() and b[pos] == 0xff:
			pos += 1
			if b[pos] == 0xff: continue
			var marker := b[pos]
			var length := (b[pos + 1] << 8) | b[pos + 2]
			if length < 2 or marker == 0xda or marker == 0xd9: break
			if marker in [0xc0, 0xc1, 0xc2]:
				return Vector2i((b[pos + 6] << 8) | b[pos + 7], (b[pos + 4] << 8) | b[pos + 5])
			pos += 1 + length
	return Vector2i.ZERO
