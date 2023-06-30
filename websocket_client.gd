# ------------------------------------------------------------------------------
# @file        websocket_client.gd
# @brief       WSClient
# @author      masvetak
# @version     0.1.0
# ------------------------------------------------------------------------------

class_name WSClient extends Node

signal connected
signal disconnected
signal data_received
signal host_updated(host_url)

var _web_socket: WebSocketPeer = null
var _web_socket_data_serializer: DataSerializer = null
var _web_socket_connected: bool = false

var _web_socket_connect_timer: Timer = null
var _web_socket_auto_connect_set: bool = false

var _web_socket_heartbeat_timer: Timer = null
var _web_socket_heartbeat_set: bool = false
var _web_socket_heartbeat_message: Dictionary = {}

var _host_url: String = ""

# ------------------------------------------------------------------------------
# Data serialization classes
# ------------------------------------------------------------------------------

class DataSerializer:
	func serialize(_data: Dictionary):
		pass
	
	func deserialize(_data: PackedByteArray):
		pass

class JSONDataSerializer extends DataSerializer:
	func serialize(data: Dictionary):
		return JSON.stringify(data).to_utf8_buffer()
	
	func deserialize(data: PackedByteArray):
		return JSON.parse_string(data.get_string_from_utf8())

class MsgpckDataSerializer extends DataSerializer:
	func serialize(data: Dictionary):
		var encode_result = Msgpck.encode(data)
		if encode_result.error == OK:
			return encode_result.get('result')
		else:
			print("[MsgpckDataSerializer] Msgpck encode error with code: %d, reason: %s" % [encode_result.error, encode_result.error_string])
			return null
	
	func deserialize(data: PackedByteArray):
		var decode_result = Msgpck.decode(data)
		if decode_result.error == OK:
			return decode_result.get('result')
		else:
			print("[MsgpckDataSerializer] Msgpck decode error with code: %d, reason: %s" % [decode_result.error, decode_result.error_string])
			return null

# ------------------------------------------------------------------------------
# Build-in methods
# ------------------------------------------------------------------------------

func _init(web_socket_data_serializer) -> void:
	_web_socket_data_serializer = web_socket_data_serializer
	_web_socket = WebSocketPeer.new()

func _ready() -> void:
	self.set_process(false)

func _process(_delta: float):
	_web_socket.poll()
	var web_socket_state = _web_socket.get_ready_state()
	match web_socket_state:
		WebSocketPeer.STATE_OPEN:
			if not get_connected():
				var selected_protocol: String = _web_socket.get_selected_protocol()
				_connection_established(selected_protocol)
			
			while _web_socket.get_available_packet_count():
				_data_received(_web_socket.get_packet())
			
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			var code: int = _web_socket.get_close_code()
			var reason: String = _web_socket.get_close_reason()
			_connection_closed(code, reason)

# ------------------------------------------------------------------------------
# Public methods
# ------------------------------------------------------------------------------

func set_auto_connect(wait_time_secounds: float = 5.0) -> void:
	_web_socket_connect_timer = Timer.new()
	_web_socket_connect_timer.wait_time = wait_time_secounds
	
	_web_socket_auto_connect_set = true
	var _err = _web_socket_connect_timer.timeout.connect(_on_web_socket_connect_timer_timeout)
	
	self.add_child(_web_socket_connect_timer)

func set_heartbeat(period_secounds: float = 30.0, message = {}) -> void:
	_web_socket_heartbeat_timer = Timer.new()
	_web_socket_heartbeat_timer.wait_time = period_secounds
	
	_web_socket_heartbeat_set = true
	_web_socket_heartbeat_message = message
	var _err = _web_socket_heartbeat_timer.timeout.connect(_on_web_socket_heartbeat_timer_timeout)
	
	self.add_child(_web_socket_heartbeat_timer)

func connect_to_host(host_url: String) -> void:
	_host_url = host_url
	self.host_updated.emit(_host_url)
	
	print("[WSCLIENT] connecting to host: ", _host_url)
	if _web_socket.connect_to_url("{0}".format([host_url])) == OK:
		self.set_process(true)

func disconnect_from_host() -> void:
	print("[WSCLIENT] disconnecting from host: ", _host_url)
	_web_socket_auto_connect_set = false
	_web_socket_heartbeat_set = false
	_web_socket.close()

func get_connected() -> bool:
	return _web_socket_connected

func send(data: Dictionary) -> bool:
	if not _web_socket_connected:
		return false
	
	# Data serialization
	var serialized_data = _web_socket_data_serializer.serialize(data)
	if serialized_data == null:
		return false
	
	# Send
	var error = _web_socket.send(serialized_data)
	if error != OK:
		print("[WSCLIENT] Send error with code: %d" % [error])
		return false
	
	return true

func get_host_url() -> String:
	return _host_url

# ------------------------------------------------------------------------------
# Private methods
# ------------------------------------------------------------------------------

func _connection_established(protocol: String) -> void:
	print("[WSCLIENT] connection established! Selected protocol: %s" % [protocol])
	
	_web_socket_connected = true
	self.connected.emit()
	
	if _web_socket_auto_connect_set:
		_web_socket_connect_timer.stop()
	
	if _web_socket_heartbeat_set:
		_web_socket_heartbeat_timer.start()

func _data_received(data) -> void:
	# Data deserialization
	var result_data = _web_socket_data_serializer.deserialize(data)
	if result_data == null:
		return
	
	# Data decompression
	if result_data.has('mctx') and result_data['mctx'].has('_mode_'):
		var mode = result_data['mctx']['_mode_']
		if mode.has('compression'):
			var compression_data = result_data['data']
			compression_data = compression_data.decompress(mode['size'], FileAccess.COMPRESSION_ZSTD)
			if mode.has('packed') and mode['packed']:
				compression_data = Msgpck.decode(compression_data)['result']
			result_data['data'] = compression_data
	
	self.data_received.emit(result_data)

func _connection_closed(code: int, reason: String) -> void:
	print("[WSCLIENT] connection closed with code %d, reason: %s. Was clean close: %s" % [code, reason, code != -1])
	
	_web_socket_connected = false
	self.disconnected.emit()
	
	if _web_socket_auto_connect_set:
		_web_socket_connect_timer.start()
	
	if _web_socket_heartbeat_set:
		_web_socket_heartbeat_timer.stop()
	
	self.set_process(false)

func _on_web_socket_connect_timer_timeout() -> void:
	_web_socket_connect_timer.stop()
	connect_to_host(_host_url)

func _on_web_socket_heartbeat_timer_timeout() -> void:
	print("[WSCLIENT] heartbeat send!")
	var _err = self.send(_web_socket_heartbeat_message)
