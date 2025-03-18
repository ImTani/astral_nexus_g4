extends Label

@onready var wallet_interface: MetaMaskConnector = MetamaskConnection

func _ready() -> void:
	wallet_interface.wallet_connected.connect(change_text)
	wallet_interface.wallet_connection_failed.connect(_on_connection_failed)
	
	# Set initial state
	if wallet_interface.is_connected:
		change_text(wallet_interface.wallet_address)
	else:
		text = "No Wallet Connected"

func change_text(address: String) -> void:
	text = "Wallet Connected: %s" % address
	
func _on_connection_failed(error: String) -> void:
	text = "Connection Failed: %s" % error
