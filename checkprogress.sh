#!/bin/bash

dir=$1
for namestart in $(ls $dir/start*); do
    nall=$(wc -l $namestart | awk '{print $1}')
    namestop=$(echo $namestart | sed 's/start_/stop_/')
    namefail=$(echo $namestart | sed 's/start_/failed_/')
    ndone=$(wc -l $namestop | awk '{print $1}')
    echo $namestart, $ndone "/" $nall
    awk '{print $2}' $namestop | sort | uniq -c
    cat $namefail
done
