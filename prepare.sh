#!/bin/bash

DIR=$1

./j2m $DIR/*.json | grep inputs | awk '{print $3}' | grep -o -P '[A-Za-z0-9_]+' > $DIR/input-names
./j2m $DIR/*.json | grep outputs | awk '{print $3}' | grep -o -P '[A-Za-z0-9_]+' > $DIR/output-names
