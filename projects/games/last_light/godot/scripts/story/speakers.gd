class_name Speakers
extends RefCounted
## Who is speaking, as the PLAYER is allowed to know it (Stage 3A). One table drives the name label,
## the identity card, the portrait (3C), the dialogue history and the backlog, so a hidden identity can't
## leak through any of them.
##   name  : display name          call / sub : identity card lines   art : card drawing
##   where : "radio"  always a transmission (they are never in the room)
##           "room"   physically present: person subtitles, even inside a radio conversation
##           "mode"   follows the conversation's mode (the keeper himself)
##   hidden_as / reveal : shown as another speaker until the reveal flag is set (Ross -> the man at the door)

const TABLE := {
	"MORAG": {"name": "Morag Fraser", "call": "STORNOWAY COASTGUARD", "sub": "HM Coastguard · radio officer M. Fraser", "art": "station", "where": "radio"},
	"RORY": {"name": "Rory Bain", "call": "KITTIWAKE  SY 37", "sub": "Fishing · skipper R. Bain", "art": "fishing", "where": "radio"},
	"HECTOR": {"name": "Hector Macleod", "call": "GANNET  SY 112", "sub": "Schooner · master H. Macleod", "art": "schooner", "where": "radio"},
	"CORRIE": {"name": "Corrie May", "call": "CORRIE MAY  BRD 9", "sub": "Fishing", "art": "fishing", "where": "radio"},
	"LOWESTOFT": {"name": "Lowestoft Star", "call": "LOWESTOFT STAR  LT 401", "sub": "Schooner", "art": "schooner", "where": "radio"},
	"ELSPETH": {"name": "Elspeth Ross", "call": "IONA STAR  ·  GMXQ", "sub": "Coaster · 1st mate E. Ross", "art": "steamer", "where": "radio"},
	"MARY ELLEN": {"name": "Mary Ellen", "call": "MARY ELLEN  SY 214", "sub": "Registry: LOST 15.11.1953", "art": "fishing", "where": "radio"},
	"VISITOR": {"name": "The man at the door", "call": "", "sub": "", "art": "", "where": "room"},
	"ROSS": {"name": "Alasdair Ross", "call": "MARY ELLEN  SY 214", "sub": "A. Ross, master", "art": "fishing", "where": "room",
		"hidden_as": "VISITOR", "reveal": "knows_name"},
	"CALLUM": {"name": "Callum", "call": "NORTH POINT LIGHT", "sub": "C. Mackay, principal keeper", "art": "station", "where": "mode"},
}


## The speaker as presented now. `state` may be null (tests, previews): hidden identities stay hidden.
## Returns {id, name, call, sub, art, where}; `id` is the id the player sees (VISITOR for an unrevealed ROSS).
static func resolve(id: String, state: StoryState = null) -> Dictionary:
	if id == "":
		return {"id": "", "name": "", "call": "", "sub": "", "art": "", "where": "mode"}
	var e: Dictionary = TABLE.get(id, {})
	if e.has("hidden_as") and (state == null or not state.has_flag(String(e["reveal"]))):
		return resolve(String(e["hidden_as"]), state)
	return {"id": id, "name": String(e.get("name", id.capitalize())), "call": String(e.get("call", "")),
		"sub": String(e.get("sub", "")), "art": String(e.get("art", "")), "where": String(e.get("where", "mode"))}


## How a line is drawn: "radio" (panel + card), "person" (named subtitle), "thought" (italic, Callum's
## mind), "sound" (a caption for a sound, e.g. [Three slow knocks]).
##   kind : "speech" | "thought" | "sound"    tag : "" | "room" | "radio" (SPEAKER@room: in the script)
static func look(kind: String, speaker_where: String, tag: String, conv_mode: String) -> String:
	if kind == "sound":
		return "sound"
	if kind == "thought":
		return "thought"
	if tag == "room":
		return "person"
	if tag == "radio":
		return "radio"
	if speaker_where == "radio":
		return "radio"
	if speaker_where == "room":
		return "person"
	return "person" if conv_mode == "thought" else conv_mode   # Callum speaking aloud in a thought scene


## The words of a sound caption without the brackets the script may already carry ("> [Three knocks]").
static func caption_text(t: String) -> String:
	t = t.strip_edges()
	if t.begins_with("[") and t.ends_with("]"):
		t = t.substr(1, t.length() - 2).strip_edges()
	return t


## History entries saved before Stage 3A stored raw ids ("ROSS" before the reveal). Rewrite them to what
## the player was shown, with the same rules as a live line.
static func sanitize_history(history: Array, state: StoryState) -> Array:
	var out: Array = []
	for e in history:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e.duplicate()
		if not d.has("name"):
			var r := resolve(String(d.get("speaker", "")), null if String(d.get("speaker", "")) == "ROSS" else state)
			d["speaker"] = r["id"]
			d["name"] = r["name"]
			if not d.has("look"):
				var kind := "thought" if r["id"] == "" else "speech"
				d["look"] = "person" if d.get("choice", false) else look(kind, r["where"], "", String(d.get("mode", "radio")))
		out.append(d)
	return out
