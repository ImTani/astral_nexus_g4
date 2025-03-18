extends Button

@onready var wallet_interface: MetaMaskConnector = MetamaskConnection

func _ready():
	wallet_interface.wallet_connected.connect(_on_wallet_connected)
	wallet_interface.wallet_connection_failed.connect(_on_wallet_connection_failed)
	
	# Update button state based on initial connection status
	if wallet_interface.is_connected:
		_on_wallet_connected(wallet_interface.wallet_address)

func _on_pressed():
	wallet_interface.connect_wallet()
	disabled = true  # Disable button during connection attempt
	text = "Connecting..."

func _on_wallet_connected(address: String):
	print("Connected to wallet: ", address)
	text = address.substr(0, 6) + "..." + address.substr(-4)  # Show shortened address
	disabled = true  # Keep button disabled when connected

func _on_wallet_connection_failed(error: String):
	print("Failed to connect to wallet: ", error)
	text = "Connect Wallet"  # Reset button text
	disabled = false  # Re-enable button to allow retry
