"""Fixed-wrapper generator validation and reproducibility checks."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / 'sdl3gpueffects.mod/packages/generate.py'
spec = importlib.util.spec_from_file_location('package_generator', GEN)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Packages(unittest.TestCase):
    def setUp(self):
        self.directory = ROOT / 'sdl3gpueffects.mod/packages/colormatrix'
        self.manifest = json.loads((self.directory / 'manifest.json').read_text())

    def build(self, data, output):
        path = output / 'input.json'
        path.write_text(json.dumps(data))
        module.generate(path, output, '')

    def test_reproducible(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            self.build(self.manifest, output)
            for suffix in ('metal', 'frag', 'hlsl', 'bmx'):
                name = 'colormatrix.' + suffix
                self.assertEqual((output / name).read_bytes(), (self.directory / name).read_bytes())
            for suffix in ('frag.spv', 'dxbc'):
                name = 'colormatrix.' + suffix
                (output / name).write_bytes((self.directory / name).read_bytes())
            subprocess.run([sys.executable, str(GEN.with_name('embed.py')), str(output / 'input.json'), str(output)], check=True)
            self.assertEqual((output / 'colormatrix_assets.c').read_bytes(), (self.directory / 'colormatrix_assets.c').read_bytes())

    def test_rejects_invalid_contracts(self):
        mutations = [
            lambda d: d.update(abi=2),
            lambda d: d.update(parameters=[]),
            lambda d: d['parameters'].append(d['parameters'][0]),
            lambda d: d['parameters'][0].update(type='texture'),
            lambda d: d['parameters'][0].update(name='c'),
            lambda d: d['bodies'].update(glsl='} void main() {'),
            lambda d: d['bodies'].update(metal='#include "other.h"'),
        ]
        for change in mutations:
            data = copy.deepcopy(self.manifest)
            change(data)
            with self.subTest(data=data), tempfile.TemporaryDirectory() as temp:
                with self.assertRaises(ValueError):
                    self.build(data, Path(temp))

if __name__ == '__main__':
    unittest.main()
