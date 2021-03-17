#!/bin/bash --norc
#
# @author Bernd Petrovitsch <bernd.petrovitsch@technikum-wien.at>
# @date $Date: 2015-03-23 14:12:21 +0100 (Mon, 23 Mär 2015) $
#
# @version $Revision: 1451 $
#
# @todo add files and dirs with a leading '-'
# @todo add user and group with a very long name
# @todo do we want to force folks to use asan?
# @todo create user and group with % in there. does that actually work?
# @todo create files and testcases with one (and more?) '%' to catch format string stupidities.
# @todo create testcase for -ls with a directory entry located on an
# XFS filesystem to trigger incorrect used of the d_type member of the
# struct dirent
# @todo add "ulimit -t" or something similar to trigger on endless loops (and kill them)
#
# URL: $HeadURL: https://svn.petrovitsch.priv.at/ICSS-BES/trunk/2015/src/myfind/test-find.sh $
#
# Last Modified: $Author: bernd $
#

set -u          # terminate on uninitialized variables
#set -e          # terminate if command fails
#set -vx         # for debugging

# the to be tested program
TO_BE_TESTED_FIND="./myfind"
# the known correct program
KNOWN_CORRECT_FIND="/usr/local/bin/bic-myfind"
# guess what ...
QUIET=0
VERBOSE=0
FORCE=0
RV=0

readonly SIMPLEDIR="/usr/local/etc/test-find/simple"
#readonly   FULLDIR="/usr/local/etc/test-find/full"
readonly    XFSDIR="/usr/local/etc/test-find/xfs"

readonly        CORRECT_STDOUT=`mktemp --tmpdir        "known-correct-find-stdout.XXXXXXXXXX"`
readonly        CORRECT_STDERR=`mktemp --tmpdir        "known-correct-find-stderr.XXXXXXXXXX"`
readonly         TESTED_STDOUT=`mktemp --tmpdir         "to-be-tested-find-stdout.XXXXXXXXXX"`
readonly         TESTED_STDERR=`mktemp --tmpdir         "to-be-tested-find-stderr.XXXXXXXXXX"`
readonly                DIFFED=`mktemp --tmpdir                           "diffed.XXXXXXXXXX"`

     EMPH_ON="\033[1;33m"
EMPH_SUCCESS="\033[1;32m"
 EMPH_FAILED="\033[1;31m"
    EMPH_OFF="\033[0m"

SUCCESS_COUNT=0
FAILURE_COUNT=0
   TEST_COUNT=0

TOUSEDIR="${SIMPLEDIR}"

#
# ---------------------------------------------------------------------------------------- functions ---
#

function show_usage() {
#    echo "USAGE: ${0} [-h--help] [-q|--quiet] [-v|--verbose] [-f|--force] [-c|--continue] [-n|--number (2|3|4)] [-p|--parameter-check] [--color (auto|always|never)] [-t|--test <path_to_the_to_be_tested_find>] [-r|--reference <path_to_the_known_correct_reference_find>]" >&2
    echo "USAGE: ${0} [-h--help] [-q|--quiet] [-v|--verbose] [-x|--xfs] [-c|--continue] [-n|--number (2|3|4)] [-p|--parameter-check] [--color (auto|always|never)] [-t|--test <path_to_the_to_be_tested_find>] [-r|--reference <path_to_the_known_correct_reference_find>]" >&2
    echo "           --help,-h: show this help" >&2
    echo "           --quiet,-q: do not show successful test results" >&2
    echo "           --verbose,-v: show a lot - probably only useful to debug the test script itself" >&2
    echo "           --continue,-c: continue after failed tests" >&2
#    echo "           --force,-f: use ${FULLDIR} instead of ${SIMPLEDIR} as test directory" >&2
    echo "           --xfs,-x: use ${XFSDIR} instead of ${SIMPLEDIR} as test directory" >&2
    echo "           --number,-n: test for 2, 3 or 4 group members. default == 3" >&2
    echo "           --parameter-check,-p: check all parameters first" >&2
    echo "           --color: auto-detect, force or cease coloring" >&2
    echo "           --test,-t: to be tested find implementation" >&2
    echo "           --reference,-r: known-correct reference implementation" >&2
}

function clean_up {
    :
#    rm -f "${CORRECT_STDOUT}" "${CORRECT_STDERR}" "${TESTED_STDOUT}" "${TESTED_STDERR}" "${DIFFED}"
}

