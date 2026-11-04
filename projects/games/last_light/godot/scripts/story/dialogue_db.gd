class_name DialogueDB
extends RefCounted
## Parser for THE LAST LIGHT's .dlg dialogue scripts (data/story/*.dlg). One file may hold many
## conversations. Format (one statement per line, # comments):
##
##   == conv_id  mode=radio|person|thought  [channel=16]
##   SPEAKER: line of dialogue                 (speaker ids: CALLUM, MORAG, RORY, ELSPETH, VISITOR, ROSS, ...)
##   ~ narration / thought (italic)
##   [if <expr>] SPEAKER: conditional line     (any statement may be prefixed by [if ...])
##   * Choice text -> label                    (choices gather until the next non-choice line)
##   * [if <expr>] Choice text -> label
##   = label                                   (jump target inside the conversation)
##   -> label | -> END | -> @other_conv
##   ! action arg arg...                       (set/add/clue/objective/event/wait/sfx/static/pause ...)
##
## Expressions are evaluated by StoryState.eval() (Godot Expression; e.g. flag("x") and rel("morag") > 0).

var convs := {}          # id -> {id, mode, meta, steps: Array, labels: {label: index}}
var errors: Array[String] = []


func load_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		errors.append("cannot open %s" % path)
		return
	for f in d.get_files():
		if f.ends_with(".dlg"):
			parse_text(FileAccess.get_file_as_string(path.path_join(f)), f)


func parse_text(text: String, source := "") -> void:
	var cur: Dictionary = {}
	var pending_choices: Array = []
	var lineno := 0
	for raw in text.split("\n"):
		lineno += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var cond := ""
		if line.begins_with("[if "):
			var close := line.find("]")
			cond = line.substr(4, close - 4).strip_edges()
			line = line.substr(close + 1).strip_edges()
		if line.begins_with("=="):
			_flush_choices(cur, pending_choices)
			var parts := line.substr(2).strip_edges().split(" ", false)
			var meta := {}
			for p in parts.slice(1):
				var kv := p.split("=", true, 1)
				if kv.size() == 2:
					meta[kv[0]] = kv[1]
			cur = {"id": parts[0], "mode": meta.get("mode", "radio"), "meta": meta, "steps": [], "labels": {}, "source": source}
			if convs.has(parts[0]):
				errors.append("%s:%d duplicate conversation %s" % [source, lineno, parts[0]])
			convs[parts[0]] = cur
			continue
		if cur.is_empty():
			errors.append("%s:%d statement outside a conversation" % [source, lineno])
			continue
		if line.begins_with("*"):
			var body := line.substr(1).strip_edges()
			var ccond := cond
			if body.begins_with("[if "):
				var close2 := body.find("]")
				ccond = body.substr(4, close2 - 4).strip_edges()
				body = body.substr(close2 + 1).strip_edges()
			var target := ""
			var arrow := body.rfind("->")
			if arrow >= 0:
				target = body.substr(arrow + 2).strip_edges()
				body = body.substr(0, arrow).strip_edges()
			pending_choices.append({"text": body, "goto": target, "if": ccond})
			continue
		_flush_choices(cur, pending_choices)
		var step := {"if": cond, "src": "%s:%d" % [source, lineno]}
		if line.begins_with("= "):
			cur["labels"][line.substr(2).strip_edges()] = cur["steps"].size()
			continue
		elif line.begins_with("->"):
			step["kind"] = "goto"
			step["goto"] = line.substr(2).strip_edges()
		elif line.begins_with("!"):
			var args := line.substr(1).strip_edges().split(" ", false)
			step["kind"] = "action"
			step["action"] = args[0]
			step["args"] = Array(args.slice(1))
			step["raw"] = line.substr(1).strip_edges().substr(args[0].length()).strip_edges()
		elif line.begins_with("~"):
			step["kind"] = "line"
			step["speaker"] = ""
			step["text"] = line.substr(1).strip_edges()
		else:
			var colon := line.find(":")
			if colon <= 0 or line.substr(0, colon) != line.substr(0, colon).to_upper():
				errors.append("%s:%d cannot parse: %s" % [source, lineno, line])
				continue
			step["kind"] = "line"
			step["speaker"] = line.substr(0, colon).strip_edges()
			step["text"] = line.substr(colon + 1).strip_edges()
		cur["steps"].append(step)
	_flush_choices(cur, pending_choices)


func _flush_choices(cur: Dictionary, pending: Array) -> void:
	if pending.is_empty() or cur.is_empty():
		return
	cur["steps"].append({"kind": "choice", "choices": pending.duplicate(), "if": ""})
	pending.clear()


## Static checks: every goto/choice target exists. Returns problems.
func validate() -> Array[String]:
	var out: Array[String] = errors.duplicate()
	for id in convs:
		var c: Dictionary = convs[id]
		for s in c["steps"]:
			var targets: Array = []
			if s["kind"] == "goto":
				targets.append(s["goto"])
			elif s["kind"] == "choice":
				for ch in s["choices"]:
					if ch["goto"] != "":
						targets.append(ch["goto"])
			for t in targets:
				if t == "END" or t == "":
					continue
				if t.begins_with("@"):
					if not convs.has(t.substr(1)):
						out.append("%s: unknown conversation %s" % [id, t])
				elif not c["labels"].has(t):
					out.append("%s: unknown label %s" % [id, t])
	return out
