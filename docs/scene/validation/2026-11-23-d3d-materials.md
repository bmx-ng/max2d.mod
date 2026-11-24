# Direct3D validation of material and composition changes

These checks run the recent emissive-material and unchanged-effect-stage reuse
changes on Windows 11 Pro ARM64 (10.0.26200) in Parallels, using release x64
executables. They establish functional coverage on the virtual Direct3D device;
they are not native-hardware performance measurements.

The checked source includes `a1735d5` (emissive materials) and `c9cfe59`
(effect-stage reuse). The suites cover:

- Emission: material validation, source colour and coverage, ordinary/native
  parity, floating-point output, warm texture reuse and automatic cache invalidation.
- Composition: unchanged stage results, pixel parity against full processing,
  changed padding and source content, ordering, failure recovery and resource release.
- Lighting: the broader suite for material, shadow, grouped lighting and fallback
  behaviour, including native light-capacity negotiation.

Build and run from the Windows SDK directory, changing the profile to `d3d11`
for the second backend and repeating for `scene_composite` and `scene_lighting`:

```bat
bin\bmk.exe makeapp -r -g x64 -ud max2d_d3d9 -o C:\Temp\lighting_emission.exe mod\max2d.mod\tests\lighting_emission.bmx
C:\Temp\lighting_emission.exe
```

Use an interactive desktop session for graphics tests. The regression runner also
registers these suites under the `d3d9` and `d3d11` profiles. Successful runs print
PASS and return zero. The [result table](2026-11-23-d3d-materials.csv) records the
suite summaries. Direct3D composition has one fewer check than macOS because it
checks rejection of a second live window instead of live context migration.
