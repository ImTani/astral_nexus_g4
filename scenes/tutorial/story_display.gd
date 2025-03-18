extends RichTextLabel

signal text_completed

const CHAR_DELAY = 0.03
var display_timer: Timer
var current_text = ""
var target_text = ""
var current_char_index = 0

func _ready():
	display_timer = Timer.new()
	display_timer.wait_time = CHAR_DELAY
	display_timer.one_shot = false
	display_timer.timeout.connect(_on_display_timer_timeout)
	add_child(display_timer)

func display_text(text: String):
	target_text = text
	current_text = ""
	current_char_index = 0
	display_timer.start()

func _on_display_timer_timeout():
	if current_char_index >= target_text.length():
		display_timer.stop()
		emit_signal("text_completed")
		return
	
	current_text += target_text[current_char_index]
	text = current_text
	current_char_index += 1

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Skip text animation
			current_text = target_text
			text = current_text
			display_timer.stop()
			emit_signal("text_completed")
