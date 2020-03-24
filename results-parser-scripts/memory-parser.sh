#/bin/sh
# By Narunas Kapocius
# 2020 02 16
# Sar output binary results file interrupts parameter parser script

#Variables
results_store_dir=`pwd`

#Read arguments
source_dir=$1
results_store_dir=$2
results_file=$3
parse_regex=$4

if [ -z $source_dir ] || [ -z $results_store_dir ] || [ -z $results_file ] || [ -z $parse_regex ]
then
  echo "Please provide source data directory, results store directory, file name to which write results and which regex to use for file names parser"
  echo "./interrupts-parser.sh source-data-dir results-store-dir results-file-name team|kube|phys"
  echo "Exiting.."
  exit
fi

#clean working files to prevent results overlap
echo "" > $results_store_dir/filesList.txt
echo "" > $results_store_dir/$results_file

#write sar results file list to fileList.txt
echo -n  "$(ls $source_dir > $results_store_dir/filesList.txt)"

files_array=`cat $results_store_dir/filesList.txt`

for file_name in $files_array
do
  if [ $parse_regex == "team" ]
  then
    test_name=`echo "$file_name" | grep -Po "kw\d\w{4}\d_kw\d\w{4}\d_\w{8}-\d_\w{3}-\d{2,4}_\d"`
  elif [ $parse_regex == "kube" ]
  then
    test_name=`echo "$file_name" | grep -Po "kube-worker\d-\w{3}-\d{2,4}_\d-\d{8}-\d{6}"`
  else
    test_name=`echo "$file_name" | grep -Po "kw\d\w{3}\d_kw\d\w{3}\d_\w{3}-\d{2,4}_\d-\d{8}-\d{6}"`
  fi
  echo "Processing $test_name"
  #parse kbcached memory and write to results to file
  results=`sadf -p $source_dir/$file_name -- -r  | grep -Po "kbcommit.\d*" | grep -Po "\d*"`
  printf "$results\\n" > $results_store_dir/$test_name\_kbcommit.txt
  kbcommit_value_array=`cat $results_store_dir/$test_name\_kbcommit.txt`
  counter=0
  idle_kbcommit_counter=0
  work_kbcommit_counter=0
  for value in $kbcommit_value_array
  do
    if [ $counter -lt 60 ]
    then
      idle_kbcommit_counter=`lua -e "print($idle_kbcommit_counter+$value)"`
    elif [ $counter -gt 60 ] && [ $counter -lt 180 ]
    then
      work_kbcommit_counter=`lua -e "print($work_kbcommit_counter+$value)"`
    fi
    counter=$(($counter+1))
  done
  idle_kbcommit_counter_avg=`lua -e "print($idle_kbcommit_counter/60)"`
  work_kbcommit_counter_avg=`lua -e "print($work_kbcommit_counter/120)"` 
  printf "$test_name $idle_kbcommit_counter_avg $work_kbcommit_counter_avg \\n" >> $results_store_dir/$results_file
done
