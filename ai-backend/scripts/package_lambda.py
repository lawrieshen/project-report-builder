"""Build a locked Linux arm64 ZIP without using the host's installed packages."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def package() -> Path:
    output = ROOT / 'dist' / 'ai-compose-lambda.zip'
    output.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='prb-ai-package-') as temporary:
        workspace = Path(temporary)
        requirements = workspace / 'requirements.txt'
        target = workspace / 'package'
        subprocess.run(['uv', 'export', '--locked', '--no-dev', '--no-emit-project',
                        '--output-file', str(requirements)], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['uv', 'pip', 'install', '--python-version', '3.12',
                        '--python-platform', 'aarch64-manylinux_2_28', '--only-binary', ':all:',
                        '--require-hashes', '--no-deps', '--target', str(target),
                        '-r', str(requirements)], cwd=ROOT, check=True)
        shutil.copytree(ROOT / 'src' / 'prb_ai', target / 'prb_ai',
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        files = [file for file in sorted(target.rglob('*')) if file.is_file()
                 and '__pycache__' not in file.parts and file.suffix != '.pyc']
        if sum(file.stat().st_size for file in files) >= 250 * 1024 * 1024:
            raise ValueError('Package exceeds Lambda uncompressed size limit')
        for file in files:
            if file.suffix == '.so':
                header = file.read_bytes()[:20]
                # ELF64 little-endian, e_machine=183 (AArch64).
                if header[:6] != b'\x7fELF\x02\x01' or header[18:20] != b'\xb7\x00':
                    raise ValueError(f'Unexpected native library architecture: {file.name}')
        archive = workspace / output.name
        with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
            for file in files:
                info = zipfile.ZipInfo(file.relative_to(target).as_posix(), (2020, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(info, file.read_bytes())
        shutil.copyfile(archive, output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n')
    print(f'Built {output.name} ({output.stat().st_size} bytes), SHA256 {digest}')
    return output


if __name__ == '__main__':
    package()
