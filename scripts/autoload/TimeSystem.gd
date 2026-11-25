extends Node
## Manages game calendar (4 seasons x 28 days), clock (06:00-02:00), and configurable speed.

const SEASONS := ["spring", "summer", "autumn", "winter"]
const DAYS_PER_SEASON := 28
const START_HOUR := 6
const LATE_NIGHT_HOUR := 26 # 02:00 AM next calendar morning

var year: int = 1
var season_index: int = 0
var day: int = 1
var hour: int = 6
var minute: int = 0

var seconds_per_game_hour: float = 60.0 # Default: 1 real min = 1 game hour
var is_playing: bool = false
var pause_reasons: Dictionary = {}

var _accum_seconds: float = 0.0
var total_play_seconds: float = 0.0


func _process(delta: float) -> void:
	if not is_playing:
		return
	total_play_seconds += delta
	if is_time_paused():
		return
	var sec_per_ten_min := seconds_per_game_hour / 6.0
	_accum_seconds += delta
	while _accum_seconds >= sec_per_ten_min:
		_accum_seconds -= sec_per_ten_min
		advance_minutes(10)


func reset_calendar() -> void:
	year = 1
	season_index = 0
	day = 1
	hour = START_HOUR
	minute = 0
	_accum_seconds = 0.0
	total_play_seconds = 0.0
	pause_reasons.clear()


func set_paused(reason: String, paused: bool) -> void:
	if paused:
		pause_reasons[reason] = true
	else:
		pause_reasons.erase(reason)


func is_time_paused() -> bool:
	return not pause_reasons.is_empty()


func get_season() -> String:
	return SEASONS[season_index % SEASONS.size()]


func get_formatted_time() -> String:
	var disp_h := hour % 24
	var ampm := "AM" if disp_h < 12 else "PM"
	var h12 := disp_h % 12
	if h12 == 0:
		h12 = 12
	return "%02d:%02d %s" % [h12, minute, ampm]


func get_formatted_date() -> String:
	var weekday_names := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	var wd: String = str(weekday_names[(day - 1) % 7])
	return "Yr %d - %s %d (%s)" % [year, get_season().capitalize(), day, wd]


func advance_minutes(mins: int) -> void:
	minute += mins
	while minute >= 60:
		minute -= 60
		hour += 1
	EventBus.time_ticked.emit(hour, minute)
	if hour >= LATE_NIGHT_HOUR:
		EventBus.ui_toast.emit("It's past 2:00 AM! Resting until morning...", "info")
		sleep_to_next_day(true)


func sleep_to_next_day(collapsed: bool = false) -> void:
	var prev_season := get_season()
	EventBus.day_ended.emit(year, prev_season, day)

	day += 1
	if day > DAYS_PER_SEASON:
		day = 1
		season_index += 1
		if season_index >= SEASONS.size():
			season_index = 0
			year += 1
		EventBus.season_changed.emit(get_season(), year)

	hour = START_HOUR
	minute = 0
	_accum_seconds = 0.0

	if collapsed:
		PlayerState.recover_morning(0.65)
	else:
		PlayerState.recover_morning(1.0)

	EventBus.day_started.emit(year, get_season(), day)


func get_ambient_tint() -> Color:
	if hour < 8:
		return Color(0.95, 0.90, 0.85, 1.0)
	if hour < 17:
		return Color(1.0, 1.0, 1.0, 1.0)
	if hour < 20:
		return Color(0.95, 0.78, 0.68, 1.0)
	if hour < 22:
		return Color(0.62, 0.66, 0.84, 1.0)
	return Color(0.42, 0.46, 0.68, 1.0)


func serialize() -> Dictionary:
	return {
		"year": year,
		"seasonIndex": season_index,
		"day": day,
		"hour": hour,
		"minute": minute,
		"totalPlaySeconds": total_play_seconds,
		"secondsPerGameHour": seconds_per_game_hour
	}


func deserialize(data: Dictionary) -> void:
	year = maxi(1, int(data.get("year", 1)))
	season_index = clampi(int(data.get("seasonIndex", 0)), 0, 3)
	day = clampi(int(data.get("day", 1)), 1, DAYS_PER_SEASON)
	hour = clampi(int(data.get("hour", START_HOUR)), START_HOUR, LATE_NIGHT_HOUR - 1)
	minute = clampi(int(data.get("minute", 0)), 0, 50)
	total_play_seconds = maxf(0.0, float(data.get("totalPlaySeconds", 0.0)))
	seconds_per_game_hour = clampf(float(data.get("secondsPerGameHour", 60.0)), 10.0, 300.0)
