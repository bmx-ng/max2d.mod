#include <max2d.mod/shadereffects.mod/package.h>
void *m2d_test_d3d_texture_set(unsigned char *d3d9,int size9,unsigned char *d3d11,int size11) {
    static M2DPackage package;
    package.d3d9=d3d9;package.d3d9Size=size9;
    package.d3d11=d3d11;package.d3d11Size=size11;
    package.slots=5;package.samplers=5;package.abi=M2D_NATIVE_MATERIAL_ABI;
    const char key[]="test-d3d-five-textures-v1";
    for(unsigned i=0;i<sizeof(key);i++) package.key[i]=key[i];
    return &package;
}
