"""Generate the fixed Max2D v1 colour-effect ABI around trusted function bodies.
Compile .frag with glslc and .hlsl with compile_dxbc.cpp before building BlitzMax.
"""
import argparse
import json
import re
from pathlib import Path


def generate(manifest, output, prefix):
    data = json.loads(Path(manifest).read_text())
    if set(data) != {'abi', 'name', 'factory', 'parameters', 'bodies'} or data['abi'] != 1:
        raise ValueError('Expected a version-one package manifest')
    identifier = re.compile(r'[A-Za-z_][A-Za-z0-9_]*\Z')
    if not identifier.fullmatch(data['name']) or not identifier.fullmatch(data['factory']):
        raise ValueError('Name and factory must be identifiers')
    params = data['parameters']
    if not 1 <= len(params) <= 8:
        raise ValueError('Expected one to eight parameters')
    seen = set()
    for p in params:
        if set(p) != {'name', 'type'} or not identifier.fullmatch(p['name']) or p['name'] in seen or p['name'] in {'c', 'p', 'image', 'mode', 'input', 'result'}:
            raise ValueError('Invalid, duplicate or reserved parameter name')
        if p['type'] not in ('float', 'float4'):
            raise ValueError('Only float and float4 parameters are supported')
        seen.add(p['name'])
    if set(data['bodies']) != {'metal', 'glsl', 'hlsl'}:
        raise ValueError('Supply Metal, GLSL and HLSL function bodies')
    for body in data['bodies'].values():
        # Bodies remain inside a function. This is ABI hygiene, not a sandbox.
        if not isinstance(body, str) or '#' in body or len(body) > 65536:
            raise ValueError('Invalid function body')
        depth = 0
        for c in body:
            depth += (c == '{') - (c == '}')
            if depth < 0:
                raise ValueError('Body escapes its function')
        if depth:
            raise ValueError('Unbalanced function body')
    if not re.fullmatch(r'[A-Za-z0-9_./-]*', prefix) or '..' in prefix.split('/'):
        raise ValueError('Invalid asset prefix')
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    name, count = data['name'], len(params)
    for lang in ('metal', 'glsl', 'hlsl'):
        vec = 'vec4' if lang == 'glsl' else 'float4'
        declarations = '\n'.join(f"    {('float' if p['type']=='float' else vec)} {p['name']} = p[{i}]{'.x' if p['type']=='float' else ''};" for i, p in enumerate(params))
        helper = f"{vec} userEffect({vec} c" + (', constant float4 *p' if lang == 'metal' else '') + ') {\n' + declarations + '\n' + data['bodies'][lang] + '\n}\n'
        if lang == 'metal':
            head = '#include <metal_stdlib>\nusing namespace metal;\nstruct Output { float4 position [[position]]; float4 colour; float2 uv; };\n'
            entry = 'fragment float4 m2dEffectMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]], constant float4 *p [[buffer(1)]]) {\nfloat4 c=image.sample(sampleState,input.uv);\n'
        elif lang == 'glsl':
            head = f'#version 450\nlayout(location=0) in vec4 tint;\nlayout(location=1) in vec2 texcoord;\nlayout(location=0) out vec4 result;\nlayout(set=2,binding=0) uniform sampler2D image;\nlayout(set=3,binding=0) uniform Modes {{ vec4 mode; }};\nlayout(set=3,binding=1) uniform Parameters {{ vec4 p[{count}]; }};\n'
            entry = 'void main() {\nvec4 c=texture(image,texcoord);\n'
        else:
            head = f'cbuffer Modes : register(b0, space3) {{ float4 mode; }};\ncbuffer Parameters : register(b1, space3) {{ float4 p[{count}]; }};\nTexture2D image : register(t0, space2);\nSamplerState sampleState : register(s0, space2);\nstruct Output {{ float4 position: SV_Position; float4 colour: TEXCOORD0; float2 uv: TEXCOORD1; }};\n'
            entry = 'float4 m2dEffectMain(Output input): SV_Target0 {\nfloat4 c=image.Sample(sampleState,input.uv);\n'
        tail = f'if(mode.x!=0) c={vec}(1,1,1,c.r);\nif(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:' + ('vec3(0)' if lang=='glsl' else 'float3(0,0,0)') + ';\n'
        tail += 'c*=' + ('tint' if lang=='glsl' else 'input.colour') + ';\n'
        tail += 'c=userEffect(c' + (',p' if lang=='metal' else '') + ');\nc.a=clamp(c.a,0.0,1.0);\n'
        tail += 'if(mode.z!=0 && c.a<0.5) ' + ('discard_fragment();' if lang=='metal' else 'discard;') + '\nif(mode.w!=0) c.rgb*=c.a;\n'
        tail += ('result=c;' if lang=='glsl' else 'return c;') + '\n}\n'
        (output / (name + ('.frag' if lang=='glsl' else '.'+lang))).write_text(head+helper+entry+tail)
    assets = [f'{prefix}{name}.{ext}' for ext in ('metal', 'frag.spv', 'dxbc')]
    factory = data['factory']
    bmx = "' Generated package wrapper. Run embed.py after compiling shader assets.\n"
    bmx += f"' Import {prefix}{name}_assets.c alongside your application imports.\n"
    bmx += f'Function {factory}:TMax2DShaderPackage()\n'
    bmx += '\tReturn TMax2DShaderPackage.Create("'+name+'", ['+', '.join('"'+p['name']+'"' for p in params)+'], ['+', '.join('MAX2D_PARAMETER_'+p['type'].upper() for p in params)+'], '+', '.join(f'{factory}Data({factory}Asset({i}), {factory}Size({i}))' for i in range(3))+')\nEnd Function\n'
    bmx += f'Private\nExtern "C"\n\tFunction {factory}Asset:Byte Ptr(index:Int)\n\tFunction {factory}Size:Int(index:Int)\nEnd Extern\nFunction {factory}Data:Byte[](source:Byte Ptr, length:Int)\n\tLocal data:Byte[] = New Byte[length]\n\tMemCopy(data, source, Size_T(data.Length))\n\tReturn data\nEnd Function\nPublic\n'
    (output / (name+'.bmx')).write_text(bmx)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest')
    parser.add_argument('output')
    parser.add_argument('--prefix', default='')
    args = parser.parse_args()
    generate(args.manifest, args.output, args.prefix)
