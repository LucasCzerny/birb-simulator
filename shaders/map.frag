#version 450

layout(location = 0) in float height;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 mesh_color;

layout(location = 0) out vec4 output_color;

layout(set = 0, binding = 0) uniform Camera {
    mat4 view;
    mat4 projection;
    vec3 direction;
} camera;

float lighting(vec3 normal, vec3 view_dir);

void main() {
    vec3 color;
    if (height <= 0.5) {
        color = vec3(0.0, 0.2, 0.8);
    } else if (height <= 1.5) {
        color = vec3(0.0, 0.8, 0.4);
    } else if (height <= 1.75) {
        color = vec3(0.6, 0.7, 0.2);
    } else {
        color = vec3(1.0, 1.0, 1.0);
    }

    color = mesh_color;

    float intensity = lighting(normal, camera.direction);
    output_color = vec4(intensity * color, 1.0);
}

float lighting(vec3 normal, vec3 view_dir) {
    const vec3 light_direction = normalize(vec3(0.5, 1.0, 0.0));
    normal = normalize(normal);
    view_dir = normalize(view_dir);
    
    const float ambient = 0.1;
    const float diffuse_strength = 0.6;
    const float specular_strength = 0.3;
    const float shininess = 32.0;

    const float diffuse = diffuse_strength * max(dot(normal, light_direction), 0.0);

    const vec3 halfway_dir = normalize(light_direction + view_dir);
    const float spec = pow(max(dot(normal, halfway_dir), 0.0), shininess);
    const float specular = specular_strength * spec;

    return ambient + diffuse + specular;
}

