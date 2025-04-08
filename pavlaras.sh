#!/bin/bash
#Exit upon error. It terminates the execution if an error occurs.
set -e

end_message(){			#a function to write things that happend in each function of the program to a log file so I know how the data were produced.
	local text="$1"
	echo "${1}"
	if [[ ! -f ./log.txt ]] ; then
		touch log.txt
		echo 'Writing new log file'
	else
		echo 'Editing log file'
	fi
	echo "${text}" >> log.txt
	export log_file=./log.txt
	trap "mv ./log.txt ./exit_log.txt" EXIT 
}

#Function to extract values stored in yaml. We write this function in case the yaml file isn't written correctly. i.e. it might have unexpected gaps. 
get_yaml_value() {	#fine structured
	local yaml_loc=$1
	local tag=$2
	local default=$3
	#Gets the actual name of the yaml key and removes any leading or trailing white space from the value of the key. So the value can be assigned to a variable. 
	local value=$(grep "^${tag}:" "${yaml_loc}" | cut -d':' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//') 
	
	if [[ -z "$value" && -z "$default" ]]; then 
		echo "Error: required value for ${tag} not found in config file." >&2
		exit 1
	fi
	echo "${value:-$default}"
}
															#Function to exports the variables needed from YAML file and make them environment variables.!
parse_yaml() {												#fine structured
	local yaml_file=$1

	if [[ ! -f "${yaml_file}" ]]; then  						#Checks if the config file (yaml_file) exist in the pwdirectory.
		echo "Error: Config file ${yaml_file} doesn't exist"
		exit 1
	fi

	export DATA_URL=$(get_yaml_value "${yaml_file}" "data_url" "")			#Exported variables are available globally. 
	export NEXONS=$(get_yaml_value "${yaml_file}" "EXONS_to_parse" "50") 		# number of exons to parse. 
	export THREADS=$(get_yaml_value "${yaml_file}" "threads" "1")
	export Final_output_dir=$(get_yaml_value "${yaml_file}" "output_main" "./mltspe")
	export SP_counter=$(get_yaml_value "${yaml_file}" "no_of_species" "")
											#now we'lll check if the read DATA_URL contains an URL. -z checks if a variable is empty!.
	if [[ -z ${DATA_URL} ]] ; then 
		echo "Error: You need to add URL in data_url in config file"
		exit 1
	fi
	if [[ -z ${SP_counter} ]]; then 
		echo "Error: You need to provide number of species in exon alignment."
		exit 1
	fi
	end_message "Number of exons to extract is: $NEXONS "
	end_message "File should contain exon alignments of ${SP_counter} species."
} 
#the data after download will be accessed through dDATA env variable

download_data() {  											#Downloads the data from the URL provided in the yaml file. If the data are already available it skips the download.
	local data_url=$1
	local data_dir=$2

	if [[ -f "${data_dir}/exonNuc.fa.gz" ]]; then		##checks if the files exist in order to skip the download
		export dDATA="${data_dir}/exonNuc.fa.gz"
		echo "Data already downloaded!"
		return 0
	fi

	echo 'Let me download the data...' 
	mkdir "${data_dir}"

	if ! command -v wget &> /dev/null; then 
		echo 'wget is needed. Please install it first'
		exit 127
	fi 

	if ! wget -O "./${data_dir}/exonNuc.fa.gz" "${data_url}"; then 		#Checks if download was successfull by checking if the data are in the file of the path.
		echo "Couldn't not download the data from ${data_url}. The program will exit"
		error 1
	fi 
	export dDATA="${data_dir}/exonNuc.fa.gz"
}

#Function that corresponds to hndt1.sh splits file into exons. 
splitter(){													#more or less well structured
	local inputdata=$1 					#Now I have predifened the input but I could also pass it through as an arguement.  
								#Now the input is the path to the data I want unzipped and analyzed. 
	local count=1
	if ! command -v zless &> /dev/null; then 			#installs dependency if it is missing.
		echo 'zless is needed. Please install it first'
		exit 127
	fi 

	#Create the function output folder #IS TEMPOrary due to trap command. 
	export split_folder="./prouts" 
	if [[ ! -d ${split_folder} ]]; then				#check if value is a directory.
		mkdir ${split_folder}	
	fi	
	trap "rm -rf ${split_folder}" EXIT 				#no matter how the script ends (normally or due to an error), the prouts directory will be deleted!! # So I can run the script again easily
	
					
	zless "${inputdata}" | while read -r x; do

		trimmed=$(echo "$x" | tr -d '[:space:]') 	#this part checks for the double new line that separates agjacent genes.
		if [[ -z "$trimmed" ]]; then
			if $prev_empty; then 
				continue
			fi
			prev_empty=true
		else
			prev_empty=false
		fi 		

		if [[ $x =~ "hg38" ]]; then
			block=$x								#checks if the fasta sign > exist and write the line with title of sequence in block
		else
			if [[ ! $x =~ ^[[:space:]]*$ ]]; then			#if there are no spaces is next line and it is not empty, it writes the text which is the expected sequence in block.
				block=${block}"\n"${x}
			else
				if [[ $block =~ ">" ]]; then 
				echo -e $block > ./prouts/output$count.fa		#if next line is another  > marked line it writes the previous block to the outputfile.
				fi
				count=$((count+1))

				if [[ $count -gt ${NEXONS} ]]; then			#if we reach the desired count of extracted alignments as defined by the yaml file, the while loop breaks.
					break
				fi
			fi
		fi
	done 
	
	end_message "Finished the splitting"
}



gooe(){
	local temp_dir=$(mktemp -d) 
	end_message "Temporary_directory created"
	trap "rm -rf ${temp_dir}" EXIT
	export gooe_dir="./wlgenes_singleSP"
	if [[ -d "${gooe_dir}" ]]; then
		rm -rf "${gooe_dir}"
	fi
	mkdir ${gooe_dir}
	
	local cntr=1 										#counter of output.fa file for the input
	local EXONTOT="$(ls ${split_folder} | wc -l)"		#Total no. of exons.
	local EXONLFT="${EXONTOT}"							#Exons left.
	local c=-1 											#will eventually be counting no of exons per gene.
	local LE=2											#least possible no of exons concatenate.
	local z=0											#counts nu. of genes were processed. 


	if ! ls ./prouts/*.fa &> /dev/null; then 			##This makes sure that this function has sth to work on. At least one .fa file. 
		echo "Error: Slpitter function failed to provide output."
		exit 1
	fi 

	while [ $EXONLFT -gt $LE ]; do 
	##extracts_first line of exon and identifies no of exons per gene.
	head --lines=1 ./prouts/output${cntr}.fa | grep "_[[:digit:]]_[[:digit:]]" | awk -F'_' '{print $1, $3, $4}' | awk '{print $1, $2 ,$3}' > "gnxndt" 
	a=$(head gnxndt | awk '{print $1;}'| tr -d ">" )
	b=$(head gnxndt | awk '{print $2;}' )
	c=$(head gnxndt | awk '{print $3;}' ) 		#these four lines could be a function. 

	local STOP=$((cntr + c ))
	echo $EXONLFT
	echo $STOP
	if [ $STOP -ge $EXONTOT ] ; then		#controls that enough exons are left for next gene to be complete. 
	break
	fi
	echo $a $b $c && echo $a $c >> geneinfo		#this file contains the genes I actually processed. Usefull later for multigene alignment.
	local k=1
	for i in $(seq ${SP_counter}) ; do												#this counter neeeds to go to SP_counter number of species. depending on input.
	local j=$((k+1))													#counts the lines where there is sequence.
	sed -n -e "${k}p" ./prouts/output${cntr}.fa | awk -F"_" '{print $1 "_" $2}' >> ${gooe_dir}/${a}_${i}.fasta 	#this line makes for the name to be only in the first line
	local b=1	
	#next loop concatenates all exons of the gene.
	while [ $b -le $c ]; do
			#echo $b $c 
			sed -n -e "${j}p" ./prouts/output${b}.fa >> "${temp_dir}/gene_${a}_${i}" 				# makes for all the sequences of the gene to be addeed to the ne file. These files I could delete before the end of the script to reduce garbage.
			b=$((b+1))
		done
	tail -${c} ${temp_dir}/gene_${a}_${i} | tr -d '\n' >> ${gooe_dir}/${a}_${i}.fasta
	#removes spaces between exon lines #adds a newline at the end for proper fasta format. I keep ${i} as counter in file name so I will be able to sort output files in fine order everytime.	
	printf "\n" >> ${gooe_dir}/${a}_${i}.fasta									
	k=$((k+2))
	done
	z=$((z+1))
	cntr=$((cntr + c))		#everytime except from c, add one so next iterations the exon of next gene instead of the final exon of previous gene. which would have happened without adding one.
	#echo $cntr
	EXONLFT=$((EXONLFT - c - 1)) 
	done
	rm ./gnxndt
	end_message "Finished processing exons of ${z} genes."
	end_message "${EXONLFT} exons left non-processed. Exons left don't suffice for a complete gene."
	#printf "Now run mltgn.sh in the working directory to create multi-species complete gene fasta files.\n"
} 

multigene_concat(){											#Concatenates the genes of each species, produces one single-gene multi-species alignment
										#Creates directory for output
	if [[ -d "${Final_output_dir}" ]]; then
		rm -rf "${Final_output_dir}"
	fi
	mkdir "${Final_output_dir}"
	
	local ct1=$(cat ./geneinfo | wc -l) 					#this counts for how many genes we will make mutlisp. files.
										#Gene_concatenation
	for i in $(seq 1 ${ct1}); do
		gnnm=$(head -n ${i} ./geneinfo| tail -n 1| awk '{print $1;}')		#genename
		for j in $(seq 1 ${SP_counter}); do
			cat ${gooe_dir}/${gnnm}*_${j}.fasta >> ${Final_output_dir}/${gnnm}_mlaln.fasta		#just adds the content of the gooe() ouput elements into a new multifasta file. 
		done
	done
	end_message "Finished concatenating genes of species. Output '.fasta' files are in '${Final_output_dir}' folder in working directory."
}

main(){
	local CONFIG=$1 						#file with config data is provided with it's path
	#local EXONS=$2							#of exons to extract is provided	
									#makes sure that user provides a config files(input_data).	
	if [[ ! -f "${CONFIG}" ]]; then 
		echo "You haven't provided an config file."
		exit 1
	fi
	parse_yaml ${CONFIG} 	


									#makes sure that user provides a number of exons to extract .
	if [[ -z $NEXONS ]]; then
		echo "You havn't provided a number of exons to process."
		exit 1
	else: 
		echo "I'll process "${NEXONS}" exons. "
	fi
	download_data $DATA_URL "./input_data"
	splitter $dDATA
	gooe 
	multigene_concat
	
	echo  "SYSTEM log:" 
	cat $log_file  							# This prints out all the messages we want our user to have. Except error messages.  
									#this line will only work after the download function has runned 		
	}


#Runs the workflow, $@ stands for all the arguments that main function can take. 	
main "$@"