function finish {
    clean_up
    echo -e "${EMPH_SUCCESS}Successful${EMPH_OFF} Tests: ${SUCCESS_COUNT}"
    echo -e  "${EMPH_FAILED}Failed${EMPH_OFF}     Tests: ${FAILURE_COUNT}"
    echo -e                "Total      Tests: ${TEST_COUNT} / $(( ${SUCCESS_COUNT} + ${FAILURE_COUNT} ))"
    trap - EXIT # reset it so that it does nothing
    exit "${RV}"
}

function failed() {
    local -r       ERROR_MESSAGE="${1:-}"
    local -r CORRECT_OUTPUT_FILE="${2:-}"
    local -r  TESTED_OUTPUT_FILE="${3:-}"
    echo -e "${0}: ${EMPH_FAILED}Test failed:${EMPH_OFF} ${1}"
    if [ -n "${CORRECT_OUTPUT_FILE}" -a -n "${TESTED_OUTPUT_FILE}" ]; then
        diff --ignore-space-change --unified=0 --new-file "${CORRECT_OUTPUT_FILE}" "${TESTED_OUTPUT_FILE}"
    fi
    RV=1
    if [ "${FORCE}" -eq 0 ]
    then
        exit 1
    fi
}

function success() {
    if [ "${QUIET}" -eq 0 ]
    then
        echo -e "${0}: ${EMPH_SUCCESS}Test successful:${EMPH_OFF}" "${@}"
    fi
}

function verbose() {
    if [ "${VERBOSE}" -ne 0 ]
    then
        echo "running \"${@}\""
    fi
}

#
# ------------------------------------------------------------------------------------- process args ---
#
readonly SHORT_OPTS="hvqt:r:cfn:"
readonly LONG_OPTS="help,color:"
# print nothing and just check for errors terminating the script 

readonly CMDLINE=`getopt -o "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" -- "${@}"`
if [ ${?} != 0 ]; then
    show_usage
    exit 1
fi

eval set -- "${CMDLINE}"

COLOR=auto
export GROUPMEMBERS="${GROUPMEMBERS:-3}" # to be used by find!
unset MAKE_ALL_CKECKS # to be used by find!
while [ "$#" -gt 0 ]; do
    case "${1}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    -c|--continue)
        FORCE=1
        shift
        ;;
#    -f|--force)
#	TOUSEDIR="${FULLDIR}"
#        shift
#        ;;
    -x|--xfs)
	TOUSEDIR="${XFSDIR}"
        shift
        ;;
    -q|--quiet)
        QUIET=1
        shift
        ;;
    -v|--verbose)
        VERBOSE=1
        shift
        ;;
    -t|--test)
        TO_BE_TESTED_FIND="${2}"
        echo "${0}: Using to-be-tested binary \"${TO_BE_TESTED_FIND}\""
        shift 2
        ;;
    -r|--reference)
        KNOWN_CORRECT_FIND="${2}"
        echo "${0}: Using known-correct reference binary \"${KNOWN_CORRECT_FIND}\""
        shift 2
        ;;
    --color)
        COLOR="${2}"
        shift 2
        ;;
    -n|--number)
	case "${2}" in
            2|3|4) GROUPMEMBERS="${2}";;
            *) echo "Illegal parameter for option -n: \"${2}\"" >&2
               show_usage
               exit 1
               ;;
        esac
        shift 2
        ;;
    -p|--parameter-check)
        export MAKE_ALL_CKECKS=1
        shift
        ;;
    --)
        shift
        break
        ;;
    \?)
        echo "${0}: Invalid option: -${1}" >&2
        show_usage
        exit 1
        ;;
    :)
        echo "${0}: Option -${1} requires an argument." >&2
        show_usage
        exit 1
        ;;
    *)
        echo "${0}: Option -${2} is unknown." >&2
        show_usage
        exit 1
        ;;
    esac
done

case "${COLOR}" in
    auto)
        if ! [ -t 1 ]; then # no colors if stdout is not on a tty
            EMPH_ON=""
            EMPH_SUCCESS=""
            EMPH_FAILED=""
            EMPH_OFF=""
        fi
        ;;
    never)
        EMPH_ON=""
        EMPH_SUCCESS=""
        EMPH_FAILED=""
        EMPH_OFF=""
        ;;
    always)
        ;; # do nothing
    *)
	echo "Unknown option to --color: \"${COLOR}\"" >&2
        show_usage
        exit 1
        ;;
