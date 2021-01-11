#!/bin/bash

usage() { echo "Usage: $0 -d <dir> -k <total> -l <length> [-c] [-z] [-r]" 1>&2; exit 1; }

CONVERT=false
COMPRESS=false
REMOVE=false

while getopts d:i:k:l:t:czr opt; do
    case ${opt} in
        d) DIR=${OPTARG} ;;
        i) INST=${OPTARG} ;;
        k) TRACES_TOTAL=${OPTARG} ;;
        l) TRACE_LENGTH=${OPTARG} ;;
        t) TRIES=${OPTARG} ;;
        c) CONVERT=true ;;
        z) COMPRESS=true ;;
        r) REMOVE=true ;;
    esac
done
shift $((OPTIND-1))
if [ -z "${TRACE_LENGTH}" ] || [ -z "${TRACES_TOTAL}" ]; then
    usage
fi

TRACES_ALL_TOTAL=$(echo "$TRACES_TOTAL * $TRIES" | bc)

MODEL="${DIR}/${INST}/${INST}.smv"
COMMANDS="${DIR}/${INST}/commands"
TRACES="${DIR}/${INST}/traces"

echo "TRACES_TOTAL = ${TRACES_TOTAL}"
echo "TRACE_LENGTH = ${TRACE_LENGTH}"
echo "DIR = ${DIR}"
echo "MODEL = ${MODEL}"
echo "COMMANDS = ${COMMANDS}"
echo "TRACES = ${TRACES}"

echo "go" > ${COMMANDS}
for i in $(seq $TRACES_ALL_TOTAL); do
    echo "pick_state -r" >> ${COMMANDS}
    echo "simulate -r -k $((${TRACE_LENGTH}-1))" >> ${COMMANDS}
done
echo "show_traces -a -v -o $(realpath ${TRACES})" >> ${COMMANDS}
echo "time" >> ${COMMANDS}
echo "quit" >> ${COMMANDS}

NuSMV -keep_single_value_vars -source ${COMMANDS} ${MODEL} >/dev/null
echo "Done simulating"

if $CONVERT; then
    echo "Converting traces to scenarios..."
    java -jar convertTracesToScenarios.jar ${DIR}/${INST} $TRIES
    if $REMOVE; then
        echo "Removing traces..."
        rm -f ${TRACES}
    fi

    for ((try=0; try < $TRIES; try+=1)) ; do
        mkdir -p "${DIR}/${INST}/k=${TRACES_TOTAL}/${try}"

        #prepare BeBoSy JSON
        python add_sc.py "${DIR}/${INST}/${INST}.json" "${DIR}/${INST}/scenarios-k${TRACES_TOTAL}-l${TRACE_LENGTH}-n-${try}.bebosysc" "${DIR}/${INST}/k=${TRACES_TOTAL}/${try}/${INST}-bebosy.json"

        #prepare BoSy JSON
        python add_ltl.py "${DIR}/${INST}/${INST}.json" "${DIR}/${INST}/scenarios-k${TRACES_TOTAL}-l${TRACE_LENGTH}-n-${try}.bosysc" "${DIR}/${INST}/k=${TRACES_TOTAL}/${try}/${INST}-bosy.json"

        #prepare mixed JSON
        python add_sc.py "${DIR}/${INST}/k=${TRACES_TOTAL}/${try}/${INST}-bosy.json" "${DIR}/${INST}/scenarios-k${TRACES_TOTAL}-l${TRACE_LENGTH}-n-${try}.bebosysc" "${DIR}/${INST}/k=${TRACES_TOTAL}/${try}/${INST}-mixed.json"

    done



fi
