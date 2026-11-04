class_name DialogueRunner
extends RefCounted
## Walks one conversation from DialogueDB. Pure logic: the UI calls advance()/choose() and renders
## the returned presentation item. State actions (set/add/clue) are applied to StoryState here;
## other actions are returned to the caller (the StoryDirector) as {"type": "action"}.

var db: DialogueDB
var state: StoryState
var conv: Dictionary = {}
var ip := 0
var active := false
var _choices: Array = []          # visible choices of the pending choice step


func _init(database: DialogueDB, story: StoryState) -> void:
	db = database
	state = story


func start(conv_id: String) -> bool:
	if not db.convs.has(conv_id):
		push_error("unknown conversation %s" % conv_id)
		return false
	conv = db.convs[conv_id]
	ip = 0
	active = true
	_choices = []
	return true


func mode() -> String:
	return conv.get("mode", "radio")


## Returns the next thing to present:
##   {"type": "line", "speaker", "text", "mode"}
##   {"type": "choice", "choices": [{"text", "index"}]}
##   {"type": "action", "action", "args", "raw"}     (caller performs it, then calls advance() again)
##   {"type": "end"}
func advance() -> Dictionary:
	var guard := 0
	while active:
		guard += 1
		if guard > 2000:
			push_error("dialogue loop in %s" % conv.get("id", "?"))
			return _end()
		if ip >= conv["steps"].size():
			return _end()
		var s: Dictionary = conv["steps"][ip]
		ip += 1
		if s["if"] != "" and not state.eval(s["if"]):
			continue
		match s["kind"]:
			"line":
				var item := {"type": "line", "speaker": s["speaker"], "text": s["text"], "mode": mode()}
				state.history.append({"speaker": s["speaker"], "text": s["text"], "mode": mode(),
					"clock": state.sim.clock_text() if state.sim else ""})
				return item
			"goto":
				if _jump(s["goto"]):
					continue
				return _end()
			"action":
				if s["action"] in ["set", "unset", "add", "clue"]:
					state.apply_action(s["action"], s["args"])
					continue
				return {"type": "action", "action": s["action"], "args": s["args"], "raw": s["raw"]}
			"choice":
				_choices = []
				for i in s["choices"].size():
					var ch: Dictionary = s["choices"][i]
					if ch["if"] == "" or state.eval(ch["if"]):
						_choices.append({"text": ch["text"], "goto": ch["goto"], "index": _choices.size()})
				if _choices.is_empty():
					continue
				return {"type": "choice", "choices": _choices.map(func(c): return {"text": c["text"], "index": c["index"]})}
	return _end()


func choose(index: int) -> Dictionary:
	if index < 0 or index >= _choices.size():
		return advance()
	var ch: Dictionary = _choices[index]
	state.history.append({"speaker": "CALLUM", "text": ch["text"], "mode": mode(), "choice": true,
		"clock": state.sim.clock_text() if state.sim else ""})
	state.flags["last_choice_" + conv["id"]] = ch["text"]
	_choices = []
	if ch["goto"] != "" and not _jump(ch["goto"]):
		return _end()
	return advance()


func _jump(target: String) -> bool:
	if target == "END":
		return false
	if target.begins_with("@"):
		state.convs_done[conv["id"]] = true
		return start(target.substr(1))
	if conv["labels"].has(target):
		ip = conv["labels"][target]
		return true
	push_error("missing label %s in %s" % [target, conv["id"]])
	return false


func _end() -> Dictionary:
	if active:
		state.convs_done[conv["id"]] = true
	active = false
	return {"type": "end"}
