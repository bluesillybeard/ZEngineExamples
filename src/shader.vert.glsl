#version 460 core

// Vertex inputs
layout(location = 0) in vec3 pos;
layout(location = 1) in vec2 texCoord;

// Uniform inputs
layout(location = 0) uniform mat4 transform;

// Variables to go to the fragment shader
out vec2 _texCoord;

void main() {
    gl_Position = transform * vec4(pos, 1);
    _texCoord = texCoord;
}