#!/bin/bash
MOUNT_DATA=${1}/simplace_data
MOUNT_WORK=${1}/simplacecheckout_run/trunk/simulation/
MOUNT_OUT=${1}/simplace_out
MOUNT_FINAL=${1}/simplace_final
MOUNT_PROJECT=${1}/simplace_project
SOLUTION=SimulationExperimentTemplate/solution/Lintul5.sol.xml
PROJECT=SimulationExperimentTemplate/project/Lintul5All.proj.xml
DEBUG=true
LINE_START=1
LINE_END=8
TESTRUN=false

VERSION=4.3_final.2

CONTAINER_NAME="simplace_test_run"

docker run \
--mount type=bind,source=$MOUNT_WORK,target=/simplace/SIMPLACE_WORK \
--mount type=bind,source=$MOUNT_OUT,target=/outputs \
--mount type=bind,source=$MOUNT_DATA,target=/data \
--mount type=bind,source=$MOUNT_PROJECT,target=/projects \
--rm \
--name $CONTAINER_NAME \
--user $(id -u):$(id -g) \
zalfrpm/simplace-hpc:$VERSION /simplace_start.sh $SOLUTION $PROJECT $DEBUG $LINE_START $LINE_END $TESTRUN

LINE_SPLITUPSTR=($(
docker run \
--mount type=bind,source=$MOUNT_WORK,target=/simplace/SIMPLACE_WORK \
--mount type=bind,source=$MOUNT_OUT,target=/outputs \
--mount type=bind,source=$MOUNT_DATA,target=/data \
--mount type=bind,source=$MOUNT_PROJECT,target=/projects \
--rm \
--name $CONTAINER_NAME \
--user $(id -u):$(id -g) \
zalfrpm/simplace-hpc:$VERSION /splitsimplaceproj/splitsimplaceproj /simplace/SIMPLACE_WORK/$PROJECT 4 10 _WORKDIR_?/simplace/SIMPLACE_WORK _PROJECTSDIR_?/projects _DATADIR_?/data
))

DEPENDENCY=afterany
IFS=',' # (,) is set as delimiter
read -ra ADDR <<< "$LINE_SPLITUPSTR" # str is read into an array as tokens separated by IFS

for i in "${ADDR[@]}"; do # access each element of array
    IFS='-' # (-) is set as delimiter
    read -ra SOME <<< "$i" # string is read into an array as tokens separated by IFS
    IFS=' ' # reset to default value after usage
    STARTLINE=${SOME[0]}
    ENDLINE=${SOME[1]}
	#sbatch commands
	SBATCH_COMMANDS="--parsable --job-name=${SBATCH_JOB_NAME}_${i} --time=${TIME} --cpus-per-task=40 -o log/simplace-%j"
	#simplace sbatch script commands
    #SIMPLACE_INPUT="${MOUNT_DATA} ${MOUNT_WORK} ${MOUNT_OUT} ${MOUNT_OUT_ZIP} ${MOUNT_PROJECT} ${SOLUTION_PATH} ${PROJECT_PATH} ${IMAGE_DIR}/${SINGULARITY_IMAGE} ${DEBUG} ${STARTLINE} ${ENDLINE} ${SBATCH_JOB_NAME}_${i} false"
    echo "First  $STARTLINE"
    echo "Second $ENDLINE"
    echo "$i"

	echo "sbatch $SBATCH_COMMANDS batch/sbatch_simplace.sh ..."
	#BATCHID=$( sbatch $SBATCH_COMMANDS batch/sbatch_simplace.sh $SIMPLACE_INPUT )
    #DEPENDENCY=DEPENDENCY":"BATCHID
done

docker run -it \
--mount type=bind,source=$MOUNT_OUT,target=/outputs \
--mount type=bind,source=$MOUNT_FINAL,target=/final \
--rm \
--name $CONTAINER_NAME \
--user $(id -u):$(id -g) \
zalfrpm/simplace-hpc:$VERSION 