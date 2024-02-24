#version 450

in vec2 _texCoord;
in vec4 _color;
// 0 -> texture, 1 -> color
in float _blend;

uniform sampler2D tex;

out vec4 colorOut;

void main() {
    // lerp between texture color and vertex color based on blend value
    colorOut = mix(texture(tex, _texCoord), _color, _blend);
}

