#!/bin/bash
# Builds the MIDIbox SEQ V4 macOS emulator without the (outdated) Xcode project.
#
# Usage:
#   ./build_emulator.sh          build (incremental)
#   ./build_emulator.sh clean    remove build output
#   ./build_emulator.sh run      build and start the emulator
#   V4=1 ./build_emulator.sh ... emulate the classic V4 firmware instead of V4+
#                                (separate build directory: build_v4)
#                                (SD Card folder: sequencermod/emulator_sdcard,
#                                 or set MBSEQ_SDCARD=/path/to/folder)
#
# Result: build/MBSEQ_V4_Emulator.app
#
# All core/*.c files are compiled automatically, so new sequencer files
# don't have to be registered anywhere.

set -e

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$( cd "$HERE/.." && pwd )"
MIOS32="$( cd "$APP_DIR/../../.." && pwd )"
# V4=1: classic V4 firmware (STM32F1/LPC17 core) instead of V4+, separate output directory
VARIANT_SUFFIX=""
VARIANT_DEFINE=""
if [[ "$V4" == "1" ]]; then
  VARIANT_SUFFIX="_v4"
  VARIANT_DEFINE="-DEMU_CLASSIC_V4"
fi
BUILD="$HERE/build$VARIANT_SUFFIX"
OBJ="$BUILD/obj"
BUNDLE="$BUILD/MBSEQ_V4_Emulator.app"

if [[ "$1" == "clean" ]]; then
  rm -rf "$BUILD"
  exit 0
fi

ARCH="${ARCH:-$(uname -m)}"
MIN_MACOS="11.0"

DEFINES=(
  -DMIOS32_FAMILY_EMULATION
  $VARIANT_DEFINE
  '-DMIOS32_FAMILY_STR="EMULATION"'
  '-DMIOS32_BOARD_STR="MACOS"'
)

INCLUDES=(
  -I"$HERE"
  -I"$APP_DIR/core"   # before Classes: core/tasks.h vs. Classes/Tasks.h (case-insensitive FS!)
  -I"$HERE/Classes"
  -I"$MIOS32/include/mios32"
  -I"$MIOS32/drivers/MacOS"
  -I"$MIOS32/drivers/MacOS/PYMIDI"
  -I"$MIOS32/modules/app_lcd/macos"
  -I"$MIOS32/modules/fatfs/src"
)
for m in sequencer glcd_font midifile dosfs uip_task_standard random aout blm blm_x \
         blm_scalar_master notestack file freertos_utils; do
  INCLUDES+=(-I"$MIOS32/modules/$m")
done

COMMON_FLAGS=(
  -arch "$ARCH" -mmacosx-version-min=$MIN_MACOS -g -O1
  -fcommon -fno-strict-aliasing
  -include "$HERE/midibox_seq_v4_Prefix.pch"
  -Wno-everything -Werror=implicit-function-declaration -Werror=int-conversion -Werror=pointer-to-int-cast
)
CFLAGS=(-std=gnu99 "${COMMON_FLAGS[@]}" "${DEFINES[@]}" "${INCLUDES[@]}")
OBJCFLAGS=(-std=gnu99 -fno-objc-arc "${COMMON_FLAGS[@]}" -Wno-error=int-conversion "${DEFINES[@]}" "${INCLUDES[@]}")
CXXFLAGS=(-std=gnu++11 -fno-objc-arc "${COMMON_FLAGS[@]}" "${DEFINES[@]}" "${INCLUDES[@]}")

