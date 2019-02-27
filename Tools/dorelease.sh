#!/bin/bash
# Script to search for new snapshot files in test directories, and refresh the "release"
# folder with them.
shopt -s globstar nullglob
# create release folder, if it does not exist yet
mkdir -p release
unset -v updatedSomeFile
# for all snapshots in Tests
for f in Tests/**/*.sna; do
    echo -n -e "Found snapshot: \e[96m$f\e[0m"
    dirpath=`dirname $f`
    snapname=`basename $f`
    basename=`basename -s .sna $snapname`
    # *MOVE* snapshot into release folder
    # - move, so developer of test can tell if he did refresh the release directory
    #   (but for non-developers the "release" directory should be "everything they need")
    mv $f release/$snapname
    # check if "ReadMe.txt" exists and copy it under <snapshot-base-name>.txt into release
    for readme in $dirpath/{ReadMe,readme,README,Readme}.{txt,TXT} ; do
        [[ -e $readme ]] && cp $readme release/$basename.txt \
            && echo -n -e ", updated \e[96m$basename.txt\e[0m"
    done
    # check for most recent board**.png/jpg screenshot and copy it
    # under <snapshot-base-name>.png/jpg name into release folder
    unset -v boardpic
    for bpicsearch in $dirpath/{board,Board}*{.png,.jpg} ; do
        [[ $bpicsearch -nt $boardpic ]] && boardpic=$bpicsearch
    done
    [[ -e $boardpic ]] && cp $boardpic release/$basename.${boardpic##*.} \
        && echo -n -e ", updated board pic \e[96m$basename.${boardpic##*.}\e[0m"
    echo ""     # add newline after whole line of info was produced for particular snap
    updatedSomeFile=1
done
# refresh date when release folder was updated
[[ $updatedSomeFile ]] && date -u +"%F %T %Z" > "release/!!built"
# copy the readme every time
cp release-README.txt "release/!!README.txt"
# check if some file got leftovers (there should be "3" files of same base name at most)
source Tools/chkReleaseAbundance.sh
