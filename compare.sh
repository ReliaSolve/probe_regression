#!/bin/bash
#############################################################################
# Run regression tests against a specified target (default master) and a
# specified original (default 9b198c1d1bb2cbf19cd404d372294836bda8ed0a)
# to make sure that the only differences between the outputs have to do with
# the version information printed at the beginning of the output file.
#
# Tests are run using all of the files in the test_files directory.
#
# Both versions of probe are built and then they are both run against each file.
#############################################################################

######################
# Parse the command line

new="master"
orig="9b198c1d1bb2cbf19cd404d372294836bda8ed0a"
if [ "$1" != "" ] ; then new="$1" ; fi
if [ "$2" != "" ] ; then orig="$2" ; fi

echo "Checking $new against $orig"

#####################
# Make sure the probe submodule is checked out

echo "Updating submodule"
git submodule update --init
(cd probe; git pull) &> /dev/null 

######################
# Check out each version and build each.
# The original version is build using Make because older versions don't
# have CMakeLists.txt files.

echo "Building $orig"
(cd probe; git checkout $orig; make) &> /dev/null 

echo "Building $new"
(cd probe; git fetch)
(cd probe; git checkout $new) &> /dev/null
(cd probe; git pull)
mkdir -p build_new
(cd build_new; cmake -DCMAKE_BUILD_TYPE=Release ../probe; make) &> /dev/null

orig_exe="./probe/probe"
orig_args=""
new_exe="./build_new/probe"
new_args=""

######################
# Generate two outputs for each test file, redirecting standard
# output and standard error to different files.
# Test the standard outputs to see if any differences are other than we expect.

echo
mkdir -p outputs
files=`ls test_files`
failed=0
for f in $files; do
  ##############################################
  # Full input-file name
  inf=test_files/$f

  # We must extract to a file and then run with that file as a command-line argument
  # because the original version did not process all models in a file when run with
  # the model coming on standard input.
  tfile=outputs/temp_file.tmp
  gunzip < $inf > $tfile

  ##############################################
  # Test with no command-line arguments

  echo "Testing file $f"
  # Run old and new versions in parallel
  ($orig_exe $orig_args $tfile > outputs/$f.orig 2> outputs/$f.orig.stderr) &
  ($new_exe $new_args $tfile > outputs/$f.new 2> outputs/$f.new.stderr) &
  wait

  # Strip out expected differences
  grep -v caption < outputs/$f.orig | grep -v command > outputs/$f.orig.strip
  grep -v caption < outputs/$f.new  | grep -v command > outputs/$f.new.strip

  # Test for unexpected differences
  d=`diff outputs/$f.orig.strip outputs/$f.new.strip | wc -c`
  if [ $d -ne 0 ]; then echo " Failed!"; failed=$((failed + 1)); fi

done

echo
if [ $failed -eq 0 ]
then
  echo "Success!"
else
  echo "$failed files failed"
fi

exit $failed

