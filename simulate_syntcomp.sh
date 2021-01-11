#!/bin/bash

tries=10
dir=NEW-2020-syntcomp
for k in 5 10 20 ; do
    for instance in $(ls $dir) ; do
        l=$k
        echo "Simulating with k = $k, l = $l..."
        if [ -d $dir/$instance/"k=$k" ] ; then
            continue
        fi

        ./prepare.sh $dir/$instance && ./simulate.sh -d $dir -i $instance -k $k -l $l -t 10 -c -r 

        for ((try=0; try < $tries; try += 1)); do
            d="$dir/$instance/k=$k/$try"
            mv $dir/$instance/scenarios*-n-$try.* $d
        done
    done
done
