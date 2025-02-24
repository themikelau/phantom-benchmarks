#!/bin/bash
#
# The Phantom benchmarking suite
# This wrapper script runs all benchmarks and collates the results
# Written by: Daniel Price, Feb 2019
#
if [ X$SYSTEM == X ]; then
   echo "Error: Need SYSTEM environment variable set to run PHANTOM benchmarks";
   echo "Usage: $0 [list of directories]";
   exit;
fi
if [ X$OMP_NUM_THREADS == X ]; then
   echo "Error: Need OMP_NUM_THREADS environment variable set to run PHANTOM benchmarks";
   echo "Usage: $0 [list of directories]";
   exit;
fi
if [ X$PHANTOM_DIR == X ]; then
   echo "WARNING: Need PHANTOM_DIR environment variable set to run PHANTOM benchmarks";
   PHANTOM_DIR=~/phantom;
   echo "Assuming ${PHANTOM_DIR}";
fi
#
# user-changeable settings
#
phantomdir=${PHANTOM_DIR};
nthreads=${OMP_NUM_THREADS};
htmlfile="opt-status-$SYSTEM.html";
codebinary="./phantom";
reference_server="http://data.phantom.cloud.edu.au/data/benchmarks"
#
# tolerance on how similar files shuold be
#
tol="1.e-12"
if [ ! -d $phantomdir ]; then
   echo "WARNING: $phantomdir not found";
fi
#
# preset variables
#
datetagiso=`date "+%Y-%m-%d %H:%M:%S %z"`;
red="#FF0000";
amber="#FF6600";
green="#009900";
difflog="diff-$SYSTEM-$nthreads.log";
benchlog="bench-$SYSTEM-$nthreads.log";
codelog="code-$SYSTEM-$nthreads.log";
timelog="time-$SYSTEM-$nthreads.log";
makelog="make-$SYSTEM.log";
perflog="stats-$SYSTEM-$nthreads.txt";
htmllog="log-$SYSTEM.html"
list=()
#
# run a particular benchmark
#
nfail=0
nslow=0
nbench=0
err=0
check_benchmark_dir()
{
   errlog=''
   if [ ! -e Makefile ]; then
      if [ ! -e SETUP ]; then
         errlog="setup not found"
      else
         $phantomdir/scripts/writemake.sh `cat SETUP` > Makefile
      fi
   fi
   ls *.in.s *.ref > /dev/null; err=$?;
   if [ ! $err -eq 0 ]; then
      errlog+=": infiles not found"
   fi
   if [ ! -e diffdumps ]; then
      make diffdumps >& /dev/null
      if [ ! -e diffdumps ]; then
         errlog+=": diffdumps not found"
      fi
   fi
   echo "$errlog"
}
run_benchmark()
{
   name=$1;
   download_reference
   echo "Checking ${name} benchmark..."
   rm -f $benchlog $difflog $codelog $timelog $makelog;
   nbench=$(( nbench + 1 ));
   msg=`check_benchmark_dir`
   if [ "X$msg" != "X" ]; then
      log_failure $name "$msg"
   else
      echo "Building ${name} benchmark..."
      rm -f $codebinary;
      make >& $makelog;
      # check for no errors from Make process
      grep '\*\*\*' $makelog; err=$?;
      if [ $err -ne 0 -a -e $codebinary ]; then
         echo "Running ${name} benchmark..."
         run_code
         parse_results $name
      else
         log_failure $name "failed to build"
      fi
   fi
}
# Download reference data files which
# are not commited to the repository
download_reference()
{
   while read line; do
      file=$(echo "$line" | cut -d ' ' -f 3)

      if test -f "$file"; then
         echo "Reference file $file already exists."
      else
         echo "Downloading ${reference_server}/${file}"
         curl -fLO# "${reference_server}/${file}"
      fi

   done < .hashlist

   echo "Inspecting checksums..."
   shasum -a 256 -c .hashlist

}

