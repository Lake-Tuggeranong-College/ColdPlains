extends CharacterBody3D

signal health_changed(health_value)

@export var collision_shape : CollisionShape3D
@export var pistol : Node3D
@export var pistol_muzzle_flash : GPUParticles3D
@export var toygun : Node3D
@export var uzi : Node3D
@export var Uzi_muzzle_flash : GPUParticles3D
@export var rifle : Node3D
@export var rifle_muzzle_flash : GPUParticles3D
@export var camera : Camera3D
@export var anim_player : AnimationPlayer
@export var raycast : RayCast3D
@export var flashlight : Node3D
@export var enemy_raycast : RayCast3D
@export var particle_raycast : RayCast3D

@export var walk_speed: float = 5.0
@export var slide_speed: float = 20.0
@export var slide_duration: float = 0.5
@export var slide_friction: float = 0.95
@export var no_cooldown = false

var current_weapon = null
var hit_explosion_scene = preload("res://Shaders/hit_explosion.tscn")
var is_shooting: bool = false # Checks the shooting state
var can_shoot: bool = true

var is_sliding: bool = false
var slide_timer: float = 0.0
var is_dead: bool = false

var health: int = 100
var max_health: int = 100
var damage: int = 10

const HEALTH_PACK_HEAL_AMOUNT: int = 30 #Do we want to heal that much?

var SPEED = 10.0
var JUMP_VELOCITY = 10.0
const LOOK_SPEED = 5

var gravity = 20.0

var crouch_height = 0.5
var stand_height = 2.0
var is_crouched = false
var crouch_speed = 3
var crouch_jump_velocity = 3
const CROUCH_TRANSLATE = 0.7


func _enter_tree():
	print(name)
	set_multiplayer_authority(str(name).to_int())


