extends Node

@onready var ollama = Ollama.new()
@onready var ai_label: Label = $"../../ScrollContainer/AILabel"
@onready var loading_dots: Timer = Timer.new()
var is_loading: bool = false
var dots_count: int = 0

func _ready():
	print("[OllamaButton] Initializing...")
	loading_dots.wait_time = 0.5
	loading_dots.connect("timeout", _on_loading_dots_timeout)
	add_child(loading_dots)

func _on_pressed() -> void:
	print("[OllamaButton] Button pressed")
	# Disconnect any existing connections to prevent duplicates
	if ollama.response_chunk_received.is_connected(_on_response_chunk_received):
		ollama.response_chunk_received.disconnect(_on_response_chunk_received)
	if ollama.response_complete.is_connected(_on_response_complete):
		ollama.response_complete.disconnect(_on_response_complete)
	if ollama.request_failed.is_connected(_on_request_failed):
		ollama.request_failed.disconnect(_on_request_failed)
	
	# Connect signals
	ollama.response_chunk_received.connect(_on_response_chunk_received)
	ollama.response_complete.connect(_on_response_complete)
	ollama.request_failed.connect(_on_request_failed)

	# Clear previous response and start loading state
	ai_label.text = "Thinking"
	is_loading = true
	loading_dots.start()
	print("[OllamaButton] Sending prompt...")

	# Send a prompt with streaming enabled
	var error = ollama.send_prompt("Why is the sky blue?", "You are a friendly science teacher.", true)
	print("[OllamaButton] send_prompt returned error code: ", error)

func _on_response_chunk_received(chunk: String):
	print("[OllamaButton] Received chunk: ", chunk)
	if is_loading:
		# First chunk received, clear the "Thinking..." message
		ai_label.text = ""
		is_loading = false
		loading_dots.stop()
	
	# Append the new chunk to the label
	ai_label.text += chunk

func _on_response_complete(full_response: String):
	print("[OllamaButton] Response complete!")
	is_loading = false
	loading_dots.stop()

func _on_request_failed(error: String):
	print("[OllamaButton] Request failed: ", error)
	is_loading = false
	loading_dots.stop()
	ai_label.text = "Error: " + error

func _on_loading_dots_timeout():
	if is_loading:
		dots_count = (dots_count + 1) % 4
		ai_label.text = "Thinking" + ".".repeat(dots_count)

func _exit_tree():
	print("[OllamaButton] Cleaning up...")
	loading_dots.queue_free()
	ollama.cleanup()
