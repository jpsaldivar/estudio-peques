#!/bin/bash
# sync.sh — Sincroniza archivos HTML de altomonte/ con data.json
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_JSON="$SCRIPT_DIR/../data.json"
COLEGIO_ID="altomonte"

python3 - "$DATA_JSON" "$SCRIPT_DIR" "$COLEGIO_ID" <<'PYEOF'
import sys, json, re
from pathlib import Path

data_path   = sys.argv[1]
altomonte   = Path(sys.argv[2])
colegio_id  = sys.argv[3]
data_parent = Path(data_path).resolve().parent   # estudio-peques/

with open(data_path, encoding="utf-8") as f:
    data = json.load(f)

def existing_archivos(colegio):
    seen = set()
    for curso in colegio.get("cursos", []):
        for asig in curso.get("asignaturas", []):
            for arch in asig.get("archivos", []):
                seen.add(arch["archivo"])
    return seen

def pretty(filename):
    name = re.sub(r"\.html$", "", filename)
    name = re.sub(r"[-_]", " ", name)
    return " ".join(w.capitalize() for w in name.split())

added = 0

for colegio in data:
    if colegio["id"] != colegio_id:
        continue

    seen = existing_archivos(colegio)

    for filepath in sorted(altomonte.rglob("*.html")):
        rel_str = str(filepath.relative_to(data_parent))   # altomonte/6to/ingles/unit-2.html
        if rel_str in seen:
            continue

        parts = filepath.relative_to(altomonte).parts      # (curso, asignatura, ..., file)
        if len(parts) < 3:
            print(f"  [skip] ruta inesperada: {rel_str}")
            continue

        curso_id, asig_id = parts[0], parts[1]
        nombre = pretty(parts[-1])

        # Buscar curso y asignatura en data
        curso_obj = next((c for c in colegio.get("cursos", []) if c["id"] == curso_id), None)
        if not curso_obj:
            print(f"  [warn] curso '{curso_id}' no encontrado en data.json")
            continue
        asig_obj = next((a for a in curso_obj.get("asignaturas", []) if a["id"] == asig_id), None)
        if not asig_obj:
            print(f"  [warn] asignatura '{asig_id}' no encontrada en curso '{curso_id}'")
            continue

        asig_obj.setdefault("archivos", []).append({"nombre": nombre, "archivo": rel_str})
        seen.add(rel_str)
        print(f"  [+] {rel_str}  →  \"{nombre}\"")
        added += 1

with open(data_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

if added:
    print(f"\ndata.json actualizado — {added} archivo(s) agregado(s).")
else:
    print("\ndata.json ya estaba al día, no hubo cambios.")
PYEOF
