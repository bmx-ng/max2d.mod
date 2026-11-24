# Initial spatial light-selection measurement

Release build, macOS arm64, SDL3 GPU/Metal, 2026-11-22. One local run of
`benchmarks/light_selection.bmx`, with ten warm-up and thirty measured iterations.
The [raw CSV](light-selection-metal-2026-11-22.csv) contains all cases.

| Lights | Geometry | Linear CPU ms | Indexed CPU ms |
| --- | --- | ---: | ---: |
| 32 | Static | 0.0275 | 0.0249 |
| 32 | Moving | 0.0259 | 0.0294 |
| 256 | Static | 0.0878 | 0.0336 |
| 256 | Moving | 0.0670 | 0.0413 |
| 1024 | Static | 0.1664 | 0.0526 |
| 1024 | Moving | 0.1723 | 0.0822 |

With 1,024 lights and 64 receivers, individual tests fell from 65,536 to 64 per
iteration, plus 2,438 hierarchy bounds tests. Moving geometry caused one rebuild
per iteration; static geometry caused none after warm-up. Original slot order
and output are checked separately by pixel comparisons on Metal and OpenGL,
including overlapping groups, directional lights, mask edits and resizing.

These short CPU timings are noisy. They include light updates, selection and draw
submission, not presentation or GPU timestamps. The small output and sparse
field emphasize selection work; they do not establish an application FPS gain.
The moving 32-light case was slightly slower with the hierarchy. Selection stays
opt-in, and dense overlap, X clustering and moving workloads should be measured
in the application before enabling it.
