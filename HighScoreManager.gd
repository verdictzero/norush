extends Node

const SAVE_FILE = "user://high_scores.dat"
const MAX_SCORES = 10

var high_scores: Array[Dictionary] = []

func _ready():
	load_scores()

func add_score(player_name: String, score: float, distance: float, time: float):
	var new_score = {
		"name": player_name,
		"score": score,
		"distance": distance,
		"time": time,
		"efficiency": distance / time if time > 0 else 0.0,
		"date": Time.get_datetime_string_from_system()
	}
	
	high_scores.append(new_score)
	high_scores.sort_custom(func(a, b): return a.score > b.score)
	
	if high_scores.size() > MAX_SCORES:
		high_scores.resize(MAX_SCORES)
	
	save_scores()
	return get_rank(score)

func get_rank(score: float) -> int:
	for i in range(high_scores.size()):
		if high_scores[i].score <= score:
			return i + 1
	return high_scores.size() + 1

func get_high_scores() -> Array[Dictionary]:
	return high_scores

func is_high_score(score: float) -> bool:
	if high_scores.size() < MAX_SCORES:
		return true
	return score > high_scores[MAX_SCORES - 1].score

func save_scores():
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(high_scores))
		file.close()

func load_scores():
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			if data is Array:
				high_scores = data
			else:
				high_scores = []
		else:
			high_scores = []
	else:
		high_scores = []