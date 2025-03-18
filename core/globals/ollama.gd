extends RefCounted
class_name Ollama

signal response_chunk_received(chunk: String)
signal response_complete(full_response: String)
signal request_failed(error: String)

var ollama_url: String = "https://iris.aihello.com/ollama/api/chat"
var model_name: String = "qwen2.5:14b"
var http_request: HTTPRequest
var current_response: String = ""

func _init():
	http_request = HTTPRequest.new()
	Engine.get_main_loop().root.add_child.call_deferred(http_request)
	http_request.request_completed.connect(_on_request_completed)

func send_prompt(prompt: String, system_prompt: String = "", stream: bool = true) -> Error:
	current_response = ""  # Reset current response
	var headers = ["Content-Type: application/json"]
	var messages = []
	
	if system_prompt:
		messages.append({
			"role": "system",
			"content": system_prompt
		})
	
	messages.append({
		"role": "user",
		"content": prompt
	})
	
	var body = {
		"model": model_name,
		"messages": messages,
		"stream": stream
	}
	
	var json = JSON.stringify(body)
	print("[Ollama] Sending request with body: ", json)
	return http_request.request(ollama_url, headers, HTTPClient.METHOD_POST, json)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("[Ollama] Request completed with result: ", result)
	print("[Ollama] Response code: ", response_code)
	print("[Ollama] Headers: ", headers)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		emit_signal("request_failed", "HTTP Request failed with code: " + str(result))
		return
		
	if response_code != 200:
		emit_signal("request_failed", "Server returned error code: " + str(response_code))
		return
		
	var json_string = body.get_string_from_utf8()
	print("[Ollama] Raw response: ", json_string)
	
	# Split response into lines for NDJSON parsing
	var lines = json_string.split("\n")
	for line in lines:
		if line.strip_edges().is_empty():
			continue
			
		print("[Ollama] Processing line: ", line)
		var response = JSON.parse_string(line)
		if response == null:
			print("[Ollama] Warning: Failed to parse line: ", line)
			continue
			
		if "error" in response:
			emit_signal("request_failed", response["error"])
			return
			
		# Handle streaming message format
		if "message" in response:
			var content = response["message"].get("content", "")
			if not content.is_empty():
				print("[Ollama] Received content: ", content)
				current_response += content
				emit_signal("response_chunk_received", content)
		
		# Handle delta format (if server switches to it)
		elif "delta" in response:
			var content = response.get("delta", {}).get("content", "")
			if not content.is_empty():
				print("[Ollama] Received delta content: ", content)
				current_response += content
				emit_signal("response_chunk_received", content)
		
		if response.get("done", false):
			print("[Ollama] Stream complete, full response: ", current_response)
			emit_signal("response_complete", current_response)

func cleanup():
	if http_request:
		http_request.queue_free()
