#include <max2d.mod/shadereffects.mod/package.h>
/* A native five-texture probe. Public effect packages still use their existing ABI. */
void *m2d_test_gl_texture_set(void) {
    static unsigned char source[]=
        "#version 120\n"
        "uniform sampler2D image,secondImage,thirdImage,fourthImage,fifthImage;\n"
        "uniform bool secondTarget,thirdTarget,fourthTarget,fifthTarget;\n"
        "uniform vec4 p[5]; varying vec2 texcoord;\n"
        "vec2 uv(bool target){return vec2(texcoord.x,target?1.0-texcoord.y:texcoord.y);}\n"
        "void main(){vec4 s;vec4 mode;\n"
        "if(p[0].x<0.5){s=texture2D(secondImage,uv(secondTarget));mode=p[1];}\n"
        "else if(p[0].x<1.5){s=texture2D(thirdImage,uv(thirdTarget));mode=p[2];}\n"
        "else if(p[0].x<2.5){s=texture2D(fourthImage,uv(fourthTarget));mode=p[3];}\n"
        "else{s=texture2D(fifthImage,uv(fifthTarget));mode=p[4];}\n"
        "gl_FragColor=vec4(mode.x>0.5?1.0:s.r,s.a,mode.y,1.0)*texture2D(image,texcoord).r;}\n";
    static M2DPackage package={.glsl=source,.slots=5,.samplers=5,
        .abi=M2D_NATIVE_MATERIAL_ABI,.key="test-gl-five-textures-v1"};
    return &package;
}
