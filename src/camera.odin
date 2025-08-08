package birb

import "shared:svk"

import "core:log"
import "core:math"
import "core:math/linalg"
import "vendor:glfw"

MAX_HEIGHT :: HEIGHT_SCALE / 2

Camera :: struct {
	view, projection: matrix[4, 4]f32,
	direction:        [3]f32,
	position:         [3]f32,
}

create_camera :: proc(ctx: svk.Context) -> (camera: Camera) {
	camera.view = 1
	camera.projection = calculate_projection_matrix(ctx)
	camera.position = {cast(f32)REAL_CHUNK_SIZE / 2, MAX_HEIGHT, cast(f32)REAL_CHUNK_SIZE / 2}

	return camera
}

update_camera :: proc(ctx: svk.Context, camera: ^Camera, delta_time: f32, loaded: bool) {
	if !loaded {return}

	tilt_speed: f32 : 1
	horizontal_speed: f32 = 0.5

	@(static) forward := [3]f32{0, 0, 1}
	up :: [3]f32{0, 1, 0}

	@(static) pitch: f32 = 0

	if glfw.GetKey(ctx.window.handle, glfw.KEY_SPACE) == glfw.PRESS {
		pitch += tilt_speed * delta_time
	} else {
		pitch -= tilt_speed * delta_time
	}

	pitch = clamp(pitch, -1, 1)

	right_change := 0
	left_change := 0

	if glfw.GetKey(ctx.window.handle, glfw.KEY_A) == glfw.PRESS {
		right_change = 1
	}

	if glfw.GetKey(ctx.window.handle, glfw.KEY_D) == glfw.PRESS {
		left_change = 1
	}

	right := linalg.cross(up, forward)
	forward += right * f32(right_change - left_change) * horizontal_speed * delta_time
	forward.y = pitch

	camera.position += forward
	log.info(camera.position.y)

	camera.view = linalg.matrix4_look_at_f32(
		camera.position,
		camera.position + forward,
		[3]f32{0, 1, 0},
	)
}

calculate_projection_matrix :: proc(ctx: svk.Context) -> matrix[4, 4]f32 {
	aspect_ratio := f32(ctx.window.width) / f32(ctx.window.height)
	return linalg.matrix4_perspective_f32(math.to_radians(f32(90)), aspect_ratio, 0.1, 5000)
}
