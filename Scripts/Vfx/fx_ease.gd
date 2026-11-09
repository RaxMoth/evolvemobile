class_name FxEase
extends RefCounted

## Easing for hand-animated effects: snappy cartoon timing (fast in, overshoot,
## settle) instead of linear fades. Pure functions of t in 0..1.


## 0 -> 1.2 -> 1 (back-out): pops, stamps, damage numbers.
static func pop(t: float) -> float:
	var s: float = 2.2
	var u: float = t - 1.0
	return 1.0 + (s + 1.0) * u * u * u + s * u * u


static func out_cubic(t: float) -> float:
	var u: float = 1.0 - t
	return 1.0 - u * u * u


static func in_quad(t: float) -> float:
	return t * t


## Parabolic hop height (0 at both ends, 1 at the middle).
static func hop(t: float) -> float:
	return 4.0 * t * (1.0 - t)
