extends State
"""
Parent state for all camera based states for the Camera. Handles input based on
mouse/gamepad and movement and configuration based on which state we're using.

This state holds all of the main logic, with the state itself being configured
or have its functions overriden or called by the child states. This keeps the
logic contained in a central location while being easily modifiable.
"""


onready var aim_target: Sprite3D = owner.get_node("AimTarget")

export var is_y_inverted: = true
export var fov_default: = 70.0
export var deadzone_backwards := 0.3
export var sensitivity_gamepad: = Vector2(2.5, 2.5)
export var sensitivity_mouse: = Vector2(0.1, 0.1)

var _fov_current: float = fov_default
var _input_relative: = Vector2.ZERO
var _offset: = Vector3.ZERO
var _is_aiming: = false


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	yield(owner, "ready")


func physics_process(delta: float) -> void:
	owner.global_transform.origin = owner.player.global_transform.origin + owner._position_start

	var look_direction: = get_look_direction()
	var move_direction: = get_move_direction()

	if _input_relative.length() > 0:
		process_camera_input(_input_relative * sensitivity_mouse * delta)
		_input_relative = Vector2.ZERO
	elif look_direction.length() > 0:
		process_camera_input(look_direction * sensitivity_gamepad * delta)

	var is_moving_towards_camera: bool = move_direction.x >= -deadzone_backwards and move_direction.x <= deadzone_backwards
	if not is_moving_towards_camera and not _is_aiming:
		auto_rotate(move_direction)

	owner.rotation.y = wrapf(owner.rotation.y, -PI, PI)

	if owner.camera.fov != _fov_current:
		owner.camera.fov = lerp(owner.camera.fov, _fov_current, 0.05)

	owner.spring_arm.translation = lerp(owner.spring_arm.translation, owner._position_start + _offset, 0.05)


func enter(msg: Dictionary = {}) ->void:
	_fov_current = msg["fov"] if "fov" in msg else fov_default
	_offset = msg["offset"] if "offset" in msg else Vector3(0, 0, 0)
	_is_aiming = msg["is_aiming"] if "is_aiming" in msg else false


func update_aim_target() -> void:
	var ray: RayCast = owner.aim_ray
	ray.force_raycast_update()

	if ray.is_colliding():
		var global_offset = aim_target.global_transform

		if global_offset.origin != ray.get_collision_point():
			global_offset.origin = ray.get_collision_point()
			aim_target.global_transform = global_offset
			aim_target.look_at(ray.get_collision_point() - ray.get_collision_normal(), global_offset.basis.y.normalized())

		aim_target.visible = true
	else:
		aim_target.visible = false


func auto_rotate(move_direction: Vector3) -> void:
	var offset: float = owner.player.rotation.y - owner.rotation.y
	var target_angle: float = (
		owner.player.rotation.y - 2 * PI if offset > PI
		else owner.player.rotation.y + 2 * PI if offset < -PI
		else owner.player.rotation.y
	)
	owner.rotation.y = lerp(owner.rotation.y, target_angle, 0.015)


func unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mousegrab_toggle"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("y_inversion_toggle"):
		is_y_inverted = !is_y_inverted
	elif event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_input_relative += event.get_relative()


func process_camera_input(input: Vector2) -> void:
	if input.x != 0:
		owner.rotation.y -= input.x
	if input.y != 0:
		var angle: = input.y
		owner.rotation.x -= angle * -1.0 if is_y_inverted else angle
		owner.rotation.x = clamp(owner.rotation.x, -0.75, 1.25)
		owner.rotation.z = 0


"""
Returns the direction of the camera movement from the player
"""
static func get_look_direction() -> Vector2:
	return Vector2(
			Input.get_action_strength("look_right") - Input.get_action_strength("look_left"),
			Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
		).normalized()


"""
Returns the move direction of the character controlled by the player
"""
static func get_move_direction() -> Vector3:
	return Vector3(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			0,
			Input.get_action_strength("move_back") - Input.get_action_strength("move_front")
		)
