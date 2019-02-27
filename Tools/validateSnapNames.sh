#!/bin/bash
# Script to search for snapshot files in test directories, and validate their names.
# Only 8.3 FAT16 names accepted (with extension being ".sna", to even find the file)
# and each name must be unique.
#
# To validate this, all tests must be freshly built with the SNA files still in
# the particular test directories, so it makes sense to run this script right
# after "buildTests.sh" script.
shopt -s globstar nullglob

## duplicity test (case insensitive, because FAT16 is too)
# find snapshots in Tests, strip the directory name, convert to uppercase, sort alphabetically
snafiles=`for f in Tests/**/*.sna; do fn=${f##*/}; echo ${fn} | tr '[:lower:]' '[:upper:]'; done | sort`
[[ -z $snafiles ]] && echo -e "\e[93mWarning: no snap file found.\e[0m" && exit 1
exitCode=0
previousSnap=""
for f in $snafiles; do
    [[ $f == $previousSnap ]] \
        && echo -e "\e[31mError:\e[0m snapfile \e[91m$f\e[0m already exists." \
        && exitCode=$((exitCode+1))
    previousSnap=$f
done
[[ $exitCode -gt 0 ]] \
    && echo -e "\e[31mDuplicity found $exitCode times, aborting.\e[0m" && exit $exitCode

## test for invalid characters in the filename and 8.3 length (uppercased names are OK)
for f in $snafiles; do
    [[ ! $f =~ ^[-_!\$A-Z0-9]{1,8}\.SNA$ ]] \
        && echo -e "\e[31mError:\e[0m file name \e[91m$f\e[0m is not 8.3 using only: a..z 0..9 - _ ! $ " \
        && exitCode=$((exitCode+1))
done
[[ $exitCode -gt 0 ]] && exit $exitCode

## Display OK message if everything is OK
echo -e "\e[92mOK: all files have valid names.\e[0m"
exit 0
