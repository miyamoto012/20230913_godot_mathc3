class_name Dot

extends Node2D

@export var _color: String = ""

var _matched: bool = false

@onready var _sprite = $Sprite2D


func get_color()->String:
	return _color


func set_matched(value: bool)->void:
	_matched = value

	
func get_matched()->bool:
	return _matched

		
func fall_tween(target_position: Vector2)->void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, 'position', target_position, 0.2)


#半透明にする
func dim()->void:
	_sprite.modulate = Color(1, 1, 1, 0.5)
