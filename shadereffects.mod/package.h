#ifndef M2D_PACKAGE_H
#define M2D_PACKAGE_H
#include <stddef.h>
/* Shared native transport capacity; public effect-package schemas remain unchanged. */
#define M2D_NATIVE_PARAMETER_SLOTS 128
#define M2D_NATIVE_LIGHTING_ABI 7
/* Counted native material textures: the final samplers-1 vectors hold auxiliary
   coverage/premultiplied modes in binding order. Public package ABIs are unchanged. */
#define M2D_NATIVE_MATERIAL_ABI 8
typedef struct {
	unsigned char *metal,*spirv,*dxbc,*glsl,*d3d11,*d3d9;
	size_t metalSize,spirvSize,dxbcSize,d3d11Size,d3d9Size;
	int slots,samplers,abi;
	char key[64];
} M2DPackage;
#endif
