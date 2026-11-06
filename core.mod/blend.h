#ifndef MAX2D_BLEND_H
#define MAX2D_BLEND_H
/* Public integer modes stay intact through batching and drawing-state copies.
 * Custom values are immutable descriptions, not backend resource handles. */
typedef struct M2DBlend {
	int src, dst, op, srcAlpha, dstAlpha, opAlpha;
} M2DBlend;
static int m2d_blend_decode(int mode, M2DBlend *b) {
	if (mode == 6) {
		b->src=5;
		b->dst=2;
		b->op=3;
		b->srcAlpha=1;
		b->dstAlpha=2;
		b->opAlpha=3;
		return 1;
	}
	if ((mode & 0xff000000) != 0x10000000) return 0;
	b->src=mode&15;
	b->dst=(mode>>4)&15;
	b->op=(mode>>8)&15;
	b->srcAlpha=(mode>>12)&15;
	b->dstAlpha=(mode>>16)&15;
	b->opAlpha=(mode>>20)&15;
	return b->src>=1 && b->src<=10 && b->dst>=1 && b->dst<=10 &&
		b->srcAlpha>=1 && b->srcAlpha<=10 && b->dstAlpha>=1 && b->dstAlpha<=10 &&
		b->op>=1 && b->op<=5 && b->opAlpha>=1 && b->opAlpha<=5;
}
#endif