esac
readonly EMPH_ON EMPH_SUCCESS EMPH_FAILED EMPH_OFF
readonly TO_BE_TESTED_FIND KNOWN_CORRECT_FIND QUIET VERBOSE GROUPMEMBERS

if [ "${OPTIND}" -le "$#" ]
then
    show_usage
    exit 1
fi

if [ -e "${TO_BE_TESTED_FIND}" ]
then
    echo -e "${EMPH_ON}${0}: Using to-be-tested binary \"${TO_BE_TESTED_FIND}\"${EMPH_OFF}"
else
    echo -e "${EMPH_FAILED}${0}: Cannot find to-be-tested binary \"${TO_BE_TESTED_FIND}\"${EMPH_OFF}" >&2
    show_usage
    exit 1
fi

if [ -e "${KNOWN_CORRECT_FIND}" ]
then
    echo -e "${EMPH_ON}${0}: Using known-correct reference binary \"${KNOWN_CORRECT_FIND}\"${EMPH_OFF}"
else
    echo -e "${EMPH_FAILED}${0}: Cannot find known-correct reference binary \"${KNOWN_CORRECT_FIND}\"${EMPH_OFF}" >&2
    show_usage
    exit 1
fi

echo -e "${EMPH_ON}${0}: Using directory hierarchy under \"${TOUSEDIR}\"${EMPH_OFF}"

#
# --------------------------------------------------------------------------------------- self-check ---

for dir in "${SIMPLEDIR}" "${XFSDIR}" # "${FULLDIR}"
do
      if [ ! -d "${dir}" ]
      then
          echo -e "${EMPH_FAILED}${0}: \"${dir}\" does not exist. Did you build the test environment completely?${EMPH_OFF}"
          exit 1
      fi
done

if [ ! -d "${TOUSEDIR}" ]
then
     echo -e "${EMPH_FAILED}${0}: \"${TOUSEDIR}\" does not exist. - Not yet supported!${EMPH_OFF}"
     exit 1
fi

#
# ----------------------------------------------------------------------------- install trap handler ---

trap "{ RV=1; echo \"${0}: Terminated by signal - cleaning up ...\"; finish; }" SIGINT SIGTERM
trap '{ finish; }' EXIT

#
# --------------------------------------------------------------------- Make sure our files are gone ---
clean_up

#
# ------------------------------------------------- Make us extremely nice and ignore errors on that ---
# 
renice -n 19 "$$" 2>/dev/null || :
ionice -c "3" -n "7" -p "$$" 2>/dev/null || : 

#
# -------------------------------------------------------------------------------------------- Tests ---
#

# ------------------------------------------------------------------------------------------------------
echo -e "${EMPH_ON}----- Test 0.0: Test command line parameters - unknown options ----${EMPH_OFF}"
verbose "${TO_BE_TESTED_FIND}" "${TOUSEDIR}" -die-option-gibt-es-nicht
if "${TO_BE_TESTED_FIND}" "${TOUSEDIR}" -die-option-gibt-es-nicht >&/dev/null </dev/null
then
    failed "No exit code indicating failure when calling ${TO_BE_TESTED_FIND} with \"${EMPH_ON}${TOUSEDIR} -die-option-gibt-es-nicht${EMPH_OFF}\""
    (( FAILURE_COUNT++ ))
else
    success "Exit code indicating failure when calling ${TO_BE_TESTED_FIND} with \"${EMPH_ON}${TOUSEDIR} -die-option-gibt-es-nicht${EMPH_OFF}\""
    (( SUCCESS_COUNT++ ))
fi
(( TEST_COUNT++ ))

# ------------------------------------------------------------------------------------------------------
echo -e "${EMPH_ON}----- Test 0.1: Test command line parameters - superfluous options ----${EMPH_OFF}"

function test_param()
{
    verbose "${TO_BE_TESTED_FIND}" "${TOUSEDIR}" "${@}"
    if "${TO_BE_TESTED_FIND}" "${TOUSEDIR}" "${@}" >&/dev/null </dev/null
    then
        failed "No exit code indicating failure when calling ${TO_BE_TESTED_FIND} with '${EMPH_ON}${TOUSEDIR} ${*}${EMPH_OFF}'"
        (( FAILURE_COUNT++ ))
    else
        success "Exit code indicating failure when calling ${TO_BE_TESTED_FIND} with '${EMPH_ON}${TOUSEDIR} ${*}${EMPH_OFF}'"
        (( SUCCESS_COUNT++ ))
    fi
    (( TEST_COUNT++ ))
}

