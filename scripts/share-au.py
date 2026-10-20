#!/usr/bin/env python3
"""Package and verify an already-built AU app for a friend's test installation."""
import argparse
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--arch', required=True, choices=['arm64', 'x86_64'])
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
build = root / 'Build'
# Explicit architecture output takes precedence; native default is a fallback.
source = build / args.arch / 'Swift Audio.app'
if not source.is_dir() and args.arch == platform.machine():
    source = build / 'Swift Audio.app'
if not source.is_dir():
    parser.error(f'Build first: bash scripts/build-au.sh --arch {args.arch}')

def run(*command):
    subprocess.run([str(part) for part in command], check=True)

def verify(app):
    run('codesign', '--verify', '--deep', '--strict', app)
    for binary in [
        'Contents/MacOS/Swift Audio',
        'Contents/Frameworks/AudioUnitPlugin.framework/Versions/A/AudioUnitPlugin',
        'Contents/PlugIns/SwiftAudioPluginExtension.appex/Contents/MacOS/SwiftAudioPluginExtension',
    ]:
        run('lipo', app / binary, '-verify_arch', args.arch)

verify(source)
label = 'Intel' if args.arch == 'x86_64' else 'arm64'
folder_name = f'SwiftAudioPlugin-quality-{label}'
archive = build / f'{folder_name}.zip'
with tempfile.TemporaryDirectory(prefix='share-au-', dir=build) as temporary:
    staging = Path(temporary) / folder_name
    staging.mkdir()
    run('ditto', source, staging / 'Swift Audio.app')
    machine = 'Intel Mac' if args.arch == 'x86_64' else 'Apple Silicon Mac (M1 ili noviji)'
    (staging / 'PROCITAJ-PRVO.txt').write_text(f'''SWIFT AUDIO — probna verzija za {machine}
Zahtevi: macOS 13 ili noviji, kompatibilan AU host (npr. Logic Pro).

1. Zatvori Logic i staru aplikaciju Swift Audio ako su otvoreni.
2. Raspakuj ZIP i premesti celu Swift Audio.app u Applications, zamenjujuci
   prethodnu Swift Audio verziju ako je imas. Zadrzi samo jednu instalaciju.
3. Otvori Swift Audio jednom. Prozor je pregled kontrola, ne samostalni audio plejer.
4. Ponovo pokreni Logic. Audio FX > Audio Units > OliverJ > Swift Audio Plugin.
   Ako nije vidljiv, sacekaj registraciju i ponovi scan u Plug-in Manager-u.
5. Aplikacija mora ostati instalirana: AUv3 plugin je unutar nje.

Ovo je ad-hoc potpisan razvojni build, bez Apple notarizacije. Ako macOS blokira
aplikaciju kojoj verujes, potrazi Open Anyway u System Settings > Privacy & Security.
Ako nema te opcije ili prijavi da je aplikacija ostecena, posalji tacan tekst greske.

Novo: ispravljen soft knee kompresora i reverb pre-delay; stereo peak/GR meraci,
fabricki preseti, A/B poređenje, Copy i precizan unos brojeva. A/B slotovi traju
dok je editor otvoren. Aktivna podesavanja cuva Logic u projektu.
Promene preseta i nagla automatizacija jos mogu izazvati klikove.

Za probu: proveri mono/stereo, bypass, automatizaciju, cuvanje/otvaranje projekta
i offline bounce. Navedi model Maca, macOS, Logic verziju i konkretne korake za problem.
Intel je testiran kroz Rosettu; fizicki Intel i Logic sesije jos nisu provereni.
Detalji provere i ogranicenja su u QUALITY_REPORT.md.
''', encoding='utf-8')
    shutil.copy2(root / 'QUALITY_REPORT.md', staging)
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', staging, archive)
    run('unzip', '-tq', archive)
    extracted = Path(temporary) / 'verify'
    run('ditto', '-x', '-k', archive, extracted)
    verify(extracted / folder_name / 'Swift Audio.app')
print(archive)
