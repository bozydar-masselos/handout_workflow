#!/usr/bin/bash

in_folder="./whole_genes_renamed"
OUTPUT_DIR=$1
ls ./${in_folder} | while read x ; do
	echo $x
	FILEPATH=${in_folder}/${x}	
	NEWFILE=$(echo ${x})

	echo $FILEPATH
	echo $NEWFILE

	iqtree2 -s ${FILEPATH} -redo -pre ${NEWFILE} -B 1000 -T AUTO || true
done
