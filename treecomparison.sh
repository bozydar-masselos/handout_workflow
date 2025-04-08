#!/usr/bin/bash

#get_number_of_trees(){
folder="./renamed_trees500"
nu_of_trees=$(ls ${folder} | grep ".treefile" | wc -l) 
which_trees=$(ls ${folder} | grep ".treefile" | sort -g)

large_alignment="./large_alignment/firstry.treefile"

ls ${folder} | grep ".treefile" | sort -g |while read x; do
	echo ${folder}/${x}	
	./compare_trees.R ${large_alignment} ${folder}/${x} >> 500treescomp.txt
done
