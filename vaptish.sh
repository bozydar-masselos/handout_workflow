#!/usr/bin/bash


echo "This  is a script for renaming the outputs (prouts) of pavlaras.sh" 
set -e

get_number_of_files_to_rename(){
	in_folder=$1
	nu_of_files=$(ls ./${in_folder} |wc -l)
	echo "Will rename "${nu_of_files}" alignments."
}

papas(){						#This is the name giving function. It removes the sin of long name replasing it with a species name only
	for i in $(seq 1 ${nu_of_files});do
	FILEPATH=./${in_folder}/output${i}.fa	
	echo ${FILEPATH}
	NEWFILE=$( echo ${FILEPATH} | awk -F "/" '{print $3}')
	echo ${NEWFILE}

	cat "${FILEPATH}" | while read x ; 
	do 
		if [[ $x =~ ">" ]]; then
		echo $x| awk -F "_" '{print ">" $2}' >> ./${OUTPUT_DIR}/${NEWFILE}
		else
			echo $x >> ./${OUTPUT_DIR}/${NEWFILE} 
		fi
	done
done	
}



main(){
	INPUT_DIR=$1
	INPUT_DIR=${INPUT_DIR//\//}
	OUTPUT_DIR=$2
	OUTPUT_DIR=${OUTPUT_DIR//\//}
	echo ${INPUT_DIR} ${OUTPUT_DIR} 
	get_number_of_files_to_rename ${INPUT_DIR}
	papas
}

main "$@"
