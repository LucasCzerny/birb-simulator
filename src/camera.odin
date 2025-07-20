package birb

import "shared:svk"

import "core:math"
import "core:math/linalg"
import "vendor:glfw"

Camera :: struct {
	view, projection: matrix[4, 4]f32,
	direction:        [3]f32,
	position:         [3]f32,
}

create_camera :: proc(ctx: svk.Context) -> (camera: Camera) {
	camera.view = 1
	camera.projection = calculate_projection_matrix(ctx)

	return camera
}

update_camera :: proc(ctx: svk.Context, matrices: ^Camera, delta_time: f32) -> bool {
	speed :: 100.0
	mouse_sensitivity :: 0.3

	@(static) position := [3]f32{0, 0, 5}
	@(static) forward := [3]f32{0, 0, -1}
	@(static) right := [3]f32{1, 0, 0}
	@(static) up := [3]f32{0, 1, 0}

	@(static) prev_cursor_x, prev_cursor_y: f64

	@(static) yaw: f32 = -90.0
	@(static) pitch: f32 = 0.0

	relative_movement := [3]f32{}

	moved := false

	if glfw.GetKey(ctx.window.handle, glfw.KEY_W) == glfw.PRESS {
		relative_movement += forward * speed * delta_time
		moved = true
	}
	if glfw.GetKey(ctx.window.handle, glfw.KEY_S) == glfw.PRESS {
		relative_movement -= forward * speed * delta_time
		moved = true
	}

	if glfw.GetKey(ctx.window.handle, glfw.KEY_D) == glfw.PRESS {
		relative_movement += right * speed * delta_time
		moved = true
	}
	if glfw.GetKey(ctx.window.handle, glfw.KEY_A) == glfw.PRESS {
		relative_movement -= right * speed * delta_time
		moved = true
	}

	if glfw.GetKey(ctx.window.handle, glfw.KEY_SPACE) == glfw.PRESS {
		relative_movement += up * speed * delta_time
		moved = true
	}
	if glfw.GetKey(ctx.window.handle, glfw.KEY_LEFT_CONTROL) == glfw.PRESS {
		relative_movement -= up * speed * delta_time
		moved = true
	}

	position += relative_movement

	if glfw.GetMouseButton(ctx.window.handle, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS {
		glfw.SetInputMode(ctx.window.handle, glfw.CURSOR, glfw.CURSOR_DISABLED)
	} else if glfw.GetMouseButton(ctx.window.handle, glfw.MOUSE_BUTTON_LEFT) == glfw.RELEASE {
		glfw.SetInputMode(ctx.window.handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
		return moved
	}

	cursor_x, cursor_y := glfw.GetCursorPos(ctx.window.handle)
	delta_x := cursor_x - prev_cursor_x
	delta_y := cursor_y - prev_cursor_y
	prev_cursor_x, prev_cursor_y = cursor_x, cursor_y

	if delta_x == 0 && delta_y == 0 {
		if !moved {return false}
	}

	yaw += f32(delta_x) * mouse_sensitivity
	pitch -= f32(delta_y) * mouse_sensitivity
	pitch = math.clamp(pitch, -89.0, 89.0)

	forward.x = math.cos(math.to_radians(yaw)) * math.cos(math.to_radians(pitch))
	forward.y = math.sin(math.to_radians(pitch))
	forward.z = math.sin(math.to_radians(yaw)) * math.cos(math.to_radians(pitch))
	forward = linalg.normalize(forward)

	right = linalg.normalize(linalg.cross(forward, [3]f32{0, 1, 0}))
	up = linalg.normalize(linalg.cross(right, forward))

	matrices.view = linalg.matrix4_look_at_f32(position, position + forward, up)
	matrices.direction = forward
	matrices.position = position

	return true
}

calculate_projection_matrix :: proc(ctx: svk.Context) -> matrix[4, 4]f32 {
	aspect_ratio := f32(ctx.window.width) / f32(ctx.window.height)
	return linalg.matrix4_perspective_f32(math.to_radians(f32(70)), aspect_ratio, 0.1, 1000)
}
