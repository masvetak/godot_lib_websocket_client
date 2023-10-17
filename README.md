# WSClient

## Usage
### JSON data serialization example
```gdscript
class JSONDataSerializer extends WSClient.DataSerializer:
	func serialize(data: Dictionary):
		return JSON.stringify(data).to_utf8_buffer()
	
	func deserialize(data: PackedByteArray):
		return JSON.parse_string(data.get_string_from_utf8())

```

### Msgpack data serialization example
You can use this https://github.com/masvetak/godot_lib_message_pack godot library for Msgpack. Just clone the repo to your godot project or add it as submodule.
```gdscript
class MsgpckDataSerializer extends WSClient.DataSerializer:
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
```

### Example

```gdscript
extends Node

const URL = "ws://localhost:12345"

var _ws_client: WSClient = null

func _ready() -> void:
    _ws_client = WSClient.new(JSONDataSerializer.new())
    self.add_child(_ws_client)

    _ws_client.connected.connect(_on_ws_client_connected)
    _ws_client.data_received.connect(_on_ws_client_data_received)

func send(data: Dictionary) -> void:
    var _result = _ws_client.send(data)

func _on_ws_client_connected() -> void:
    print("[WSClient]: Connected!")

func _on_ws_client_data_received(received_data: Dictionary) -> void:
    print("[WSClient]: Data received: ", received_data)

```

## Contributing


Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request.
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License


Distributed under the MIT License. See `LICENSE.txt` for more information.


## Contact

Marko Švetak - [@your_twitter](https://twitter.com/your_username) - email@example.com
