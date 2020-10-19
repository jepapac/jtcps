#!/bin/bash

GAME=wof
PATCH=
OTHER=
GOOD=0

while [ $# -gt 0 ]; do
    case $1 in
        -g|-game)  shift; GAME=$1;;
        -p|-patch) shift; PATCH=$1;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

for i in wof wofa wofj wofu dino dinoa dinohunt dinoj dinou punisher punisherbz punisherh punisherj punisheru mbomberj slammast slammastu mbombrd mbombrdj; do
    if [ $GAME = $i ]; then
        GOOD=1
        break
    fi
done

if [ $GOOD = 0 ]; then
    echo "The specified game is not a CPS 1.5 title"
    exit 1
fi

# Prepare ROM file and config file
make || exit $?
rom2hex $ROM/$GAME.rom || exit $?

ln -sf $ROM/$GAME.rom rom.bin
ln -sf sdram_bank0.hex sdram.hex

CFG_FILE=cps_cfg.hex
if [[ ! -e $CFG_FILE ]]; then
    echo "ERROR: could not find the required snapshot files"
    ls $CFG_FILE
    exit 1
fi

CPSB_CONFIG=$(cat $CFG_FILE)


export GAME_ROM_PATH=rom.bin
export MEM_CHECK_TIME=310_000_000
# 280ms to load the ROM ~17 frames
export BIN2PNG_OPTIONS="--scale"
export CONVERT_OPTIONS="-resize 300%x300%"

if [ ! -e $GAME_ROM_PATH ]; then
    echo Missing file $GAME_ROM_PATH
    exit 1
fi

# Generic simulation script from JTFRAME
echo "Game ROM length: " $GAME_ROM_LEN
../../modules/jtframe/bin/sim.sh -mist \
    -sysname cps15 \
    -def ../../hdl/jtcps15.def \
    -d CPSB_CONFIG="$CPSB_CONFIG" -d NODSP -d JTCPS_TURBO \
    -videow 384 -videoh 224 \
    $OTHER