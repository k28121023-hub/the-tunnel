extends RefCounted
## Chests and pickups must not open through solid walls, but one-way
## platforms that the player can jump through should not block them.

static func blocked(world: World2D, from: Vector2, to: Vector2, exclude: Array) -> bool:
	var hit := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, 1, exclude))
	if hit.is_empty():
		return false
	var collider = hit.get("collider")
	if collider == null:
		return true
	for child in collider.get_children():
		if child is CollisionShape2D and child.one_way_collision:
			return false
	return true
