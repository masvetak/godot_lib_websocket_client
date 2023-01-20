# ------------------------------------------------------------------------------
# @file        websocket_client.gd
# @brief       WSClient
# @author      masvetak
# @version     0.1.0
# ------------------------------------------------------------------------------

class_name WSClient
extends Node

signal connected()
signal disconnected()
signal data_received()
signal host_updated(host_url)

var _ws_client: WebSocketClient = null
var _ws_client_connected: bool = false

var _ws_client_connect_timer: Timer = null
var _ws_client_auto_connect: bool = false

var _ws_client_heartbeat_timer: Timer = null
var _ws_client_heartbeat_set: bool = false

var _host_url: String = ""

func _init() -> void:
	_ws_client = WebSocketClient.new()
	
	var _err = FAILED
	_err = _ws_client.connect("connection_closed", self, "_on_connection_closed")
	_err = _ws_client.connect("connection_error", self, "_on_connection_error")
	_err = _ws_client.connect("connection_established", self, "_on_connection_established")
	_err = _ws_client.connect("data_received", self, "_on_data_received")
	
	set_process(true)

func _process(_delta):
	_ws_client.poll()

func _on_connection_closed(was_clean_close: bool) -> void:
	print("[WSCLIENT] connection closed! Was clean close: ", was_clean_close)
	
	_ws_client_connected = false
	emit_signal("disconnected")
	
	if _ws_client_auto_connect:
		_ws_client_connect_timer.start()
	
	if _ws_client_heartbeat_set:
		_ws_client_heartbeat_timer.stop()

func _on_connection_error() -> void:
	print("[WSCLIENT] on connection error!")
	
	_ws_client_connected = false
	emit_signal("disconnected")
	
	if _ws_client_auto_connect:
		_ws_client_connect_timer.start()
	
	if _ws_client_heartbeat_set:
		_ws_client_heartbeat_timer.stop()

func _on_connection_established(protocol: String) -> void:
	print("[WSCLIENT] connection established! Protocol: ", protocol)
	
	_ws_client_connected = true
	emit_signal("connected")
	
	if _ws_client_auto_connect:
		_ws_client_connect_timer.stop()
	
	if _ws_client_heartbeat_set:
		_ws_client_heartbeat_timer.start()

func _on_data_received() -> void:
# JSON
#	var received_data = _ws_client.get_peer(1).get_packet().get_string_from_utf8()
#	var dict: Dictionary = parse_json(received_data)

# Msgpck
	var data_received = _ws_client.get_peer(1).get_packet()
	var dict: Dictionary = Msgpck.decode(data_received).get('result')
	
	if dict.has('mctx') and dict['mctx'].has('_mode_'):
		var mode = dict['mctx']['_mode_']
		if mode.has('compression'):
			var data = dict['data']
			data = data.decompress(mode['size'], File.COMPRESSION_ZSTD)
			if mode.has('packed') and mode['packed']:
				data = Msgpck.decode(data)['result']
			dict['data'] = data
	
	emit_signal("data_received", dict)

func _on_ws_client_connect_timer_timeout() -> void:
	_ws_client_connect_timer.stop()
	var _err = self.connect_to_host(_host_url)

func set_auto_connect(wait_time_secounds: float = 5.0) -> void:
	_ws_client_connect_timer = Timer.new()
	_ws_client_connect_timer.wait_time = wait_time_secounds
	
	_ws_client_auto_connect = true
	var _err = _ws_client_connect_timer.connect("timeout", self, "_on_ws_client_connect_timer_timeout")
	
	add_child(_ws_client_connect_timer)

func _on_ws_client_heartbeat_timer_timeout() -> void:
	print("[WSCLIENT] heartbeat send!")
	var _err = self.send({})

func set_heartbeat(period_secounds: float = 30.0, _message = {}) -> void:
	_ws_client_heartbeat_timer = Timer.new()
	_ws_client_heartbeat_timer.wait_time = period_secounds
	
	_ws_client_heartbeat_set = true
	var _err = _ws_client_heartbeat_timer.connect("timeout", self, "_on_ws_client_heartbeat_timer_timeout")
	
	add_child(_ws_client_heartbeat_timer)

func connect_to_host(host_url: String) -> bool:
	_host_url = host_url
	emit_signal("host_updated", _host_url)
	
	print("[WSCLIENT] connecting to host: ", _host_url)
	var result = _ws_client.connect_to_url("{0}".format([host_url]))
	return true if result == OK else false

func disconnect_from_host() -> void:
	print("[WSCLIENT] disconnecting from host: ", _host_url)
	_ws_client.disconnect_from_host()

func connected() -> bool:
	return _ws_client_connected

func send(data: Dictionary) -> bool:
	if not _ws_client_connected:
		return false
	
# JSON
#	var query = JSON.print(data)
#	var result = _ws_client.get_peer(1).put_packet(query.to_utf8())

# Msgpck
	var query = Msgpck.encode(data).get('result')
	var result = _ws_client.get_peer(1).put_packet(query)
	return true if result == OK else false

func get_host_url() -> String:
	return _host_url
