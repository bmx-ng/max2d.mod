# Attribution

`core.mod/blitzfont.bin` is copied unchanged from BRL.Max2D, whose module
identifies its copyright as Blitz Research Ltd and license as zlib/libpng.
The surrounding Max2D implementation is new, with the familiar BlitzMax Max2D
public API retained where currently supported; it is not the original BRL code.

BRL, Math.Polygon, BRL.RectPacker, Image.PNG, Text.JSON, Text.HBFreeTypeFont,
FreeType/HarfBuzz and SDL3 remain separate
dependencies under their
own licenses. This repository neither copies nor modifies the vendored SDL3 source.

`examples/oldskool2.bmx` is adapted from Binary Therapy's Oldskool2 sample,
released into the public domain in 2004 according to its accompanying readme.
Original code: Mikkel Løkke (FlameDuck); logo: Andreas Engström (Razorien);
music: Rob Farley (Dr Av); font credited in the source to FONText/Beaker.
Assets remain in the SDK's `samples/flameduck/oldskool2` directory.

`examples/viewport.bmx` is adapted from the SDK's `samples/hitoro/viewport.bmx`;
the accompanying hitoro info.txt credits James L Boyd, Blitz Support. Its image
assets remain in the SDK samples directory.

`examples/filmclip.bmx`, `examples/snowfall.bmx` and
`examples/background_loading.bmx` are adapted from the corresponding SDK samples
under `birdie/misc/filmclip`, `simonh/snow` and `threads`. Snowfall credits simonh
(si@si-design.co.uk). The ports retain original source comments; PNG assets remain
in the SDK samples tree and are embedded at build time.
