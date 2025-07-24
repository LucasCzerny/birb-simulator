package birb

import "core:log"
import "core:math"

_ :: log

import "shared:svk"

VIEW_DISTANCE :: 2
CHUNKS_PER_ROW :: 1 + 2 * VIEW_DISTANCE // also per column cuz thats how squares work
N :: CHUNKS_PER_ROW

Chunk_Thread_Data :: struct {
	temp_ctx:              svk.Context,
	prev_center_coords:    [2]int,
	first_frame:           bool,
	//
	meshes:                [N][N]Mesh,
	copy_meshes:           bool,
	//
	pregenerated_meshes:   [N][N]Mesh,
	free_slot_deletion:    int,
	to_be_destroyed_index: int,
}

chunks_worker :: proc(init_data_ptr: rawptr) {
	render_data := cast(^Render_Data)context.user_ptr
	chunks_data := cast(^Chunk_Thread_Data)init_data_ptr

	for render_data.is_running {
		center_coords := [2]int {
			cast(int)math.floor(render_data.camera.position.x / 240.0),
			cast(int)math.floor(render_data.camera.position.z / 240.0),
		}

		if center_coords != chunks_data.prev_center_coords || chunks_data.first_frame {
			render_data.center_coords = center_coords
			update_current_chunks(chunks_data, render_data)

			generate_future_chunks(chunks_data, render_data)
		}

		chunks_data.prev_center_coords = center_coords
		chunks_data.first_frame = false
	}
}

update_current_chunks :: proc(chunks_data: ^Chunk_Thread_Data, render_data: ^Render_Data) {
	levels_of_detail := [7]u32{1, 2, 4, 6, 8, 10, 12}

	center_offset := render_data.center_coords - chunks_data.prev_center_coords

	for y in 0 ..< N {
		for x in 0 ..< N {
			offset := [2]int{x, y} - VIEW_DISTANCE
			max_offset := max(abs(offset.x), abs(offset.y))
			lod := levels_of_detail[max_offset]

			prev_index := [2]int{x, y} + center_offset
			new_mesh := &chunks_data.meshes[y][x]

			prev_mesh: ^Mesh = nil
			pregenerated_mesh: ^Mesh = nil

			prev_index_valid :=
				prev_index.x >= 0 && prev_index.x < N && prev_index.y >= 0 && prev_index.y < N
			generate_new_mesh := !prev_index_valid || chunks_data.first_frame

			if !generate_new_mesh {
				prev_mesh = &render_data.meshes[prev_index.y][prev_index.x]
				pregenerated_mesh = &chunks_data.pregenerated_meshes[prev_index.y][prev_index.x]

				if lod == prev_mesh.lod {
					new_mesh^ = prev_mesh^
					prev_mesh._was_copied = true
				} else if lod == pregenerated_mesh.lod {
					new_mesh^ = pregenerated_mesh^
					pregenerated_mesh._was_copied = true
				} else {
					generate_new_mesh = true
				}
			}

			if generate_new_mesh {
				new_mesh^ = generate_chunk_mesh(
					chunks_data.temp_ctx,
					lod,
					render_data.center_coords + offset,
				)
			}
		}
	}

	chunks_data.copy_meshes = true
}

generate_future_chunks :: proc(chunks_data: ^Chunk_Thread_Data, render_data: ^Render_Data) {
	for y in 0 ..< N {
		for x in 0 ..< N {
			offset := [2]int{x, y} - VIEW_DISTANCE
			mesh := &chunks_data.meshes[y][x]

			pregenerated_lod: u32
			switch mesh.lod {
			case 1:
				pregenerated_lod = 2
			// use 1 below the prev mesh lod for 2, ..., 12
			// levels_of_detail := [7]u32{1, 2, 4, 6, 8, 10, 12}
			case 2:
				pregenerated_lod = 1
			case 4, 6, 8, 10, 12:
				pregenerated_lod = mesh.lod - 2
			}

			chunks_data.pregenerated_meshes[y][x] = generate_chunk_mesh(
				chunks_data.temp_ctx,
				pregenerated_lod,
				render_data.center_coords + offset,
			)
		}
	}
}

