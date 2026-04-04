class_name WorldItem
extends Area3D
## A pickable item in the 3D world.
##
## Place in the scene with an item assigned. When the player enters the
## pickup radius, shows a prompt. Press interact to pick up.
## Auto-pickup option available for common items.


signal picked_up(item: InventoryItem, amount: int)


@export_group("Item")
## The item this world pickup represents.
@export var item: InventoryItem
## How many of this item.
@export var amount: int = 1

@export_group("Behavior")
## Automatically pick up when player enters radius (no button press).
@export var auto_pickup: bool = false
## Input action for manual pickup.
@export var interact_action: StringName = &"interact"
## Destroy after pickup.
@export var destroy_on_pickup: bool = true
## Optional: Explicit reference to the InventoryComponent. If not set, auto-discovers from player.
@export var inventory_component: InventoryComponent

@export_group("Visual")
## Rotation speed (degrees/second) for idle spin.
@export var spin_speed: float = 90.0
## Bob amplitude (units).
@export var bob_amplitude: float = 0.15
## Bob speed.
@export var bob_speed: float = 2.0
## Rarity glow color (auto-set from item rarity if not overridden).
@export var glow_color: Color = Color.TRANSPARENT

## Static: the closest in-range WorldItem this frame (only one shows prompt).
static var _focused_item: WorldItem = null
static var _focused_distance: float = INF
static var _focus_frame: int = -1

## The mesh/visual child to animate.
var _visual: Node3D
## The prompt label.
var _prompt_label: Label3D
## Whether player is in range.
var _player_in_range: bool = false
## Reference to the player node.
var _player: Node = null
## Base Y position for bobbing.
var _base_y: float = 0.0
## Time accumulator for animation.
var _time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_time = randf() * TAU  # Random start phase so items don't bob in sync

	# Find or create visual
	_visual = _find_visual()
	if not _visual and item and item.icon:
		_create_sprite_visual()

	# Create pickup prompt
	_create_prompt()

	# Set up collision
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Apply rarity glow
	if item and glow_color == Color.TRANSPARENT:
		glow_color = InventoryItem.RARITY_COLORS.get(item.rarity, Color.WHITE)


func _physics_process(_delta: float) -> void:
	# Focus competition: all in-range items compete, closest wins.
	# _physics_process runs for ALL nodes before any _process runs,
	# so by the time _process checks _focused_item, competition is settled.
	var frame := Engine.get_physics_frames()
	if frame != _focus_frame:
		_focus_frame = frame
		_focused_item = null
		_focused_distance = INF

	if _player_in_range and not auto_pickup and _player:
		var dist := global_position.distance_to(_player.global_position)
		if dist < _focused_distance:
			_focused_distance = dist
			_focused_item = self


func _process(delta: float) -> void:
	_time += delta

	# Spin and bob animation
	if _visual:
		_visual.rotation.y += deg_to_rad(spin_speed) * delta
		_visual.position.y = sin(_time * bob_speed) * bob_amplitude

	# Show prompt only if this is the focused item (decided in _physics_process)
	var is_focused := (_focused_item == self)
	if _prompt_label:
		_prompt_label.visible = is_focused

	# Only focused item responds to interact
	if is_focused and Input.is_action_just_pressed(interact_action):
		_try_pickup()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	_player = body
	_player_in_range = true

	if auto_pickup:
		_try_pickup()


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player_in_range = false
		_player = null


func _try_pickup() -> void:
	if not item or not _player:
		return

	# Use explicit reference if set, otherwise find on player
	var inv_comp: InventoryComponent = inventory_component
	if not inv_comp:
		inv_comp = _player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inv_comp:
		push_warning("WorldItem: No InventoryComponent found on player (set export or add child named 'InventoryComponent')")
		return

	var remaining := inv_comp.add_item(item, amount)
	if remaining < amount:
		var picked := amount - remaining
		picked_up.emit(item, picked)

		if remaining == 0 and destroy_on_pickup:
			_play_pickup_effect()
		else:
			amount = remaining


func _play_pickup_effect() -> void:
	# Quick scale-down animation before freeing
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
	# Prevent further interaction during animation
	_player_in_range = false
	set_process_unhandled_input(false)


func _find_visual() -> Node3D:
	for child in get_children():
		if child is MeshInstance3D or child is Sprite3D:
			return child
	return null


func _create_sprite_visual() -> void:
	var sprite := Sprite3D.new()
	sprite.texture = item.icon
	sprite.pixel_size = 0.02
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sprite)
	_visual = sprite


func _create_prompt() -> void:
	_prompt_label = Label3D.new()
	_prompt_label.text = "Press E - %s" % (item.name if item else "Item")
	_prompt_label.position = Vector3(0, 0.8, 0)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.font_size = 32
	_prompt_label.outline_size = 8
	_prompt_label.modulate = Color(1, 1, 1, 0.9)
	_prompt_label.visible = false
	add_child(_prompt_label)
