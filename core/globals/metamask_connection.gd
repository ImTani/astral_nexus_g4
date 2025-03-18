class_name MetaMaskConnector
extends Node

signal wallet_connected(account: String)
signal wallet_connection_failed(error: String)

var wallet_address: String = ""
var is_connected: bool = false
var _connection_callback
var metamask_interface

func _ready() -> void:
	if not OS.has_feature('web'):
		push_error("MetaMaskConnector is only available in HTML5 exports")
		return
		
	metamask_interface = JavaScriptBridge.get_interface("MetaMaskInterface")
	if not metamask_interface:
		push_error("MetaMaskInterface not found")
		return
		
	_connection_callback = JavaScriptBridge.create_callback(_handle_connection_result)
	_check_existing_connection()

func _check_existing_connection() -> void:
	# Create a callback to handle the ethereum.request response
	var accounts_callback = JavaScriptBridge.create_callback(_handle_existing_accounts)
	var ethereum = JavaScriptBridge.get_interface("ethereum")
	if ethereum:
		ethereum.request({"method": "eth_accounts"}).then(accounts_callback)

func _handle_existing_accounts(args: Array) -> void:
	if not args.is_empty() and args[0] is Array and not args[0].is_empty():
		wallet_address = args[0][0]
		is_connected = true
		wallet_connected.emit(wallet_address)

func connect_wallet() -> void:
	if is_connected:
		wallet_connected.emit(wallet_address)  # Re-emit for any new listeners
		return
		
	if not metamask_interface:
		wallet_connection_failed.emit("MetaMask interface not found")
		return
	
	metamask_interface.connectWallet().then(_connection_callback)

func _handle_connection_result(args: Array) -> void:
	if args.is_empty():
		wallet_connection_failed.emit("No response received")
		return
		
	var result = args[0]
	if result.success:
		wallet_address = result.account
		is_connected = true
		wallet_connected.emit(wallet_address)
	else:
		var error_message = "Connection failed"
		match result.error:
			"NOT_INSTALLED":
				error_message = "MetaMask is not installed"
			"WRONG_CHAIN":
				error_message = "Please switch to EDU Chain TestNet"
			"USER_REJECTED":
				error_message = "Connection rejected by user"
			"CHAIN_ADD_FAILED":
				error_message = "Failed to add EDU Chain TestNet"
			"CHAIN_SWITCH_FAILED":
				error_message = "Failed to switch to EDU Chain TestNet"
		wallet_connection_failed.emit(error_message)
