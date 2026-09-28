// c0: textured, source premultiplied, output premultiplied, mask.
float4 options : register(c0);
sampler2D image : register(s0);
float4 main(float4 tint : COLOR0, float2 uv : TEXCOORD0) : COLOR0 {
    float4 c = lerp(float4(1,1,1,1), tex2D(image, uv), options.x);
    float3 straight = c.a > 0 ? c.rgb / max(c.a, 0.0001) : float3(0,0,0);
    c.rgb = lerp(c.rgb, straight, options.y);
    c *= tint;
    clip(lerp(1.0, c.a - 0.5, options.w));
    c.rgb *= lerp(1, c.a, options.z);
    return c;
}
