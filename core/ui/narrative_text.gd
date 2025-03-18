extends Control

signal typing_completed

@export var text_speed: float = 0.05  # Seconds per character
@export_subgroup("UI")
@export var text_label: RichTextLabel

var _original_text: String = ""
var _displayed_chars: int = 0
var _typing_timer: Timer
var _is_typing: bool = false

var _continue_indicator: String = "▼"  # Could also use "→" or "►" depending on your style
var _blink_time: float = 0.0
const BLINK_SPEED: float = 2.0  # Blinks per second

func _ready() -> void:
	_typing_timer = Timer.new()
	add_child(_typing_timer)
	_typing_timer.timeout.connect(_on_type_timer_timeout)

func _process(delta: float) -> void:
	if not _is_typing:
		_blink_time += delta * BLINK_SPEED
		if fmod(_blink_time, 2.0) < 1.0:
			text_label.text = _original_text + "\n" + _continue_indicator
		else:
			text_label.text = _original_text + "\n" + "  "  # Spaces to maintain layout

func display_text(text: String) -> void:
	_original_text = text
	text_label.text = ""
	_displayed_chars = 0
	_is_typing = true
	_typing_timer.start(text_speed)

func _on_type_timer_timeout() -> void:
	if _displayed_chars < _original_text.length():
		_displayed_chars += 1
		text_label.text = _original_text.substr(0, _displayed_chars)
		# Optional: Play typing sound here
	else:
		_typing_timer.stop()
		_is_typing = false
		text_label.text = _original_text + "\n" + _continue_indicator
		emit_signal("typing_completed")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if _is_typing:
			# Skip typing animation
			_displayed_chars = _original_text.length()
			_typing_timer.stop()
			_is_typing = false
			text_label.text = _original_text + "\n" + _continue_indicator
			emit_signal("typing_completed")
