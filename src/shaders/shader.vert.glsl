#version 450

in vec3 pos;
in vec2 texCoord;
in vec4 color;
// 0 -> texture, 1 -> color
in float blend;


uniform mat4 transform;

out vec2 _texCoord;
out vec4 _color;
out float _blend;

void main() {
    _texCoord = texCoord;
    _color = color;
    _blend = blend;
    gl_Position = vec4(pos, 1) * transform;
}

