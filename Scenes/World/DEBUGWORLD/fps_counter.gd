extends Label

@export var update_interval: float = 0.5
@export var show_average: bool = true

var frame_count: int = 0
var time_elapsed: float = 0.0
var fps_history: Array[float] = []
var max_history: int = 10

func _ready() -> void:
	# Position in top-left corner
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(10, 10)
	
	# Style the label
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color.YELLOW)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 2)

func _process(delta: float) -> void:
	frame_count += 1
	time_elapsed += delta
	
	if time_elapsed >= update_interval:
		var current_fps = frame_count / time_elapsed
		
		# Update history for average
		fps_history.append(current_fps)
		if fps_history.size() > max_history:
			fps_history.pop_front()
		
		# Calculate average
		var avg_fps = 0.0
		if show_average and fps_history.size() > 0:
			for fps in fps_history:
				avg_fps += fps
			avg_fps /= fps_history.size()
		
		# Update text
		if show_average:
			text = "FPS: %d (Avg: %d)" % [current_fps, avg_fps]
		else:
			text = "FPS: %d" % current_fps
		
		# Color coding based on performance
		if current_fps >= 55:
			add_theme_color_override("font_color", Color.GREEN)
		elif current_fps >= 30:
			add_theme_color_override("font_color", Color.YELLOW)
		else:
			add_theme_color_override("font_color", Color.RED)
		
		# Reset counters
		frame_count = 0
		time_elapsed = 0.0
