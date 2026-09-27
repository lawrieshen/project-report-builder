#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mvn verify
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
jar = Path('target/cloud-report-service-0.1.0-SNAPSHOT.jar')
with ZipFile('target/report-api.zip', 'w', ZIP_DEFLATED) as archive:
    archive.write(jar, 'lib/report-api.jar')
print('Created backend/target/report-api.zip')
PY
