#!/bin/bash
# Check if there is abundance of "release" files (two board photos, or whatever)
# In correct case each test should have at most 3 files (SNA + TXT + board-image)
shopt -s globstar nullglob
# check if release folder exists
[[ ! -d release ]] && echo -e "\e[31mError:\e[0m \e[96mrelease\e[0m folder not found." && exit 1

## helper function to detect abundance ( $currentGroup should contain all group files )
checkForTooManyFiles() {
    [[ ${#currentGroup[@]} -lt 4 ]] && return 0
    echo -e "\e[31mError:\e[0m for \e[96m$currentBase\e[0m there are"\
    "\e[91m${#currentGroup[@]}\e[0m files: \e[96m${currentGroup[@]}\e[0m"
    return 1
}

## main loop of check, grouping files by their basename into variable $currentGroup
exitCode=0
currentBase=""
currentGroup=()
for f in release/*; do
    fn=${f##*/}
    cn=${fn%.*}
    if [[ $cn != $currentBase ]]; then
        checkForTooManyFiles || exitCode=$((exitCode + 1))
        currentBase=$cn && currentGroup=()
    fi
    currentGroup+=($fn)
done
# check for last group from the loop
checkForTooManyFiles || exitCode=$((exitCode + 1))
# display OK message if no error was detected
[[ $exitCode -eq 0 ]] && echo -e "\e[92mOK: no abundance of \"release\" files detected.\e[0m"
exit $exitCode
