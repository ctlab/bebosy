#!/bin/bash

tries=10
dir=NEW-2019-syntcomp
for k in 5 10 20 50 100; do
    for instance in collector_v2_3 collector_v2_5 collector_v3_3 collector_v3_5 collector_v3_7 collector_v4_3 collector_v4_5; do
        l=$k
        echo "Simulating with k = $k, l = $l..."

        ./prepare.sh $dir/$instance && ./simulate.sh -d $dir -i $instance -k $k -l $l -t 10 -c  

        for ((try=0; try < $tries; try += 1)); do
            d="$dir/$instance/k=$k/$try"
            mv $dir/$instance/scenarios*-n-$try.* $d
        done
    done
done