test_param -user karl nicht
test_param -name so nicht
test_param -type d nicht
test_param -print nicht
test_param -ls nicht
if [ "${GROUPMEMBERS}" -ge 3 ]
then
    test_param -nouser geht gar nicht
    test_param -path "${TOUSEDIR}/so" nicht
fi
if [ "${GROUPMEMBERS}" -ge 4 ]
then
    test_param -group karl nicht
    test_param -nogroup geht gar nicht
fi


# ------------------------------------------------------------------------------------------------------
echo -e "${EMPH_ON}----- Test 0.2: Test command line parameters with a missing parameter ----${EMPH_OFF}"
test_param -user
test_param -name
test_param -type
if [ "${GROUPMEMBERS}" -ge 3 ]
then
    test_param -path
fi
if [ "${GROUPMEMBERS}" -ge 4 ]
then
    test_param -group
fi

# ------------------------------------------------------------------------------------------------------
echo -e "${EMPH_ON}----- Test 0.3: Test command line parameters with a wrong parameter ----${EMPH_OFF}"
test_param -user 123-und-du-bist-raus
test_param -user 12345678901234567890
test_param -userx root
test_param --user root
test_param -namex '*'
test_param --name '*'
test_param -type 'x'
test_param -typex 'f'
test_param --type 'f'
test_param --print
test_param --ls
if [ "${GROUPMEMBERS}" -ge 3 ]
then
    test_param -pathx '*'
    test_param --path '*'
fi
if [ "${GROUPMEMBERS}" -ge 4 ]
then
    test_param -group 123-und-du-bist-raus
    test_param -group 12345678901234567890
    test_param -groupx root
    test_param --group root
fi

# ------------------------------------------------------------------------------------------------------

# Parameters:
# filename where stdout should go
# filename where stderr should go
# the command name
# the parameters
function run_command()
{
    local -r stdoutfilename="${1}"
    local -r stderrfilename="${2}"
    shift 2
    local -r command="${1}"
    # and the rest are the parameters

    verbose "${@}"
    # if the called program is terminated by a signal, we want to see the complete
    # commandline (and not "${@}" ....)
    # diff --ignore-space-change cannot handle missings space at the head and the end of the line
    eval "${@}" 2> "${stderrfilename}" | sed -e 's/^[[:space:]]+//' -e 's/[[:space:]]+$//' | sort > "${stdoutfilename}"
    local -r rc="${PIPESTATUS[0]}"
    if [ "${rc}" -eq "0" ]
    then
        if [ -s "${stderrfilename}" ]
        then
                failed "Command \"$*\" succeeded but data on stderr in ${stderrfilename}."
        fi
    else
        if [ ! -s "${stderrfilename}" ]
        then
                failed "Command \"$*\" failed but no error message on stderr."
        fi        
    fi
    if egrep -v "^[[:space:]]*[[]?(${command}|${command##*/})[[:space:]]*(\]|:)" "${stderrfilename}"
    then
        failed "Error messages are not preceeded with the commands name"
    fi
    return "${rc}"
}

function diff_files() {
    local -r f1="${1}"
    local -r f2="${2}"
    shift 2
    local rv
    local -r cmd=$(printf '%q ' "${@}")
    if diff --ignore-space-change --unified=0 --new-file "${f1}" "${f2}" > "${DIFFED}"
    then
        success "The output for \"${EMPH_ON}${cmd}${EMPH_OFF}\" is similar."
        rv=0
    else
        cat "${DIFFED}"
        failed "The output for \"${EMPH_ON}${cmd}${EMPH_OFF}\" is wrong." "${f1}" "${f2}"
        rv=1
    fi
    rm "${DIFFED}"
    return "${rv}"
}

# "wc -l" needs a fork(2)+execve(2)
function count_lines()
{
#    local i=0
#    while read -r line
#    do
#      (( i++ ))
#    done
#    echo "${i}"
    wc -l
}

