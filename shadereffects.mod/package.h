#ifndef M2D_PACKAGE_H
#define M2D_PACKAGE_H
#include <stddef.h>
typedef struct {
	unsigned char *metal,*spirv,*dxbc,*glsl;
	size_t metalSize,spirvSize,dxbcSize;
	int slots,samplers,abi;
	char key[64];
} M2DPackage;
#endif
