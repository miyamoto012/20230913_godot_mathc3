extends Node2D

enum State {
	DISPLAY_UPDATE,
	WAITING_INPUT
}

enum Mouse_Input{
	PRESS,
	RELEASE,
	NONE,
}

#最大列数
const WIDTH: int = 7
#最大行数
const HEIGHT: int = 7

@export var offset: int
@export var y_offset: int


var state: State

#
var all_dots = []

#Dotを配置しない座標を集めた配列
var empty_spaces: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(0, 6),
	Vector2i(6, 0),
	Vector2i(6, 6),
	Vector2i(2, 3),
	Vector2i(3, 3),
	Vector2i(4, 3),
]

var destroy_timer := Timer.new()
var collapse_timer := Timer.new()
var refill_timer := Timer.new()

#スワップ元のドット
var dot_one: Dot = null
#スワップ先のドット
var dot_two: Dot = null

#スワップ元のグリッド座標
var swap_grid := Vector2i(0,0)
#スワップ元からスワップ先への向き
var swap_direction := Vector2i(0,0)

#左マウスボタンを押下したグリッド座標
var _pressed_grid := Vector2i(0,0)
#左マウスボタンを離したグリッド座標
var _released_grid := Vector2i(0,0)
#左マウスボタンが押下されている
var _is_press: bool = false


@onready var x_start = ((get_window().size.x / 2.0) - ((WIDTH/2.0) * offset ) + (offset / 2))
@onready var y_start = ((get_window().size.y / 2.0) + ((HEIGHT/2.0) * offset ) - (offset / 2))

#出現するドットの種類をまとめた配列
@onready var possible_dots: Array = [
	preload("res://scenes/dots/dot_blue.tscn"),
	preload("res://scenes/dots/dot_green.tscn"),
	preload("res://scenes/dots/dot_pink.tscn"),
	preload("res://scenes/dots/dot_red.tscn"),
	preload("res://scenes/dots/dot_yellow.tscn"),
]


func _ready()->void:
	state = State.WAITING_INPUT
	setup_timers()
	randomize()
	all_dots = initialize_2d_array()
	spawn_dots()


func setup_timers()->void:
	destroy_timer.connect("timeout", Callable(self, "destroy_matches"))
	destroy_timer.set_one_shot(true)
	destroy_timer.set_wait_time(0.2)
	add_child(destroy_timer)
	
	collapse_timer.connect("timeout", Callable(self, "collapse_columns"))
	collapse_timer.set_one_shot(true)
	collapse_timer.set_wait_time(0.2)
	add_child(collapse_timer)

	refill_timer.connect("timeout", Callable(self, "refill_columns"))
	refill_timer.set_one_shot(true)
	refill_timer.set_wait_time(0.2)
	add_child(refill_timer)
	
	
func initialize_2d_array()->Array:
	var array = []
	for i_c in WIDTH:
		array.append([])
		for i_r in HEIGHT:
			array[i_c].append(null)
	return array


func spawn_dots():
	for i_c in WIDTH:
		for i_r in HEIGHT:
			if !empty_spaces.has(Vector2i(i_c, i_r)):
				var dot_instance: Dot = possible_dots.pick_random().instantiate()
				var loops: int = 0
				#　配置するdotがマッチしていれば置きなおし
				while (match_at(i_c, i_r, dot_instance.get_color()) && loops < 100):
					loops += 1
					dot_instance = possible_dots.pick_random().instantiate()
				add_child(dot_instance)
				dot_instance.position = grid_to_pixel(i_c, i_r)
				all_dots[i_c][i_r] = dot_instance
			

func match_at(column: int, row: int, color: String)->bool:
	if column > 1:
		if all_dots[column - 1][row] != null && all_dots[column - 2][row] != null:
			if all_dots[column - 1][row].get_color() == color && all_dots[column - 2][row].get_color() == color:
				return true
	if row > 1:
		if all_dots[column][row - 1] != null && all_dots[column][row - 2] != null:
			if all_dots[column][row - 1].get_color() == color && all_dots[column][row - 2].get_color() == color:
				return true
	return false


#グリッド座標からグローバル座標へ変換する
func grid_to_pixel(column: int, row: int)->Vector2:
	var new_x = x_start + offset * column
	var new_y = y_start + -offset * row
	return Vector2(new_x, new_y)


#グローバル座標からグリッド座標へ変換する	
func pixel_to_grid(pixel_x: float ,pixel_y: float)->Vector2i:
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2i(new_x, new_y)


#grid_positionがパズルの範囲内か調べる
func is_in_grid(grid_position: Vector2i)->bool:
	if grid_position.x >= 0 && grid_position.x < WIDTH:
		if grid_position.y >= 0 && grid_position.y < HEIGHT:
			return true
	return false
	
	
func _process(_delta)->void:
	if state == State.WAITING_INPUT:
		if touch_input() != Mouse_Input.RELEASE:
			return
		
		var direction = touch_difference(_pressed_grid, _released_grid)
		if direction == Vector2i.ZERO:
			return
		
		swap_dots(_pressed_grid.x, _pressed_grid.y, direction)
		
		find_matches()
		
		await get_tree().create_timer(0.2).timeout
		
		destroy_matches()
		