func _ready():
	#rpc("flashLight_toggle")

	if not is_multiplayer_authority(): 
		return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	
	$CanvasLayer.visible = true
	
	if is_multiplayer_authority():
		Lobby.player_loaded.rpc_id(1)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event):
	if not is_multiplayer_authority() or is_dead:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	# Handle shooting input
	if Input.is_action_just_pressed("shoot"):
		is_shooting = true
		if current_weapon == uzi or current_weapon == rifle:
			anim_player.play("automatic_weapons_shoot")
			play_shoot_effects.rpc()
			perform_shooting_logic()
		else:  # pistol or toygun
			# Enforcing the shooting animation waiting mechanism
			if can_shoot or no_cooldown:
				can_shoot = false  # Set this to false to prevent immediate re-shot
				anim_player.play("shoot")
				play_shoot_effects.rpc()
				perform_shooting_logic()
			else:
				print("Cannot shoot yet; waiting for animation to finish.")

	elif Input.is_action_pressed("shoot") and is_shooting and (current_weapon == uzi or current_weapon == rifle):
		# Continue automatic fire while held
		if anim_player.current_animation != "automatic_weapons_shoot":
			anim_player.play("automatic_weapons_shoot")
		play_shoot_effects.rpc()
		perform_shooting_logic()

	if Input.is_action_just_pressed("capture_toggle") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif Input.is_action_just_pressed("capture_toggle"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	elif Input.is_action_just_released("shoot"):
		is_shooting = false


func _physics_process(delta):
	if not is_multiplayer_authority() or is_dead: 
		return

	handle_crouch(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_pressed("ui_accept") and is_on_floor():
		velocity += JUMP_VELOCITY * get_floor_normal()

	if Input.is_action_just_pressed("toggle_flashlight"):
		rpc("flashLight_toggle")

	if Input.is_action_just_pressed("slide") and is_on_floor():
		var input_dir = Input.get_vector("left", "right", "up", "down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction != Vector3.ZERO and not is_sliding:
			start_slide(direction)

	if is_sliding:
		slide_timer += delta
		velocity.x *= slide_friction
		velocity.z *= slide_friction
		if slide_timer >= slide_duration:
			is_sliding = false
	else:
		var input_dir = Input.get_vector("left", "right", "up", "down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			var damping_value = 10
			velocity.x = move_toward(velocity.x, 0, SPEED / damping_value * abs(velocity.normalized().x))
			velocity.z = move_toward(velocity.z, 0, SPEED / damping_value * abs(velocity.normalized().z))

	var look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if look_dir != Vector2.ZERO:
		rotate_y(-look_dir.x * LOOK_SPEED * delta)
		camera.rotate_x(-look_dir.y * LOOK_SPEED * delta)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	if anim_player.current_animation == "shoot":
		pass
	elif Input.get_vector("left", "right", "up", "down") != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")
	
	if Input.is_action_just_pressed("swap_to_pistol"):
		switch_weapons(pistol)
	if Input.is_action_just_pressed("swap_to_toy_gun"):
		switch_weapons(toygun)
	if Input.is_action_just_pressed("swap_to_uzi"):
		switch_weapons(uzi)
	if Input.is_action_just_pressed("swap_to_rifle"):
		switch_weapons(rifle)

	if is_shooting and current_weapon == uzi:
		perform_shooting_logic()
		
	if is_shooting and current_weapon == rifle:
		perform_shooting_logic()
		
	move_and_slide()


func perform_shooting_logic():
	if raycast.is_colliding():
		var hit_player = raycast.get_collider()
		#hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
		hit_player.request_damage.rpc_id(1)
	
	if enemy_raycast.is_colliding():
		enemy_raycast.get_collider().damage_taken += damage
	
	if particle_raycast.is_colliding():
		var hit_explosion = hit_explosion_scene.instantiate()
		var pos = particle_raycast.get_collision_point()
		var norm = particle_raycast.get_collision_normal()
		hit_explosion.look_at_from_position(pos, norm + pos)
		hit_explosion.setup_particles(damage) #damage for this function should be replaced with damage from the current weapon
		get_parent().add_child(hit_explosion)


func switch_weapons(selected_weapon):
	#Hide all weapons
	pistol.hide()
	toygun.hide()
	uzi.hide()
	rifle.hide()
	# Show the selected weapon
	current_weapon = selected_weapon
	if current_weapon:
		current_weapon.show()


func _on_animation_player_animation_finished(anim_name):
	print("Animation finished: ", anim_name)  # Check this is called for the "shoot" animation
	if anim_name == "shoot":
		can_shoot = true  # Allow shooting again only when shoot animation finishes
		anim_player.play("idle")  # Transition to idle after shooting


func start_slide(direction: Vector3) -> void:
	is_sliding = true
	slide_timer = 0.0
	velocity.x = direction.x * slide_speed
	velocity.z = direction.z * slide_speed


@rpc("call_local")
func play_shoot_effects():
	if current_weapon == pistol:
		if pistol_muzzle_flash:
			pistol_muzzle_flash.restart()
			pistol_muzzle_flash.emitting = true
		else:
			print("Muzzle flash for pistol is null")
	elif current_weapon == uzi:
		if Uzi_muzzle_flash:
			Uzi_muzzle_flash.restart()
			Uzi_muzzle_flash.emitting = true
		else:
			print("Rifle muzzle flash is null")
	elif current_weapon == rifle:
		if rifle_muzzle_flash:
			rifle_muzzle_flash.restart()
			rifle_muzzle_flash.emitting = true
		else:
			print("Uzi muzzle flash is null")


@rpc("any_peer", "call_remote", "reliable")
func request_damage() -> void:
	if not multiplayer.is_server():
		return
	if is_dead:
		return
	# Apply damage on the server.
	var new_health := maxi(health - damage, 0)
	_broadcast_health(new_health)
	if new_health <= 0:
		is_dead = true
		rpc("die")


func handle_crouch(delta) -> void:
	if is_crouched: 
		SPEED = crouch_speed 
		JUMP_VELOCITY = crouch_jump_velocity
	else: 
		SPEED = 10
		JUMP_VELOCITY = 10
	
	is_crouched = Input.is_action_pressed("crouch")
	camera.position = Vector3(0,(CROUCH_TRANSLATE if is_crouched else 1.513),0)
	$CollisionShape3D.shape.height = stand_height - CROUCH_TRANSLATE if is_crouched else stand_height
	$CollisionShape3D.position.y = $CollisionShape3D.shape.height / 2


@rpc("authority", "call_local")
func die():
	velocity = Vector3.ZERO
	set_process(false)
	set_physics_process(false)
	hide()
	if is_multiplayer_authority():
		get_tree().call_group("ui","show_lose_screen")


@rpc("call_local", "reliable", "any_peer")
func flashLight_toggle():
	flashlight.visible = not flashlight.visible


func heal(amount: int) -> bool:
	if not is_multiplayer_authority():
		return false
	if is_dead or health >= max_health:
		return false
	var old_health = health
	health = mini(health + amount, max_health)
	if health != old_health:
		health_changed.emit(health)
		print("Player healed! Health: ", health, "/", max_health)
		return true
	return false


func request_use_health_pack() -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	if multiplayer.is_server():
		_server_use_health_pack()
	else:
		request_use_health_pack_rpc.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func request_use_health_pack_rpc() -> void:
	if not multiplayer.is_server():
		return
	# Only accept requests from the owner of this player.
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != get_multiplayer_authority():
		return
	_server_use_health_pack()


func _server_use_health_pack() -> void:
	if not multiplayer.is_server() or is_dead:
		return
	var inventory_node := get_node_or_null("PlayerInventory") as PlayerInventory
	if inventory_node == null:
		print("[HealthPack] Inventory not found!")
		return
	print("[HealthPack] Server health: ", health, "/", max_health)
	if health >= max_health:
		print("[HealthPack] Health is already full.")
		return
	# Only consume the item if one exists.
	if not inventory_node.use_health_pack_server(HEALTH_PACK_HEAL_AMOUNT):
		print("[HealthPack] No Health Pack in inventory!")
		return
	# Calculate the new health on the server.
	var new_health := mini(health + HEALTH_PACK_HEAL_AMOUNT,max_health)
	_broadcast_health(new_health)
	print("[HealthPack] Used successfully! New health: ",new_health,"/",max_health)


func _broadcast_health(new_health: int) -> void:
	if not multiplayer.is_server():
		return
	_receive_health_update.rpc(new_health)


@rpc("any_peer", "call_local", "reliable")
func _receive_health_update(new_health: int) -> void:
	# Only accept health updates from the server.
	if not multiplayer.is_server():
		if multiplayer.get_remote_sender_id() != 1:
			return
	health = clampi(new_health, 0, max_health)
	health_changed.emit(health)
	print("[Health] Updated: ", health, "/", max_health)
