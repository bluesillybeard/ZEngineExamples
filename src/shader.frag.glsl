#version 460 core

// inputs from the vertex shader
in vec2 _texCoord;

// uniform inputs
layout(location = 1, binding = 0) uniform sampler2D tex;

// output color
out vec4 colorOut;

void main() {
    colorOut = texture(tex, _texCoord);
}