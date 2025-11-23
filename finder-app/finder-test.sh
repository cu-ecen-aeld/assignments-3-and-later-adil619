#!/bin/sh
# Tester script for assignment 1,2,3,4
# Modified by Adil Chatha for Assignment 4

set -e
set -u

# ------------------------------
# Assignment 4 required locations
# ------------------------------
CONFIG_DIR="/etc/finder-app/conf"
RESULTFILE="/tmp/assignment4-result.txt"

NUMFILES=10
WRITESTR=AELD_IS_FUN
WRITEDIR=/tmp/aeld-data

username=$(cat "${CONFIG_DIR}/username.txt")
assignment=$(cat "${CONFIG_DIR}/assignment.txt")

# ------------------------------
# Argument handling
# ------------------------------
if [ $# -lt 3 ]
then
    echo "Using default value ${WRITESTR} for string to write"
    if [ $# -lt 1 ]
    then
        echo "Using default value ${NUMFILES} for number of files to write"
    else
        NUMFILES=$1
    fi
else
    NUMFILES=$1
    WRITESTR=$2
    WRITEDIR=/tmp/aeld-data/$3
fi

MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

echo "Writing ${NUMFILES} files containing string ${WRITESTR} to ${WRITEDIR}"

rm -rf "${WRITEDIR}"

# Assignment >=2 requires directory creation
if [ "$assignment" != "assignment1" ]
then
    mkdir -p "$WRITEDIR"
    if [ -d "$WRITEDIR" ]
    then
        echo "$WRITEDIR created"
    else
        exit 1
    fi
fi

# ------------------------------
# Write files using installed writer
# ------------------------------
for i in $(seq 1 $NUMFILES)
do
    writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

# ------------------------------
# Run finder using installed script
# ------------------------------
OUTPUTSTRING=$(finder.sh "$WRITEDIR" "$WRITESTR")

# Save output to required file
echo "${OUTPUTSTRING}" > "${RESULTFILE}"

# Remove temporary directory
rm -rf /tmp/aeld-data

# ------------------------------
# Validate output
# ------------------------------
echo "${OUTPUTSTRING}" | grep "${MATCHSTR}" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "success"
    exit 0
else
    echo "failed: expected ${MATCHSTR} in ${OUTPUTSTRING}"
    exit 1
fi