#
# run code and generate timing output
# could replace this routine with
# external script if desired
#
run_code()
{
  # find .in.s file and .ref file
  sfile=`ls *.in.s | head -1`;
  reffile=`ls *.ref | head -1`;
  infile=${sfile/.in.s/.in};
  # copy blah.in.s blah.in
  cp ${sfile} ${infile};
  rm -f ${reffile/.ref/};
  # run code and time it
  if [[ $MPI == "yes" ]]; then
    mpirun="mpirun -np 4"
  else
    mpirun=""
  fi
  infile_changed=1
  while [ $infile_changed -eq 1 ]; do
    cp ${infile} infile.orig;
    time -p ($mpirun $codebinary $infile >& $codelog) >& $timelog;
    # Continue if the code ran fine
    if [ $? -eq 0 ]; then
      break
    fi
    # Otherwise, check if the .in file was rewritten
    cmp -s ${infile} infile.orig
    infile_changed=$?
    if [ $infile_changed -eq 1 ]; then
      echo "${infile} was modified, re-running phantom..."
    fi
  done
  rm infile.orig;
  #walltime=`grep 'Total wall time' $codelog | cut -d'=' -f 2 | cut -d's' -f 1`
  walltime=`head -1 $timelog`;
  walltime=${walltime/real/};
  # check differences
  ./diffdumps ${reffile/.ref/} ${reffile} $tol > $difflog
  check=`grep FILES $difflog`
  if [ "$check" == " FILES ARE IDENTICAL " ]; then
     echo "$datetagiso $walltime" > $benchlog
     echo "$datetagiso $walltime" >> $perflog
  else
     echo "$datetagiso failed" > $benchlog
     echo "$datetagiso 0.0" >> $perflog
  fi
}
log_failure()
{
  nfail=$(( nfail + 1 ));
  name=$1;
  msg=$2;
  line="<tr><td bgcolor=\"$red\">$name</td><td>FAILED: $msg</td><td>N/A</td>"
  rmserr=`get_rmserr`
  line+="<td>$rmserr</td></tr>"
  echo "$line" > $htmllog;
  echo "*** $msg ***";
}
log_success()
{
  name=$1;
  timing=$5;
  resultsprev=`tail -1 ${benchlog}.prev`;
  line="<tr><td bgcolor=\"$green\">$name</td><td>$timing</td>"
  #
  # check if timings slowed by more than 10% compared to previous run
  #
  change=`get_percent $timing $resultsprev`;
  gtr_than $change 10.0; slowdown=$?
  gtr_than $change 5.0; amberslowdown=$?
  if [ $slowdown -eq 1 ]; then
     line+="<td bgcolor=\"$red\">$change</td>"
     nslow=$(( nslow + 1 ))
  elif [ $amberslowdown -eq 1 ]; then
     line+="<td bgcolor=\"$amber\">$change</td>"
  else
     line+="<td bgcolor=\"$green\">$change</td>"
  fi
  rmserr=`get_rmserr`
  line+="<td>$rmserr</td></tr>"
  echo "$line" > $htmllog;
  echo "TIME: ${timing}s CHANGE: ${change}%";
}
#
# find RMS error from diffdumps output
#
get_rmserr()
{
  rmserr=`grep 'RMS ERROR' $difflog | cut -d':' -f 2`;
  if [ "X$rmserr" == "X" ]; then
     echo "N/A"
  else
     echo "$rmserr"
  fi
}
# find percentage change in timing results
get_percent()
{
   timing=$1
   timingprev=$5
   percent=`awk -v n1="$timing" -v n2="$timingprev" 'BEGIN { print (100.*(n1-n2)/n2) }'`
   echo $percent;
}
# awk utility for floating point comparison
gtr_than()
{
 awk -v n1="$1" -v n2="$2" 'BEGIN { exit (n2 <= n1) }'
}
parse_results()
{
  results=`tail -1 $benchlog`
  fail=`echo "$results" | grep fail`;
  if [ "X${results}X" == "XX" ]; then
     log_failure $name "no output";
  elif [ "X${fail}X" == "XX" ]; then
     log_success $name $results;
     cp ${benchlog} ${benchlog}.prev;
  elif [ ! -e ${reffile/.ref/} ]; then
     log_failure $name "did not complete";
  else
     log_failure $name "results differ from reference";
  fi
}
#
# run all benchmarks in turn
#
run_all_benchmarks()
{
  for name in "$@"; do
      echo;
      cd $name;
      run_benchmark $name
      cd ..;
  done
}
#
# use only directories that exist in list of arguments
#
get_directory_list()
{
  for dir in "$@"; do
      if [ -d ${dir} ]; then
         list+=("${dir}")
      fi
  done
}
collate_and_print_results()
{
  open_html_file
  for name in $@; do
      cat $name/$htmllog >> $htmlfile;
  done
  close_html_file
}
open_html_file()
{
  echo "<h2>Checking Phantom benchmarks, SYSTEM=$SYSTEM</h2>" > $htmlfile;
  echo "<p>Benchmarks completed: `date`" >> $htmlfile;
  echo "<br/>$HOSTNAME" >> $htmlfile;
  echo "<br/>OMP_NUM_THREADS=$OMP_NUM_THREADS" >> $htmlfile;
  echo "</p><table>" >> $htmlfile;
  echo "<tr><td><strong>Benchmark</strong></td><td><strong>Time (s)</strong></td><td><strong>%Change</strong></td><td><strong>RMS error</strong></td></tr>" >> $htmlfile;
}
close_html_file()
{
  echo "</table>" >> $htmlfile;
  echo "<p>Completed $nbench benchmarks; <strong>$nfail failures</strong>; <strong>$nslow slowdowns</strong></p>" >> $htmlfile;
  echo; echo "output written to $htmlfile"
}
########################
# Start of main script #
########################
if [ $# -le 0 ]; then
   get_directory_list *;
else
   get_directory_list "$@";
fi
run_all_benchmarks ${list[@]};
collate_and_print_results ${list[@]};
if [ "$nfail" -gt 0 ] && [ "$RETURN_ERR" == "yes" ]; then exit 1; fi