func touch_input()->Mouse_Input:
	var mouse_position = get_global_mouse_position()
	var mouse_grid_position = pixel_to_grid(mouse_position.x, mouse_position.y)
	
	if Input.is_action_just_pressed("ui_touch"):
		if is_in_grid(mouse_grid_position):
			_pressed_grid = mouse_grid_position
			_is_press = true
			return Mouse_Input.PRESS
	if Input.is_action_just_released("ui_touch"):
		if is_in_grid(mouse_grid_position) && _is_press:
			_released_grid = mouse_grid_position
			_is_press = false
			return Mouse_Input.RELEASE
	return Mouse_Input.NONE


func swap_dots(column: int, row: int, direction: Vector2i)->void:
	var first_dot: Dot = all_dots[column][row]
	var other_dot: Dot = all_dots[column + direction.x][row + direction.y]
	
	if first_dot != null && other_dot != null:
		store_info(first_dot, other_dot, Vector2i(column, row), direction)
		state = State.DISPLAY_UPDATE
		all_dots[column][row] = other_dot
		all_dots[column + direction.x][row + direction.y] = first_dot
		first_dot.fall_tween(grid_to_pixel(column + direction.x, row + direction.y))
		other_dot.fall_tween(grid_to_pixel(column, row))


func store_info(first_dot: Dot, other_dot: Dot, grid: Vector2i, direciton: Vector2i)->void:
	dot_one = first_dot
	dot_two = other_dot
	swap_grid = grid
	swap_direction = direciton


func swap_back()->void:
	if dot_one != null && dot_two != null:
		swap_dots(swap_grid.x, swap_grid.y, swap_direction)
	state = State.WAITING_INPUT


func touch_difference(grid_1: Vector2i, grid_2: Vector2i)->Vector2i:
	var difference := grid_2 - grid_1
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			return Vector2i(1, 0)
		elif difference.x < 0:
			return Vector2i(-1, 0)
	elif abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			return Vector2i(0, 1)
		elif difference.y < 0:
			return Vector2i(0, -1)
	return Vector2i.ZERO

	
func find_matches()->void:
	for i_c in WIDTH:
		for i_r in HEIGHT:
			if all_dots[i_c][i_r] != null:
				var current_color = all_dots[i_c][i_r].get_color()
				if i_c > 0 && i_c < WIDTH -1:
					if all_dots[i_c - 1][i_r] != null && all_dots[i_c + 1][i_r] != null:
						if all_dots[i_c - 1][i_r].get_color() == current_color && all_dots[i_c + 1][i_r].get_color() == current_color:
							match_and_dim(all_dots[i_c - 1][i_r])
							match_and_dim(all_dots[i_c][i_r])
							match_and_dim(all_dots[i_c + 1][i_r])
				if i_r > 0 && i_r < HEIGHT -1:
					if all_dots[i_c][i_r - 1] != null && all_dots[i_c][i_r + 1] != null:
						if all_dots[i_c][i_r - 1].get_color() == current_color && all_dots[i_c][i_r + 1].get_color() == current_color:
							match_and_dim(all_dots[i_c][i_r - 1])
							match_and_dim(all_dots[i_c][i_r])
							match_and_dim(all_dots[i_c][i_r + 1])


func match_and_dim(dot: Dot)->void:
	dot.set_matched(true)
	dot.dim()

#matched=trueの値を持つdotを削除する
func destroy_matches()->void:
	var was_matched = false
	for i_c in WIDTH:
		for i_r in HEIGHT:
			if all_dots[i_c][i_r] != null:
				if all_dots[i_c][i_r].get_matched():
					was_matched = true
					all_dots[i_c][i_r].queue_free()
					all_dots[i_c][i_r] = null
	if was_matched:
		collapse_timer.start()
	else:
		swap_back()

#削除されて空いた空間に上にあるdotを下に詰める
func collapse_columns()->void:
	for i_c in WIDTH:
		for i_r in HEIGHT:
			if all_dots[i_c][i_r] == null && !empty_spaces.has(Vector2i(i_c,i_r)):
				for j_r in range(i_r + 1, HEIGHT):
					if all_dots[i_c][j_r] != null:
						all_dots[i_c][j_r].fall_tween(grid_to_pixel(i_c, i_r))
						all_dots[i_c][i_r] = all_dots[i_c][j_r]
						all_dots[i_c][j_r] = null
						break
	refill_timer.start()

#dotを下に詰めた際に上に生じた空間にdotを補充する
func refill_columns()->void:
	for i_c in WIDTH:
		for i_r in HEIGHT:
			if all_dots[i_c][i_r] == null && !empty_spaces.has(Vector2i(i_c,i_r)):
				var dot_instance: Dot = possible_dots.pick_random().instantiate()
				var loops = 0
				while (match_at(i_c, i_r, dot_instance.get_color()) && loops < 100):
					loops += 1
					dot_instance = possible_dots.pick_random().instantiate()
				add_child(dot_instance)
				dot_instance.position = grid_to_pixel(i_c, i_r - y_offset)
				dot_instance.fall_tween(grid_to_pixel(i_c,i_r))
				all_dots[i_c][i_r] = dot_instance
	after_refill()

#dotの補充後に再度マッチのチェックを
func after_refill()->void:
	for i_c in WIDTH:
		for i_r in HEIGHT:
			if all_dots[i_c][i_r] != null:
				if match_at(i_c, i_r, all_dots[i_c][i_r].get_color()):
					find_matches()
					destroy_timer.start()
					return
	state = State.WAITING_INPUT
