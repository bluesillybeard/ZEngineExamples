# ZEngine Examples

Examples on how to use [ZEngine](https://github.com/bluesillybeard/ZEngine) and its official modules.

## Dependencies
- Zig version 0.12.0-dev.3146+671c2acf4 or compatible
- SDL2
    - VERY IMPORTANT: SDL.zig DOES NOT work on the above Zig verison, all instances of '.static' and '.dynamic' need to be replaced with '.Static' and '.Dynamic' in their build.zig in order for it to work
- OpenGL 4.6
    - Why 4.6 when only rendering basic stuff? Because I use static layout locations and bindings, which was apparently not added until OpenGL 4.
