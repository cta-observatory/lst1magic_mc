#!/bin/bash

for dir in "$@"; do
    dirout=$dir/more
    echo mkdir $dirout
    i=0
    for plik in $(ls $dir/dl*h5); do
	if [ $i -eq 0 ]; then
	    echo "echo keep $plik"
	    i=1
	else
	    echo "mv -n $plik $dirout"
	    i=0
	fi
    done
done
