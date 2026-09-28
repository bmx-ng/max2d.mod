/* Max2D.TiledZstd - zlib/libpng licence. Bounded one-shot decompression. */
#include "../../archive.mod/zstd.mod/zstd/lib/zstd.h"

int max2d_tiled_zstd_decode(const void *source, int source_size,
		void *destination, int destination_size) {
	size_t result;
	if (source_size < 0 || destination_size < 0)
		return 0;
	result = ZSTD_decompress(destination, (size_t)destination_size,
		source, (size_t)source_size);
	return !ZSTD_isError(result) && result == (size_t)destination_size;
}
