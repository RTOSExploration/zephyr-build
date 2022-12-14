#!/usr/bin/env bash
# Build wllvm for zephyr sample projects

ZEPHYRPROJECT_PATH=..
. $ZEPHYRPROJECT_PATH/.venv/bin/activate
APP_ROOT_DIR=$ZEPHYRPROJECT_PATH/zephyr/samples/
APP_DIRS=$(find $APP_ROOT_DIR -type d -exec test -f '{}'/CMakeLists.txt \; -print)
#echo $APP_DIRS
#BOARDS='nrf52832_mdk reel_board 96b_aerocore2 atsamd20_xpro'
BOARDS=$(west boards | grep -vE '(qemu|native)')

export WLLVM_OUTPUT_LEVEL=INFO \
       LLVM_COMPILER=hybrid \
       LLVM_COMPILER_PATH=/usr/lib/llvm-14/bin \
       BINUTILS_TARGET_PREFIX=$(find $ZEPHYRPROJECT_PATH/zephyr-sdk-*/ \
                                -name "arm-zephyr-eabi-gcc" \
                                | xargs realpath | sed 's/-gcc$//')
echo $BINUTILS_TARGET_PREFIX

for BOARD in $BOARDS; do
  for APP_DIR in $APP_DIRS; do
    SUB_DIR=${APP_DIR#$APP_ROOT_DIR}
    #APP_NAME=$(basename "$SRC_DIR")
    BUILD_DIR=build/$BOARD/$SUB_DIR
    DB=$RTOSExploration/bitcode-db/zephyr-samples/$BOARD/$SUB_DIR
    [ -f "$DB/DONE" ] && echo "Skip $DB" && continue
    rm -rf $BUILD_DIR $DB
    mkdir -p $DB
    west build -b $BOARD -d $BUILD_DIR $APP_DIR -- -DUSE_CCACHE=0
    elf=$BUILD_DIR/zephyr/zephyr.elf
    extract-bc $elf && $LLVM_COMPILER_PATH/llvm-dis $elf.bc && \
      cp --backup=numbered $elf.bc $elf.ll $DB
    rm -rf $BUILD_DIR # save disk space
    touch $DB/DONE
  done
done
