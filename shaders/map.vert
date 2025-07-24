#version 450

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;

layout(location = 0) out float height_out;
layout(location = 1) out vec3 normal_out;

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

    vec3 world_position = vec3(position.x + offset.x, position.y, position.z + offset.y);
    gl_Position = camera.projection * camera.view * vec4(world_position, 1.0);
}
