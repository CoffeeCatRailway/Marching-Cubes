extends CharacterBody3D

@export var speed := 15.
@export var flying := false

var isMoving := false
var originalPos := Vector3.ZERO
var vieSensitivity := .3
var pitch := 0.
var yaw := 0.
var mouseModeToggle := true # false is visible

const Accel := 2.
const Deaccel := 4.
const Gravity := 9.8 * 3.

func _ready() -> void:
	originalPos = global_transform.origin
	floor_max_angle = floor_max_angle * 1.5

func _input(event) -> void:
	if event is InputEventMouseMotion:
		if mouseModeToggle:
			pitch = max(min(pitch - (event as InputEventMouseMotion).relative.y * vieSensitivity, 90.), -90.)
			yaw = fmod(yaw - (event as InputEventMouseMotion).relative.x * vieSensitivity, 360.)
			$Camera3D.rotation.x = deg_to_rad(pitch)
			$Camera3D.rotation.y = deg_to_rad(yaw)
	if event is InputEventKey:
		if event.is_action_released("ui_home"):
			global_transform.origin = originalPos
		if event.is_action_released("game_quit"):
			mouseModeToggle = !mouseModeToggle
			if mouseModeToggle:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _enter_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta) -> void:
	var aim = $Camera3D.global_transform.basis
	var moveDir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		moveDir -= aim[2]
	if Input.is_action_pressed("move_backward"):
		moveDir += aim[2]
	if Input.is_action_pressed("move_left"):
		moveDir -= aim[0]
	if Input.is_action_pressed("move_right"):
		moveDir += aim[0]
	
	moveDir = moveDir.normalized()
	isMoving = moveDir.length() > 0. # Reset flag for movement
	
	# Add gravity
	if !flying:
		velocity.y -= Gravity * delta
		if Input.is_action_just_pressed("move_jump") && is_on_floor():
			velocity.y += Gravity / 2.
	
	# Calculate target position to move
	var target := moveDir * speed
	# Accelerate if moving
	var accel := Deaccel
	if isMoving:
		accel = Accel
	
	if !flying:
		# Calculate the horizontal velocity to move toward the target
		var hvel := velocity
		hvel.y = 0.
		
		hvel = hvel.lerp(target, accel * delta)
		velocity.x = hvel.x
		velocity.z = hvel.z
	else:
		velocity = velocity.lerp(target, accel * delta)
	
	# Move the node
	move_and_slide()



















