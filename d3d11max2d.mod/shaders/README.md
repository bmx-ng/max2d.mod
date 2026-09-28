# D3D11 shaders

`draw.hlsl` contains the vertex/pixel shaders. `compile.cpp` is a Windows build
tool using D3DCompiler. Compile it with `g++ -static -ld3dcompiler`, then pass the
HLSL input and `draw_shaders.cpp` output paths. Commit the generated C++ source.

Applications link the bytecode directly and do not load D3DCompiler. The profiles
are vs_4_0 and ps_4_0, requiring Direct3D feature level 10.0 or higher.

The vertex input is Max2D's eight-float XY/RGBA/UV format. D3D11 pixel centres do
not use D3D9's half-pixel adjustment. MASKBLEND uses shader discard at alpha 0.5.

Render images and mipmapped images store premultiplied RGBA. The pixel shader converts sampled premultiplied
colour to straight RGB before tinting, then premultiplies SOLID/MASK output when
writing another render image. ALPHA/LIGHT use source-alpha hardware blending.
