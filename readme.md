# ZEngine Examples

Simple example on how to use [ZEngine](https://github.com/bluesillybeard/ZEngine) with SDL and OpenGL.

## Dependencies
- Zig version 0.12.0 or 0.13.0-dev.46+3648d7df1
- SDL2
- OpenGL 4.6
    - Why 4.6 when only rendering basic stuff? Because I use static layout locations and bindings, which was apparently not added until OpenGL 4.