###############################################################################
# Source files
###############################################################################
SOURCES=(
  "$HERE/main.m"
  "$APP_DIR"/core/*.c
  "$MIOS32/mios32/common/mios32_midi.c"
  "$MIOS32/mios32/common/mios32_uart_midi.c"
  "$MIOS32/mios32/common/mios32_lcd.c"
  "$MIOS32/mios32/common/mios32_din.c"
  "$MIOS32/mios32/common/mios32_dout.c"
  "$MIOS32/mios32/common/mios32_osc.c"
  "$MIOS32/modules/sequencer/seq_bpm.c"
  "$MIOS32/modules/sequencer/seq_midi_out.c"
  "$MIOS32/modules/glcd_font/glcd_font_normal.c"
  "$MIOS32/modules/midifile/mid_parser.c"
  "$MIOS32/modules/uip_task_standard/osc_client.c"
  "$MIOS32/modules/random/jsw_rand.c"
  "$MIOS32/modules/aout/aout.c"
  "$MIOS32/modules/blm_x/blm_x.c"
  "$MIOS32/modules/blm/blm.c"
  "$MIOS32/modules/blm_scalar_master/blm_scalar_master.c"
  "$MIOS32/modules/notestack/notestack.c"
  "$MIOS32/modules/file/file.c"
  "$MIOS32/modules/app_lcd/macos/app_lcd.cpp"
  "$MIOS32/modules/app_lcd/macos/CLcd.cpp"
  "$MIOS32/modules/app_lcd/macos/CLcdView.mm"
  "$MIOS32"/drivers/MacOS/PYMIDI/*.m
  "$HERE"/Classes/*.c
  "$HERE"/Classes/*.m
  "$HERE"/Classes/*.mm
)
# extra sources (e.g. stubs for functions which are not available in the emulation)
[[ -d "$HERE/emu" ]] && SOURCES+=("$HERE"/emu/*.c)

###############################################################################
# Compile (in parallel, only changed files)
###############################################################################
mkdir -p "$OBJ"

# headers may have changed: rebuild everything if any header is newer than the last build
if [[ -f "$OBJ/.stamp" ]] && [[ -n "$(find "$APP_DIR/core" "$HERE" -name '*.h' -newer "$OBJ/.stamp" -print -quit)" ]]; then
  rm -f "$OBJ"/*.o
fi

FAILED=0
OBJECTS=()
for src in "${SOURCES[@]}"; do
  [[ -f "$src" ]] || continue
  OBJECTS+=("$OBJ/$(echo "$src" | sed "s|$MIOS32/||; s|/|_|g").o")
done

# helper script which compiles a single file (called in parallel by xargs)
COMPILE="$BUILD/compile_one.sh"
{
  echo '#!/bin/bash'
  echo 'src="$1"'
  echo "obj=\"$OBJ/\$(echo \"\$src\" | sed \"s|$MIOS32/||; s|/|_|g\").o\""
  echo 'if [[ -f "$obj" && "$obj" -nt "$src" ]]; then exit 0; fi'
  echo 'case "$src" in'
  echo "  *.c)        clang   $(printf '%q ' "${CFLAGS[@]}")    -c \"\$src\" -o \"\$obj\" ;;"
  echo "  *.m)        clang   $(printf '%q ' "${OBJCFLAGS[@]}") -c \"\$src\" -o \"\$obj\" ;;"
  echo "  *.mm|*.cpp) clang++ $(printf '%q ' "${CXXFLAGS[@]}")  -c \"\$src\" -o \"\$obj\" ;;"
  echo 'esac || { echo "FAILED: $src" >&2; exit 255; }'
} > "$COMPILE"
chmod +x "$COMPILE"

printf '%s\n' "${SOURCES[@]}" | while read -r src; do [[ -f "$src" ]] && echo "$src"; done | \
  xargs -P "$(sysctl -n hw.ncpu)" -n 1 "$COMPILE" || FAILED=1

if [[ $FAILED != 0 ]]; then
  echo "*** compilation failed" >&2
  exit 1
fi
touch "$OBJ/.stamp"

###############################################################################
# Link and create app bundle
###############################################################################
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
clang++ -arch "$ARCH" -mmacosx-version-min=$MIN_MACOS "${OBJECTS[@]}" \
  -framework Cocoa -framework CoreMIDI -framework CoreAudio -framework CoreFoundation \
  -o "$BUNDLE/Contents/MacOS/MBSEQ_V4_Emulator"

sed -e 's/${EXECUTABLE_NAME}/MBSEQ_V4_Emulator/g' \
    -e 's/${PRODUCT_NAME}/MBSEQ_V4_Emulator/g' \
    -e 's/${PRODUCT_NAME:rfc1034identifier}/MBSEQ-V4-Emulator/g' \
    -e 's/${MACOSX_DEPLOYMENT_TARGET}/'$MIN_MACOS'/g' \
    "$HERE/Info.plist" > "$BUNDLE/Contents/Info.plist"

# UI: the newest Interface Builder document is English.lproj/MainMenu.nib/designable.nib
# (MainMenu_xib3.x.xib and MainMenu_nib2.x.nib are older versions)
mkdir -p "$BUILD/xib"
cp "$HERE/English.lproj/MainMenu.nib/designable.nib" "$BUILD/xib/MainMenu.xib"
rm -rf "$BUNDLE/Contents/Resources/MainMenu.nib"
ibtool --compile "$BUNDLE/Contents/Resources/MainMenu.nib" "$BUILD/xib/MainMenu.xib"

echo "Fertig: $BUNDLE"

if [[ "$1" == "run" ]]; then
  # SD Card content is stored in sequencermod/emulator_sdcard (override with MBSEQ_SDCARD)
  export MBSEQ_SDCARD="${MBSEQ_SDCARD:-$(cd "$MIOS32/.." && pwd)/emulator_sdcard}"
  # the emulated frontpanel is Wilba's MB-SEQ PCB -> use its hardware config
  # (an existing MBSEQ_HW.V4 on the emulated SD Card won't be overwritten)
  mkdir -p "$MBSEQ_SDCARD"
  if [[ ! -f "$MBSEQ_SDCARD/MBSEQ_HW.V4" ]]; then
    cp "$APP_DIR/hwcfg/wilba/MBSEQ_HW.V4" "$MBSEQ_SDCARD/MBSEQ_HW.V4"
    echo "Wilba Hardware-Konfiguration auf die emulierte SD-Karte kopiert"
  fi
  # detached from the calling shell, debug output goes to build/emulator.log
  nohup "$BUNDLE/Contents/MacOS/MBSEQ_V4_Emulator" > "$BUILD/emulator.log" 2>&1 &
  disown
  echo "Emulator gestartet (Log: $BUILD/emulator.log)"
fi
