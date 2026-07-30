class_name GridDirection
extends RefCounted


static func to_vector(
		direction: GameEnums.CardinalDirection
) -> Vector2i:
	match direction:
		GameEnums.CardinalDirection.UP:
			return Vector2i.UP
		GameEnums.CardinalDirection.RIGHT:
			return Vector2i.RIGHT
		GameEnums.CardinalDirection.DOWN:
			return Vector2i.DOWN
		GameEnums.CardinalDirection.LEFT:
			return Vector2i.LEFT
	return Vector2i.RIGHT


static func from_delta(delta: Vector2i) -> GameEnums.CardinalDirection:
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		return (
				GameEnums.CardinalDirection.RIGHT
				if delta.x > 0
				else GameEnums.CardinalDirection.LEFT
		)
	if delta.y != 0:
		return (
				GameEnums.CardinalDirection.DOWN
				if delta.y > 0
				else GameEnums.CardinalDirection.UP
		)
	return GameEnums.CardinalDirection.RIGHT


static func rotate_from_right(
		offset: Vector2i,
		direction: GameEnums.CardinalDirection
) -> Vector2i:
	match direction:
		GameEnums.CardinalDirection.UP:
			return Vector2i(offset.y, -offset.x)
		GameEnums.CardinalDirection.RIGHT:
			return offset
		GameEnums.CardinalDirection.DOWN:
			return Vector2i(-offset.y, offset.x)
		GameEnums.CardinalDirection.LEFT:
			return Vector2i(-offset.x, -offset.y)
	return offset
