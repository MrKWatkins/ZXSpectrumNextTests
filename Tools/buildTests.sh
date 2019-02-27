#!/bin/bash
# Script to rebuild all tests - it will try to assemble any "*.asm" file (except "*.i.asm")
# in any folder Tests/*/  (not directly in Tests folder, like "Tests/x.asm" - ignored)

shopt -s globstar nullglob
pushd () {
    command pushd "$@" > /dev/null
}
popd () {
    command popd "$@" > /dev/null
}
whitespace="                       "
unset -v last_result

# for all *.asm in Tests/*/**
for f in Tests/*/**/*.asm; do
    # ignore "include" files (must have ".i.asm" extension)
    if [[ ".i.asm" == ${f:(-6)} ]]; then
        continue
    fi
    # standalone .asm file was found, try to build it
    dirpath=`dirname $f`
    asmname=`basename $f`
    echo -e "\e[95mBuilding\e[0m file \e[96m${asmname}\e[0m ${whitespace:${#asmname}}in test \e[96m${dirpath:6}\e[0m"
    # switch to test directory and run assembler (break the FOR in case of error)
    pushd $dirpath
    sjasmplus --fullpath --nologo $asmname
    last_result=$?
    popd
    if [[ $last_result -ne 0 ]]; then
        echo -e "\e[31mError status $last_result returned, aborting.\e[0m"
        exit $last_result
    fi
done
# check if "last_result" is unset
[[ -z ${last_result+x} ]] && echo "No ASM files found!" && exit 0
echo -e "\e[92mOK: all files assembled.\e[0m"

# validate all snapshot filenames
Tools/validateSnapNames.sh
