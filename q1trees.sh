#!/usr/bin/bash

echo "This is a script for creating trees for all the alignment in a folder." 


set -e 
get_number_of_trees(){
	local in_folder=$1
	nu_of_trees=$(ls ./${in_folder} |wc -l)
	echo "I will produce trees for "${nu_of_trees}" alignments."
}
	
treemaker(){
	for i in $(seq 1 ${nu_of_trees}); do
	exon_to_process=$(head -n1 ./${input_dir}/output${i}.fa | awk -F "_" '{print $1 "_" $3}')
	echo ${exon_to_process}										#this is from first run when  I used the variable to name the new files.
	#mkdir ./${exon_to_process}
	iqtree2 -s ./${input_dir}/output${i}.fa -redo -pre ./${output_dir}/renamedtree${i} || true  
	done
}


main(){									#you need to give as first the name of the folder where the alignments are and as second the folder to direct the output:
	output_dir=$2	
	input_dir=$1	
	get_number_of_trees prouts
	echo ${nu_of_trees}

	if [[ ! -d ./${output_dir} ]]; then
		mkdir ./${output_dir}
		echo "Creating output directory"
	else
		echo "Output dir already exists"
	fi
	treemaker
}

main "$@"
