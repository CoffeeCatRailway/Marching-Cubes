extends CharacterBody3D

@export var marchMesh: MeshInstance3D

@export var speed := 15.

var isMoving := false
var originalPos := Vector3.ZERO

const Accel := 2.
const Deaccel := 4.
const Gravity := 9.8 * 3.

func _ready() -> void:
	originalPos = global_transform.origin

func _physics_process(delta) -> void:
	if Input.is_action_just_released("ui_home"):
		global_transform.origin = originalPos
	
	var moveDir := Vector3.ZERO
	moveDir.x += Input.get_axis("ui_left", "ui_right")
	moveDir.z += Input.get_axis("ui_up", "ui_down")
	
	isMoving = moveDir.length() > 0. # Reset flag for movement
	moveDir = moveDir.normalized()
	
	# Add gravity
	velocity.y -= Gravity * delta
	
	# Calculate target position to move
	var target := moveDir * speed
	# Accelerate if moving
	var accel := Deaccel
	if isMoving:
		accel = Accel
	
	# Calculate the horizontal velocity to move toward the target
	var hvel := velocity
	hvel.y = 0.
	
	hvel = hvel.lerp(target, accel * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	
	# Move the node
	move_and_slide()
	



















