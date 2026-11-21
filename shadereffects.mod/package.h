#ifndef M2D_PACKAGE_H
#define M2D_PACKAGE_H
#include <stddef.h>
typedef struct {
	unsigned char *metal,*spirv,*dxbc,*glsl,*d3d11,*d3d9;
	size_t metalSize,spirvSize,dxbcSize,d3d11Size,d3d9Size;
	int slots,samplers,abi;
	char key[64];
} M2DPackage;
#endif
