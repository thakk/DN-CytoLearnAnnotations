$HOSTNAME = ""
params.outdir = 'results'  


if (!params.TrainingCases){params.TrainingCases = ""} 
if (!params.RandomSeed){params.RandomSeed = ""} 
if (!params.CytoHost){params.CytoHost = ""} 
if (!params.CytoPrivKey){params.CytoPrivKey = ""} 
if (!params.CytoPubKey){params.CytoPubKey = ""} 
if (!params.CytoProjectId){params.CytoProjectId = ""} 

Channel.value(params.TrainingCases).set{g_2_Value_g_0}
Channel.value(params.RandomSeed).set{g_3_Value_g_0}
Channel.value(params.CytoHost).set{g_6_Value_g_1}
Channel.value(params.CytoPrivKey).set{g_7_Value_g_1}
Channel.value(params.CytoPubKey).set{g_8_Value_g_1}
Channel.value(params.CytoProjectId).set{g_9_Value_g_1}


process PullCytoProjectAnn {

publishDir params.outdir, overwrite: true, mode: 'copy',
	saveAs: {filename ->
	if (filename =~ /annotations\/.*csv$/) "CytoAllAnn/$filename"
	else if (filename =~ /.*log$/) "CytoPullLog/$filename"
}

input:
 val CytoHost from g_6_Value_g_1
 val CytoPrivKey from g_7_Value_g_1
 val CytoPubKey from g_8_Value_g_1
 val ProjectId from g_9_Value_g_1

output:
 file "annotations/*csv"  into g_1_csvFile_g_0
 file "*log"  into g_1_logFile

"""
python3 /home/hakkinet/Python/omat/get_project_annotations.py --cytomine_host ${CytoHost} --cytomine_public_key ${CytoPubKey} --cytomine_private_key ${CytoPrivKey} --cytomine_id_project ${ProjectId} > ${ProjectId}.log
mkdir annotations
cat annotations.csv | tr ";" "," > annotations/annotations.csv
"""
}

g_3_Value_g_0= g_3_Value_g_0.ifEmpty([""]) 


process SplitFileRandomly {

publishDir params.outdir, overwrite: true, mode: 'copy',
	saveAs: {filename ->
	if (filename =~ /training\/training.csv$/) "TrainingCSV/$filename"
	else if (filename =~ /test\/test.csv$/) "TestCSV/$filename"
}

input:
 file inputCSV from g_1_csvFile_g_0
 val NumInTraining from g_2_Value_g_0
 val RandomSeed from g_3_Value_g_0

output:
 file "training/training.csv"  into g_0_trainCSV_g_12
 file "test/test.csv"  into g_0_testCSV

script:
remainingLines = NumInTraining.toInteger()+1
"""
get_seeded_random() {   seed="\$1"; openssl enc -aes-256-ctr -pass pass:"\$seed" -nosalt </dev/zero 2>/dev/null; }
mkdir training
mkdir test
head -n 1 ${inputCSV} > training/training.csv
head -n 1 ${inputCSV} > test/test.csv
tail -n +2 ${inputCSV} > temp.csv
sort -R --random-source=<(get_seeded_random ${RandomSeed}) temp.csv | head -n ${NumInTraining} >> training/training.csv
sort -R --random-source=<(get_seeded_random ${RandomSeed}) temp.csv | tail -n ${remainingLines} >> test/test.csv

"""

}


process PullCytoCrop {

publishDir params.outdir, overwrite: true, mode: 'copy',
	saveAs: {filename ->
	if (filename =~ /pullCrops.log$/) "Croplog/$filename"
}

input:
 file CytoAnnotations from g_0_trainCSV_g_12.splitCsv(header:true)

output:
 file "pullCrops.log"  into g_12_logFile

"""
echo ${CytoAnnotations.Term} > pullCrops.log
"""
}


workflow.onComplete {
println "##Pipeline execution summary##"
println "---------------------------"
println "##Completed at: $workflow.complete"
println "##Duration: ${workflow.duration}"
println "##Success: ${workflow.success ? 'OK' : 'failed' }"
println "##Exit status: ${workflow.exitStatus}"
}
