extends Button

@export var wallet_interface: MetaMaskConnector
@export var amount_line_edit: LineEdit
var currency_amount: String

func _on_amount_text_changed(new_text:String) -> void:
	if new_text.is_valid_float():
		currency_amount = new_text

func _on_pressed() -> void:
	if currency_amount.is_valid_float():
		print("Redeeming: %s for address: %s" % [currency_amount, wallet_interface.wallet_address])
	else:
		print("Invalid amount")