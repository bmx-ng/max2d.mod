/* Max2D.Tiled - zlib/libpng licence. Exact, bounded zlib/gzip decoding. */
#include <string.h>
#include "../../archive.mod/zlib.mod/zlib/zlib.h"

int max2d_tiled_inflate(const unsigned char *source, int source_size,
		unsigned char *dest, int dest_size, int gzip) {
	z_stream stream;
	int status, valid;
	memset(&stream, 0, sizeof(stream));
	stream.next_in = (Bytef *)source;
	stream.avail_in = (uInt)source_size;
	stream.next_out = dest;
	stream.avail_out = (uInt)dest_size;
	if (inflateInit2(&stream, gzip ? 31 : 15) != Z_OK)
		return 0;
	status = inflate(&stream, Z_FINISH);
	valid = status == Z_STREAM_END && stream.total_out == (uLong)dest_size
		&& stream.total_in == (uLong)source_size;
	inflateEnd(&stream);
	return valid;
}
