#version 450

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;

layout(location = 0) out float height_out;
layout(location = 1) out vec3 normal_out;
layout(location = 2) out vec3 vertex_position_out;
layout(location = 3) out vec3 position_relative_to_cam_out;

layout(set = 0, binding = 0) uniform Camera {
    mat4 view;
    mat4 projection;
    vec3 direction;
} camera;

layout(push_constant) uniform Offsets {
    vec2 offset;
};

void main() {
    height_out = position.y;
    normal_out = normal;
    vertex_position_out = position;

    vec3 world_position = vec3(position.x + offset.x, position.y, position.z + offset.y);
    vec4 position_relative_to_cam = camera.view * vec4(world_position, 1.0);
    position_relative_to_cam_out = position_relative_to_cam.xyz;
    
    gl_Position = camera.projection * position_relative_to_cam;
}
