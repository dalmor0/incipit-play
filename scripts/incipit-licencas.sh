#!/usr/bin/env bash
# Incipit Play: junta NOTICE, licenças das bibliotecas e o endereço do código deste build na pasta do app.
# Chamado no fim do scripts/deploy-windows-msys2.sh. Nunca derruba o build.
# uso: incipit-licencas.sh <pasta-do-app> <prefixo-msys>
set -u
out="$1"
prefix="${2:-/mingw64}"
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
L="$out/licencas"
mkdir -p "$L/msys2" "$L/ffmpeg" "$L/fontes"

cp "$raiz/NOTICE.md" "$out/NOTICE.md" 2>/dev/null || true
cp "$raiz"/gui/src/qml/fonts/OFL-*.txt "$L/fontes/" 2>/dev/null || true
sha="${GITHUB_SHA:-$(git -C "$raiz" rev-parse HEAD 2>/dev/null || echo desconhecido)}"
printf '%s\r\n' \
  "Incipit Play is based on chiaki-ng (https://github.com/streetpea/chiaki-ng), AGPL-3.0." \
  "Source code of this exact build: https://github.com/dalmor0/incipit-play/tree/${sha}" \
  "Third-party notices: NOTICE.md and the licencas folder." > "$out/CODIGO-FONTE-DESTE-BUILD.txt"

# as mesmas DLLs extras que o workflow copia depois (plugins do Qt pedem DLLs que a primeira passada não viu)
for pass in 1 2 3; do
  find "$out" -name '*.dll' | while read -r f; do
    objdump -p "$f" 2>/dev/null | awk '/DLL Name:/ { sub(/\r$/, "", $3); print $3 }' | while read -r n; do
      [ -n "$n" ] || continue
      [ "${n,,}" = "vulkan-1.dll" ] && continue
      if [ ! -f "$out/$n" ] && [ -f "$prefix/bin/$n" ]; then cp "$prefix/bin/$n" "$out/"; fi
    done
  done
done

: > "$L/.pkgs"
for f in $(find "$out" -name '*.dll' -printf '%f\n' | sort -u); do
  if [ -f "$prefix/bin/$f" ]; then pacman -Qoq "$prefix/bin/$f" >> "$L/.pkgs" 2>/dev/null || true; fi
done
echo "Pacotes MSYS2 que entregam as DLLs deste app (nome, versao, licenca declarada, endereco)." > "$L/PACOTES.txt"
for p in $(sort -u "$L/.pkgs"); do
  echo >> "$L/PACOTES.txt"
  pacman -Qi "$p" 2>/dev/null | grep -E '^(Name|Version|Licenses|URL) ' >> "$L/PACOTES.txt" || true
  s="${p#mingw-w64-x86_64-}"
  if [ -d "$prefix/share/licenses/$s" ]; then cp -r "$prefix/share/licenses/$s" "$L/msys2/" || true; fi
done
rm -f "$L/.pkgs"

cd "$raiz" || exit 0
cp ffmpeg-*-win64-gpl-shared-*/LICENSE* "$L/ffmpeg/" 2>/dev/null || true
for d in libplacebo SDL3-* sdl2-compat-* hidapi third-party/*; do
  [ -d "$d" ] || continue
  for lf in "$d"/LICENSE* "$d"/COPYING* "$d"/License* "$d"/LICENCE*; do
    if [ -f "$lf" ]; then mkdir -p "$L/$(basename "$d")"; cp "$lf" "$L/$(basename "$d")/" || true; fi
  done
done
echo "licencas:"; find "$L" -type f | sort
exit 0
