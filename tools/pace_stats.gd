extends RefCounted

## The pace metric of tools/sim_match.gd (README "Headless Tools", "pace"):
## how long a watcher waits between two hits seen on screen. Pure functions
## over event times in game seconds; loaded by path, because a -s script
## cannot name project classes.
##
## A gap is the time between two events in a row, counting the match start ->
## the first event and the last event -> the end. A quiet stretch is a gap of
## at least the threshold (game seconds); real seconds are game seconds / the
## time scale the match is watched at.


## Every gap of `times` (game seconds, ascending) in a match that ran 0 ..
## end_t: the opening, the gaps between events and the closing. No event at
## all is one gap, the whole match.
static func gaps(times: Array[float], end_t: float) -> Array[float]:
	var out: Array[float] = []
	var last: float = 0.0
	for t: float in times:
		out.append(maxf(0.0, t - last))
		last = t
	out.append(maxf(0.0, end_t - last))
	return out


## The quiet stretches of `times` at `threshold` game seconds, watched at
## `speed` game seconds per real second: {share (quiet time / end_t),
## longest_real (the longest gap, real seconds, quiet or not), n (stretches)}.
static func quiet(times: Array[float], end_t: float, threshold: float, speed: float) -> Dictionary:
	var quiet_s: float = 0.0
	var longest: float = 0.0
	var n: int = 0
	for g: float in gaps(times, end_t):
		longest = maxf(longest, g)
		if g >= threshold:
			quiet_s += g
			n += 1
	return {
		"share": snappedf(quiet_s / end_t, 0.001) if end_t > 0.0 else 0.0,
		"longest_real": snappedf(longest / maxf(speed, 0.001), 0.1),
		"n": n,
	}


## The longest gap of `times` (start and end included) in real seconds.
static func longest_real(times: Array[float], end_t: float, speed: float) -> float:
	var longest: float = 0.0
	for g: float in gaps(times, end_t):
		longest = maxf(longest, g)
	return snappedf(longest / maxf(speed, 0.001), 0.1)
