extends Node
## Conditional seasonal weather generator + forecast system.

const WEATHER_TYPES := ["sunny", "cloudy", "rainy", "stormy", "snowy", "foggy"]

var current_weather: String = "sunny"
var tomorrow_weather: String = "sunny"
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	EventBus.day_started.connect(_on_day_started)


func reset_weather() -> void:
	current_weather = "sunny"
	tomorrow_weather = roll_weather_for_season("spring")
	EventBus.weather_changed.emit(current_weather)


func _on_day_started(_year: int, season: String, _day: int) -> void:
	current_weather = tomorrow_weather
	# Ensure season validity on season transition day 1
	if season == "winter" and current_weather in ["rainy", "stormy"]:
		current_weather = "snowy"
	elif season != "winter" and current_weather == "snowy":
		current_weather = "sunny"
	tomorrow_weather = roll_weather_for_season(season)
	EventBus.weather_changed.emit(current_weather)


func roll_weather_for_season(season: String) -> String:
	var table: Dictionary = {}
	match season:
		"spring":
			table = {"sunny": 0.45, "cloudy": 0.20, "rainy": 0.22, "stormy": 0.05, "foggy": 0.08}
		"summer":
			table = {"sunny": 0.55, "cloudy": 0.15, "rainy": 0.15, "stormy": 0.12, "foggy": 0.03}
		"autumn":
			table = {"sunny": 0.35, "cloudy": 0.25, "rainy": 0.20, "stormy": 0.05, "foggy": 0.15}
		"winter":
			table = {"sunny": 0.28, "cloudy": 0.24, "snowy": 0.38, "foggy": 0.10}
		_:
			table = {"sunny": 1.0}

	var roll := _rng.randf()
	var accum := 0.0
	for w in table.keys():
		accum += float(table[w])
		if roll <= accum:
			return str(w)
	return "sunny"


func is_watering_weather() -> bool:
	return current_weather in ["rainy", "stormy"]


func get_weather_label() -> String:
	return current_weather.capitalize()


func serialize() -> Dictionary:
	return {"current": current_weather, "tomorrow": tomorrow_weather}


func deserialize(data: Dictionary) -> void:
	var c := str(data.get("current", "sunny"))
	var t := str(data.get("tomorrow", "sunny"))
	current_weather = c if c in WEATHER_TYPES else "sunny"
	tomorrow_weather = t if t in WEATHER_TYPES else "sunny"
	EventBus.weather_changed.emit(current_weather)