function test_single_file()
{
    local findrc myfindrc finderrlines myfinderrlines success

    success=1
    run_command "${CORRECT_STDOUT}" "${CORRECT_STDERR}" "${KNOWN_CORRECT_FIND}" "${@}"
    findrc="${?}"

    run_command "${TESTED_STDOUT}" "${TESTED_STDERR}" "${TO_BE_TESTED_FIND}" "${@}"
    myfindrc="${?}"

    # check the line count of the error file
    finderrlines=$(count_lines < "${CORRECT_STDERR}")
    myfinderrlines=$(count_lines < "${TESTED_STDERR}")
    if [ "${finderrlines}" -ne "${myfinderrlines}" ]
        then
        failed "The error line count for \"${EMPH_ON}${@}${EMPH_OFF}\" are not equivalent - ${finderrlines} vs ${myfinderrlines}." "${CORRECT_STDERR}" "${TESTED_STDERR}"
        success=0
    fi
        # check the return values
    if [ "${findrc}" -eq "0" -a "${myfindrc}" -eq 0 ] || [ "${findrc}" -ne "0" -a "${myfindrc}" -ne "0" ]
        then
            # the have the same return value. now check the output
        if ! diff_files "${CORRECT_STDOUT}" "${TESTED_STDOUT}" "${@}"
            then
            success=0
        fi
            # counters both inc'd
    else
        failed "The return values for \"${EMPH_ON}${@}${EMPH_OFF}\" are not equivalent - ${findrc} vs ${myfindrc}."
        success=0
    fi
    if [ "${success}" == 0 ]
        then
        (( FAILURE_COUNT++ ))
    else
        (( SUCCESS_COUNT++ ))
    fi
    (( TEST_COUNT++ ))
}


# called with the filter/action parameters for `find`
function test_all_files()
{
    local file
    while read -r file
    do
      test_single_file "'${file}'" "${@}"
    done < <(find "${TOUSEDIR}" ! -type d 2> /dev/null) # silently ignore files in directories which we cannot see
}

function test_directory()
{
    run_command "${CORRECT_STDOUT}" "${CORRECT_STDERR}" "${KNOWN_CORRECT_FIND}" "${@}"
    local -r findrc="${?}"

    run_command "${TESTED_STDOUT}" "${TESTED_STDERR}" "${TO_BE_TESTED_FIND}" "${@}"
    local -r myfindrc="${?}"

    # check the return values
    if [ "${findrc}" -eq "0" -a "${myfindrc}" -eq "0" ] || [ "${findrc}" -ne "0" -a "${myfindrc}" -ne "0" ]
    then
        # the have the same return value. now check the output
        if diff_files "${CORRECT_STDOUT}" "${TESTED_STDOUT}" "${@}"
        then
            (( SUCCESS_COUNT++ ))
        else
            (( FAILURE_COUNT++ ))
        fi
    else
        failed "The return values for \"${EMPH_ON}${@}${EMPH_OFF}\" are not equivalent - ${findrc} vs ${myfindrc}."
        (( FAILURE_COUNT++ ))
    fi
    (( TEST_COUNT++ ))
}

# and for which options should we test?

# we build a list as we need it later on anyways
declare -ar single_filter_00=("")
declare -ar single_filter_01=(-user "karl")
declare -ar single_filter_02=(-user "hugo")
declare -ar single_filter_03=(-user "150")
declare -ar single_filter_04=(-user "160")

declare -ar single_filter_10=(-name "so")
declare -ar single_filter_11=(-name "'*hidden'")
declare -ar single_filter_12=(-name "'*file'") # trigger failure if FNM_PERIOD is used
declare -ar single_filter_13=(-name "'file\\with\\escape\\character'") # trigger failure if FNM_NOESCAPE is not used
declare -ar single_filter_20=(-type "b")
declare -ar single_filter_21=(-type "c")
declare -ar single_filter_22=(-type "d")
declare -ar single_filter_23=(-type "p")
declare -ar single_filter_24=(-type "f")
declare -ar single_filter_25=(-type "l")
declare -ar single_filter_26=(-type "s")

declare -ar single_filter_30=(-print)
declare -ar single_action_30=(-print)

declare -ar single_filter_31=(-ls)
declare -ar single_action_31=(-ls)

if [ "${GROUPMEMBERS}" -ge 3 ]
then
    declare -ar single_filter_40=(-nouser)
    declare -ar single_filter_50=(-path "${TOUSEDIR}/so")
    declare -ar single_filter_51=(-path "'*file'") # trigger failure if FNM_PERIOD is used
    declare -ar single_filter_52=(-path "'${TOUSEDIR}/file\\with\\escape\\character'") # trigger failure if FNM_NOESCAPE is not used
    declare -ar single_filter_53=(-path "'${TOUSEDIR}?plain-file'") # trigger failure if FNM_PATHNAME is used
