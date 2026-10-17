## Top level: title <-> match.
extends Node

var _screen: Node


func _ready() -> void:
	show_title()


func _swap(n: Node) -> void:
	if _screen:
		_screen.queue_free()
	_screen = n
	add_child(n)


func show_title() -> void:
	var t := TitleScreen.new()
	t.start_match.connect(_on_start)
	_swap(t)


func _on_start(cfg: SimTypes.MatchConfig, venue: String) -> void:
	var m := MatchView.new()
	m.finished.connect(func(_to_title: bool): show_title())
	_swap(m)
	m.setup(cfg, venue, false)
