extends TestCase

## PersistedData.level_progress: level L -> L+1 costs 100*L (cumulative 100/300/600/1000).

func test_level_boundaries() -> void:
	var p: Dictionary = PersistedData.level_progress(0)
	assert_eq(p.level, 1); assert_eq(p.into, 0); assert_eq(p.needed, 100)
	p = PersistedData.level_progress(99)
	assert_eq(p.level, 1); assert_eq(p.into, 99)
	p = PersistedData.level_progress(100)
	assert_eq(p.level, 2); assert_eq(p.into, 0); assert_eq(p.needed, 200)
	p = PersistedData.level_progress(300)
	assert_eq(p.level, 3); assert_eq(p.into, 0); assert_eq(p.needed, 300)
	p = PersistedData.level_progress(600)
	assert_eq(p.level, 4); assert_eq(p.into, 0); assert_eq(p.needed, 400)


func test_partial_progress_and_negative() -> void:
	var p: Dictionary = PersistedData.level_progress(350)
	assert_eq(p.level, 3); assert_eq(p.into, 50); assert_eq(p.needed, 300)
	assert_eq(PersistedData.level_from_xp(-5), 1)