fi

if [ "${GROUPMEMBERS}" -ge 4 ]
then
    declare -ar single_filter_60=(-group "karl")
    declare -ar single_filter_61=(-group "hugo")
    declare -ar single_filter_62=(-group "150")
    declare -ar single_filter_63=(-group "160")
    declare -ar single_filter_70=(-nogroup)
fi

echo -e "${EMPH_ON}----- Test 1.0: Test with simple and single files ----${EMPH_OFF}"

# test special case to trigger simple faults
# see if readlink is used, file type 'l' comes out and if it works on a file
test_single_file "/var/tmp/test-find/simple/working-sym-link" -ls

# see if file type are handled
test_single_file "/var/tmp/test-find/simple" -name "socket" -ls

test_single_file "/var/tmp/test-find/simple" -name "named-pipe" -ls

test_single_file "/var/tmp/test-find/simple" -name "char-device" -ls

test_single_file "/var/tmp/test-find/simple" -name "block-device" -ls

test_single_file "/var/tmp/test-find/simple" -name "-nouser" -ls
test_single_file "/var/tmp/test-find/simple" -name "-nogroup" -ls


# see if file\with\escape\character is correctly quoted
test_single_file "/var/tmp/test-find/simple" -name 'file\with\escape\character' -ls
test_single_file "/var/tmp/test-find/simple" -name 'file\with\escape\character' -print

# see if duplicate -ls and -print is handled
test_single_file "/var/tmp/test-find/simple" -name 'plain-file' -print -print
test_single_file "/var/tmp/test-find/simple" -name 'plain-file' -print -ls
test_single_file "/var/tmp/test-find/simple" -name 'plain-file' -ls -print
test_single_file "/var/tmp/test-find/simple" -name 'plain-file' -ls -ls
# see if duplicate -ls and -print is handled with a filtr in between
test_single_file "/var/tmp/test-find/simple" -name 'plain-file' -print -type b -print
test_single_file "/var/tmp/test-find/simple" -name 'plain-file' -print -type b -ls
test_single_file "/var/tmp/test-find/simple" -name 'plain-file' -ls -type b -print
test_single_file "/var/tmp/test-find/simple" -name 'plain-file' -ls -type b -ls


# and do something: first, just one of them
for var in ${!single_filter_*}
do
#set -vx
    # pass all of the array elements
    eval test_all_files "\${$var[*]}"
#set +vx
done

# ------------------------------------------------------------------------------------------------------
echo -e "${EMPH_ON}----- Test 2.0: Test single files with two options ----${EMPH_OFF}"
i=1
# and do something: then 2 of them
for var1 in ${!single_filter_*}
do
    for var2 in ${!single_filter_*}
    do
#        if [ "${QUIET}" -eq 0 ]; then eval echo -e "\${EMPH_ON}----- Test 3.${i}: \${TOUSEDIR//\\/\\\\} \${$var1[*]} \${$var2[*]} ----\${EMPH_OFF}"; fi
        # pass all of the array elements
        eval test_directory "${TOUSEDIR}" "\${$var1[*]}" "\${$var2[*]}"
        i=$(( ${i} + 1))
    done
done

# ------------------------------------------------------------------------------------------------------
echo -e "${EMPH_ON}----- Test 3.0: Test single files with two output-only options and three all of them ----${EMPH_OFF}"
i=1
# now compose 3 output actions with 2 of all
for var1 in ${!single_action_*}
do
  for var2 in ${!single_filter_*}
  do
    for var3 in ${!single_action_*}
    do
      for var4 in ${!single_filter_*}
      do
        for var5 in ${!single_action_*}
        do
#            if [ "${QUIET}" -eq 0 ]; then eval echo -e "\${EMPH_ON}----- Test 3.${i}: \${TOUSEDIR//\\/\\\\} \${$var1[*]} \${$var2[*]} \${$var3[*]} \${$var4[*]} \${$var5[*]} ----\${EMPH_OFF}"; fi
            # pass all of the array elements
            eval test_directory "${TOUSEDIR}" "\${$var1[*]}" "\${$var2[*]}" "\${$var3[*]}" "\${$var4[*]}" "\${$var5[*]}"
            i=$(( ${i} + 1))
        done
      done
    done
  done
done

# Local Variables:
# sh-basic-offset: 4
# End:

