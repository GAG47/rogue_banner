class_name TestSuite
extends RefCounted

var assertion_count: int = 0
var failures: Array[String] = []


func assert_true(value: bool, message: String) -> void:
	assertion_count += 1
	if not value:
		failures.append(message)


func assert_false(value: bool, message: String) -> void:
	assertion_count += 1
	if value:
		failures.append(message)


func assert_int_equal(expected: int, actual: int, message: String) -> void:
	assertion_count += 1
	if expected != actual:
		failures.append("%s Expected %d, received %d." % [message, expected, actual])


func assert_vector_equal(
		expected: Vector2i,
		actual: Vector2i,
		message: String
) -> void:
	assertion_count += 1
	if expected != actual:
		failures.append("%s Expected %s, received %s." % [message, expected, actual])


func assert_not_same(expected: Object, actual: Object, message: String) -> void:
	assertion_count += 1
	if expected == actual:
		failures.append(message)


func passed() -> bool:
	return failures.is_empty()
