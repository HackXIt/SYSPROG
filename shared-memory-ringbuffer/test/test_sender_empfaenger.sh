#!/bin/bash --norc
#
# @author Bernd Petrovitsch <bernd.petrovitsch@technikum-wien.at>
# @author Thomas M. Galla <thomas.galla@technikum-wien.at>
# @date 2005/02/22
#
# @version $Revision: 1682 $
# 
# @todo Nothing to do. - Everything perfect! ;-)
#
# URL: $HeadURL: https://svn.petrovitsch.priv.at/ICSS-BES/trunk/2015/src/sender-empfaenger/test_sender_empfaenger.sh $
#
# Last Modified: $Author: tom $

set -u		# terminate on uninitialized variables
set -e		# terminate if command fails
#set -vx	# for debugging

#
# ------------------------------------------------------------------------------------------ globals ---
#

readonly PROGNAME="$0"

readonly MYTMPDIR="${TMPDIR:-/tmp}"
readonly STDERRFILENAME=`mktemp ${MYTMPDIR}/stderr.XXXXXXXXXX`

SENDER="./sender"
EMPFAENGER="./empfaenger"
DELAYTIME="15"
IGNORE_FAILED_TESTS="0"
QUIET="0"

readonly USAGEMSGREGEX="^[[:space:]]*(USAGE|Usage|usage)"

readonly TESTS=" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 "

readonly MYUID=`whoami`

readonly SHM_KEYS_BEFORE_FILE=`mktemp ${MYTMPDIR}/shmkeys_before.XXXXXXXXXX`
readonly SEM_KEYS_BEFORE_FILE=`mktemp ${MYTMPDIR}/semkeys_before.XXXXXXXXXX`
readonly SHM_KEYS_AFTER_FILE=`mktemp ${MYTMPDIR}/shmkeys_after.XXXXXXXXXX`
readonly SEM_KEYS_AFTER_FILE=`mktemp ${MYTMPDIR}/semkeys_after.XXXXXXXXXX`

readonly SMALL_BINARY_FILE="/usr/local/etc/small_binary_file.bin"
readonly SMALL_TEXT_FILE="/usr/local/etc/small_text_file.txt"
readonly HUGE_BINARY_FILE="/usr/local/etc/huge_binary_file.bin"
readonly GET_SHM_LIMIT_FILE="/usr/local/bin/bic-get_shm_limit"

readonly SMALL_BINARY_FILE_RESULT=`mktemp ${MYTMPDIR}/small_binary_file_result.bin.XXXXXXXXXX`
readonly SMALL_TEXT_FILE_RESULT=`mktemp ${MYTMPDIR}/small_text_file_result.txt.XXXXXXXXXX`
readonly HUGE_BINARY_FILE_RESULT=`mktemp ${MYTMPDIR}/huge_binary_file_result.bin.XXXXXXXXXX`


SHM_KEYS_AFTER=""
SEM_KEYS_AFTER=""
SHM_KEYS_BEFORE=""
SEM_KEYS_BEFORE=""

EMPH_ON="\033[1;33m"
EMPH_SUCCESS="\033[1;32m"
EMPH_FAILED="\033[1;31m"
EMPH_OFF="\033[0m"

#
# ---------------------------------------------------------------------------------------- functions ---
#

function ensure_existence_of_support_files() {
    local -r EXITCODE="${1:-1}"
    
    if ! [ -x "${GET_SHM_LIMIT_FILE}" ]
    then
	echo "${PROGNAME}: Required executable \"${GET_SHM_LIMIT_FILE}\" is missing or not executable" >& 2
	exit ${EXITCODE}
    fi
    
    if ! [ -r "${SMALL_TEXT_FILE}" ]
    then       
	echo "${PROGNAME}: Required file ${SMALL_TEXT_FILE} is missing or not readable" >& 2
	exit ${EXITCODE}
    fi

    if ! [ -r "${SMALL_BINARY_FILE}" ]
    then       
	echo "${PROGNAME}: Required file ${SMALL_BINARY_FILE} is missing" >& 2
	exit ${EXITCODE}
    fi

    if ! [ -r "${HUGE_BINARY_FILE}" ]
    then       
	echo "${PROGNAME}: Required file ${HUGE_BINARY_FILE} is missing" >& 2
	exit ${EXITCODE}
    fi
}

function show_usage() {
    local -r EXITCODE="${1:-1}"
    echo "usage: ${PROGNAME} [-s <sender executable>] [-e <empfaenger executable>] [-t <delay time>] [-f] [-c (auto|always|never)] [<num1>] [<num2>] ..." >& 2
    echo "       <num<x>> must be a number from ${TESTS}" >& 2
    echo "       --help,-h: this help" >& 2
    echo "       --sender,-s: the binary of the producer" >& 2
    echo "       --empfaenger,-e: the binary of the consumer" >& 2
    echo "       --time,-t: delay time for longer running tests" >& 2
    echo "       --force,-f: do not stop on failed tests (unless shared memory or semaphores are left over)" >& 2
    echo "       --color,-c: auto-detect, force or prevent coloring" >& 2
    echo "       --quiet,-q: do not show successful test results" >& 2
    exit "${EXITCODE}"
}

function clean_up() {
    local -r EXITCODE="${1}"
    rm -f "${SHM_KEYS_BEFORE_FILE}" "${SEM_KEYS_BEFORE_FILE}" "${SHM_KEYS_AFTER_FILE}" "${SEM_KEYS_AFTER_FILE}" \
        "${SMALL_BINARY_FILE_RESULT}" "${SMALL_TEXT_FILE_RESULT}" "${HUGE_BINARY_FILE_RESULT}"
    exit $EXITCODE
}

function test_failed() {
    echo -e "${PROGNAME}: ${EMPH_FAILED}Test failed:${EMPH_OFF} $1"
    if [ "${IGNORE_FAILED_TESTS}" = "0" ]
    then
        exit 1
    fi
}

function test_passed() {
    if [ "$QUIET" == 0 ]
        then
        echo -e "${PROGNAME}: ${EMPH_SUCCESS}Test successful:${EMPH_OFF} $1"
    fi
}

function record_resources_after() {
    SEM_KEYS_AFTER=`find /dev/shm -user "${MYUID}"   -path "/dev/shm/sem.*" -print | sort -u`
    SHM_KEYS_AFTER=`find /dev/shm -user "${MYUID}" ! -path "/dev/shm/sem.*" -print | sort -u`
}

function record_resources_before() {
    SEM_KEYS_BEFORE=`find /dev/shm -user "${MYUID}"   -path "/dev/shm/sem.*" -print | sort -u`
    SHM_KEYS_BEFORE=`find /dev/shm -user "${MYUID}" ! -path "/dev/shm/sem.*" -print | sort -u`
}

function check_resources() {
    local RV=0
    # create new/truncate files
    for i in ${SHM_KEYS_BEFORE}; do echo $i; done > "${SHM_KEYS_BEFORE_FILE}"
    for i in ${SHM_KEYS_AFTER};  do echo $i; done > "${SHM_KEYS_AFTER_FILE}"
    for i in ${SEM_KEYS_BEFORE}; do echo $i; done > "${SEM_KEYS_BEFORE_FILE}"
    for i in ${SEM_KEYS_AFTER};  do echo $i; done > "${SEM_KEYS_AFTER_FILE}"

    local -r STALE_SHM_KEYS=`diff "${SHM_KEYS_BEFORE_FILE}" "${SHM_KEYS_AFTER_FILE}" | grep \> | cut -d' ' -f2`
    local -r STALE_SEM_KEYS=`diff "${SEM_KEYS_BEFORE_FILE}" "${SEM_KEYS_AFTER_FILE}" | grep \> | cut -d' ' -f2`

    if [ -z "${STALE_SHM_KEYS}" ]
    then
	test_passed "Shared memory segments have been cleaned up properly"
    else
	echo -e "${PROGNAME}: ${EMPH_FAILED}Test failed:${EMPH_OFF} Shared memory segments with the following keys have not been cleaned up"
	echo "${STALE_SHM_KEYS}"
	exit 1
    fi

    if  [ -z "${STALE_SEM_KEYS}" ]
    then
	test_passed "Semaphores have been cleaned up properly"
    else
	echo -e "${PROGNAME}: ${EMPH_FAILED}Test failed:${EMPH_OFF} Semaphores with the following keys have not been cleaned up"
	echo "${STALE_SEM_KEYS}"
	exit 1
    fi

    rm -f "${SHM_KEYS_BEFORE_FILE}" "${SHM_KEYS_AFTER_FILE}" "${SEM_KEYS_BEFORE_FILE}" "${SEM_KEYS_AFTER_FILE}"
    return $RV
}

function check_exit_status_ok() {
    local RV=0
    set +e # dont want to terminate on non-zero exit status of wait
    wait "$1"
    local -r EXIT_STATUS="$?"
    set -e # terminate upon failed commands again

    if [ "${EXIT_STATUS}" -ne 0 ]
    then
	test_failed "Process $2 with PID $1 terminated with exit status ${EXIT_STATUS} instead of 0"
        RV=1
    else
	test_passed "Process $2 with PID $1 terminated with exit status ${EXIT_STATUS}"
    fi
    return $RV
}


function check_process_dead() {
    local RV=0
    if ps -o "pid" -p "$1" --no-headers | grep -q "$1"
    then
	test_failed "Process $2 with PID $1 is still alive"
        RV=1
    else
	test_passed "Process $2 with PID $1 terminated correctly"
    fi
    return $RV
}

function check_process_alive() {
    local RV=0
    if ps -o "pid" -p "$1" --no-headers | grep -q "$1"
    then
	test_passed "Process $2 with PID $1 is still alive"
    else
	test_failed "Process $2 with PID $1 terminated" 
        RV=1
    fi
    return $RV
}

function check_files_equal() {
    local RV=0
    if diff -q "$1" "$2" > /dev/null
    then
	test_passed "Inputfile \"$1\" and outputfile \"$2\" are identical"
    else
	echo -e "${PROGNAME}: ${EMPH_FAILED}Test failed:${EMPH_OFF} Inputfile \"$1\" and outputfile \"$2\" differ"
	# we actually exited here always on the "failing" diff .....
	set +e # don't want to terminate on the output of `diff`
	diff "$1" "$2"
	set -e # terminate upon failed commands again
	if [ "${IGNORE_FAILED_TESTS}" = "0" ]
        then
	    exit 1
	fi
        RV=1
    fi
    return $RV
}

#
# Test 0: Test command line parameters - unknown options
#
function test_0() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 0: Test command line parameters - unknown options ----${EMPH_OFF}"
    if "${SENDER}" -x > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with unknown options"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with unknown options"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with unknown options (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi

    if "${EMPFAENGER}" -y > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with unknown options"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with unknown options"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with unknown options (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    return $RV
}

#
# Test 1: Test command line parameters - no options
#
function test_1() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 1: Test command line parameters - no options -----${EMPH_OFF}"
    if "${SENDER}" > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} without options"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} without options"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} without options (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi

    if "${EMPFAENGER}" > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} without options"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} without options"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} without options (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    return $RV
}

#
# Test 2: Test command line parameters - additional parameters
#
function test_2() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 2: Test command line parameters - additional parameters -----${EMPH_OFF}"
    if "${SENDER}" -m 10 foobar > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with additional parameters"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with additional parameters"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with additional parameters (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    if "${SENDER}" -m10 foobar > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with additional parameters"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with additional parameters"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with additional parameters (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi

    if "${EMPFAENGER}" -m 10 foobar > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with additional parameters"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with additional parameters"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with additonal parameters (see ${STDERRFILENAME}) for output on stderr)"
	    RV=1
	fi
    fi
    if "${EMPFAENGER}" -m10 foobar > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with additional parameters"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with additional parameters"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with additional parameters (see ${STDERRFILENAME}) for output on stderr)"
	    RV=1
	fi
    fi
    return $RV
}

#
# Test 3: Test command line parameters - negative ring buffer size
#
function test_3() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 3: Test command line parameters - negative ring buffer size ----${EMPH_OFF}"
    if "${SENDER}" -m -1 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with a negative ring buffer size"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with a negative ring buffer size"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with a negative ring buffer size (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    if "${SENDER}" -m-1 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with a negative ring buffer size"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with a negative ring buffer size"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with a negative ring buffer size (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi

    if "${EMPFAENGER}" -m -1 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with a negative ring buffer size"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with a negative ring buffer size"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with a negative ring buffer size (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    if "${EMPFAENGER}" -m-1 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with a negative ring buffer size"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with a negative ring buffer size"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with a negative ring buffer size (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    return $RV
}

#
# Test 4: Test command line parameters - zero as ring buffer size
#
function test_4() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 4: Test command line parameters - zero as ring buffer size ----${EMPH_OFF}"
    if "${SENDER}" -m 0 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with zero as ring buffer size "
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with zero as ring buffer size"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with zero as ring buffer size (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    if "${SENDER}" -m0 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with zero as ring buffer size"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with zero as ring buffer size"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with zero as ring buffer size (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi

    if "${EMPFAENGER}" -m 0 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with zero as ring buffer size"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with zero as ring buffer size"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with zero as ring buffer size (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    if "${EMPFAENGER}" -m0 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with zero as ring buffer size"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with zero as ring buffer size"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with zero as ring buffer size (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    return $RV
}

#
# Test 5: Test command line parameters - invalid number
#
function test_5() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 5: Test command line parameters - invalid number ----${EMPH_OFF}"
    if "${SENDER}" -m 10foobar > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with an invalid number"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with an invalid number"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with an invalid number (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    if "${SENDER}" -m10foobar > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with an invalid number"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with an invalid number"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with an invalid number (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi

    if "${EMPFAENGER}" -m 10foobar > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with an invalid number"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with an invalid number"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with an invalid number (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    if "${EMPFAENGER}" -m10foobar > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with an invalid number"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with an invalid number"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with an invalid number (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    return $RV
}

#
# Test 6: Test command line parameters - huge number (provoking ERANGE error with strtoll)
#
function test_6() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 6: Test command line parameters - huge number (violating the range of long long) ----${EMPH_OFF}"
    if "${SENDER}" -m1234567890123456789012345678901234567890 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with a huge number"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with a huge number"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with a huge number (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi

    if "${EMPFAENGER}" -m1234567890123456789012345678901234567890 > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with a huge number"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with a huge number"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with a huge number (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    return $RV
}

#
# Test 7: Test command line parameters - large number (provoking buffer * sizeof(int) to exceed the maximum
# possible size for the shared memory)
#
function test_7() {
    local RV=0
    local MAXELEMENTS=$(( `${GET_SHM_LIMIT_FILE}` + 1 ))
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 7: Test command line parameters - large number (${MAXELEMENTS} - exceeding maximum possible size for the shared memory) ----${EMPH_OFF}"
    if "${SENDER}" -m ${MAXELEMENTS} > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${SENDER} with large number (${MAXELEMENTS}) exceeding maximum possible size for the shared memory"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${SENDER} with a large number (${MAXELEMENTS}) exceeding maximum possible size for the shared memory"
	else
	    test_failed "No usage message printed to stderr when calling ${SENDER} with a large number (${MAXELEMENTS}) exceeding maximum possible size for the shared memory (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi

    if "${EMPFAENGER}" -m ${MAXELEMENTS} > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_failed "No exit code indicating failure when calling ${EMPFAENGER} with a large number (${MAXELEMENTS}) exceeding maximum possible size for the shared memory"
        RV=1
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
            test_passed "Exit code indicating failure and proper usage message printed to stderr when calling ${EMPFAENGER} with a large number (${MAXELEMENTS}) exceeding maximum possible size for the shared memory"
	else
	    test_failed "No usage message printed to stderr when calling ${EMPFAENGER} with a large number (${MAXELEMENTS}) exceeding maximum possible size for the shared memory (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	fi
    fi
    return $RV
}


#
# Test 8: Test command line parameters - large number (but buffer * sizeof(int) not exceeding the maximum
# possible size for the shared memory)
#
function test_8() {
    local RV=0
    local MAXELEMENTS=`${GET_SHM_LIMIT_FILE}`
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 8: large number (${MAXELEMENTS} - not exceeding maximum possible size for the shared memory) -----${EMPH_OFF}"
    if "${SENDER}" -m${MAXELEMENTS} > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_passed "No exit code indicating failure when calling ${SENDER} with (${MAXELEMENTS}) not exceeding maximum possible size for the shared memory"
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
	    test_failed "Usage message printed to stderr when calling ${SENDER} with a large number (${MAXELEMENTS}) not exceeding maximum possible size for the shared memory (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	else
            test_failed "Exit code indicating failure but no usage message printed to stderr when calling ${SENDER} with a large number (${MAXELEMENTS}) not exceeding maximum possible size for the shared memory"
            RV=1
	fi
    fi

    if "${EMPFAENGER}" -m${MAXELEMENTS} > /dev/null 2> "${STDERRFILENAME}" < /dev/null
    then
        test_passed "No exit code indicating failure when calling ${EMPFAENGER} with (${MAXELEMENTS}) not exceeding maximum possible size for the shared memory"
    else
	if egrep -q "${USAGEMSGREGEX}" "${STDERRFILENAME}"
	then
	    test_failed "Usage message printed to stderr when calling ${EMPFAENGER} with a large number (${MAXELEMENTS}) not exceeding maximum possible size for the shared memory (see ${STDERRFILENAME} for output on stderr)"
	    RV=1
	else
            test_failed "Exit code indicating failure but no usage message printed to stderr when calling ${EMPFAENGER} with a large number (${MAXELEMENTS}) not exceeding maximum possible size for the shared memory"
            RV=1
	fi
    fi
    return $RV
}

#
# Test 9: Simple transfer of small text file
#
function test_9() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 9: Simple transfer of small text file -----${EMPH_OFF}"
    record_resources_before
    "${SENDER}" -m 10 < "${SMALL_TEXT_FILE}" &
    local -r PID_SENDER="$!"
    "${EMPFAENGER}" -m 10 > "${SMALL_TEXT_FILE_RESULT}" &
    local -r PID_EMPFAENGER="$!"
    sleep 5
    record_resources_after
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${SMALL_TEXT_FILE}" "${SMALL_TEXT_FILE_RESULT}"
    then
	echo "check_files_equal() returned 1"
        RV=1
    fi
    return $RV
}

#
# Test 10: Transfer of small text file - big buffer => sender should
# terminate immediately
#
function test_10() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 10: Transfer of small text file - big buffer -----${EMPH_OFF}"
    record_resources_before
    "${SENDER}" -m 1000 < "${SMALL_TEXT_FILE}" &
    local -r PID_SENDER="$!"
    sleep 5
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    "${EMPFAENGER}" -m 1000 > "${SMALL_TEXT_FILE_RESULT}" &
    local -r PID_EMPFAENGER="$!"
    sleep 5
    record_resources_after
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${SMALL_TEXT_FILE}" "${SMALL_TEXT_FILE_RESULT}"
    then
        RV=1
    fi
    return $RV
}

#
# Test 11: Simple transfer of small text file - -m10 (should not yield an error if getopt() is used properly)
#
function test_11() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 11: Simple transfer of small text file - -m10 -----${EMPH_OFF}"
    record_resources_before
    "${SENDER}" -m10 < "${SMALL_TEXT_FILE}" &
    local -r PID_SENDER=$!
    "${EMPFAENGER}" -m10 > "${SMALL_TEXT_FILE_RESULT}" &
    local -r PID_EMPFAENGER=$!
    sleep 5
    record_resources_after
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${SMALL_TEXT_FILE}" "${SMALL_TEXT_FILE_RESULT}"
    then
        RV=1
    fi
    return $RV
}

#
# Test 12: Simple transfer of small text file - -m   10  (should not yield an error if getopt() is used properly)
#
function test_12() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 12: Simple transfer of small text file - -m   10 -----${EMPH_OFF}"
    record_resources_before
    "${SENDER}" -m   10 < "${SMALL_TEXT_FILE}" &
    local -r PID_SENDER=$!
    "${EMPFAENGER}" -m   10 > "${SMALL_TEXT_FILE_RESULT}" &
    local -r PID_EMPFAENGER=$!
    sleep 5
    record_resources_after
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${SMALL_TEXT_FILE}" "${SMALL_TEXT_FILE_RESULT}"
    then
        RV=1
    fi
    return $RV
}

#
# Test 13: Transfer of small text file - start empfanger first => should block
# 
function test_13() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 13: Transfer of small text file - reverse start order -----${EMPH_OFF}"
    record_resources_before
    "${EMPFAENGER}" -m 1000 > "${SMALL_TEXT_FILE_RESULT}" &
    local -r PID_EMPFAENGER=$!
    sleep 2
    if ps -o "pid" -p "${PID_EMPFAENGER}" --no-headers | grep -q "${PID_EMPFAENGER}"
    then
        test_passed "Process ${EMPFAENGER} with PID ${PID_EMPFAENGER} is waiting for process ${SENDER}"
    else
        test_failed "Process ${EMPFAENGER} with PID ${PID_EMPFAENGER} is no longer alive"
        RV=1
    fi
    "${SENDER}" -m 1000 < "${SMALL_TEXT_FILE}" &
    local -r PID_SENDER=$!
    sleep 5
    record_resources_after
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${SMALL_TEXT_FILE}" "${SMALL_TEXT_FILE_RESULT}"
    then
        RV=1
    fi
    return $RV
}

#
# Test 14: Transfer of small binary file containing char 255
# 
function test_14() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 14: Transfer of small binary file containing char 255 -----${EMPH_OFF}"
    record_resources_before
    "${SENDER}" -m 10 < "${SMALL_BINARY_FILE}" &
    local -r PID_SENDER="$!"
    "${EMPFAENGER}" -m 10 > "${SMALL_BINARY_FILE_RESULT}" &
    local -r PID_EMPFAENGER="$!"
    sleep 5
    record_resources_after
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${SMALL_BINARY_FILE}" "${SMALL_BINARY_FILE_RESULT}"
    then
        RV=1
    fi
    return $RV
}

#
# Test 15: Test proper handling of EINTR
# 
function test_15() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 15: Test proper handling of EINTR -----${EMPH_OFF}"
    record_resources_before
    "${SENDER}" -m 10 < "${SMALL_BINARY_FILE}" &
    local -r PID_SENDER="$!"
    sleep 2
    kill -STOP "${PID_SENDER}" # send SIGSTOP while sender is blocking in P() operation
    sleep 1
    check_process_alive "${PID_SENDER}" "${SENDER}"
    kill -CONT "${PID_SENDER}" # continue sender => should simply restart P()
    sleep 1
    check_process_alive "${PID_SENDER}" "${SENDER}"
    kill -STOP "${PID_SENDER}" # send SIGSTOP again while sender is blocking in P() operation (we do this so the client does no terminate prematurely)
    "${EMPFAENGER}" -m 10 > "${SMALL_BINARY_FILE_RESULT}" &
    local -r PID_EMPFAENGER="$!"
    sleep 2
    kill -STOP "${PID_EMPFAENGER}" # send SIGSTOP while empfaenger is blocking in P() operation
    sleep 1
    check_process_alive "${PID_EMPFAENGER}" "${EMPFAENGER}"
    kill -CONT "${PID_EMPFAENGER}" # continue empfaenger => should simply restart P()
    sleep 1
    check_process_alive "${PID_EMPFAENGER}" "${EMPFAENGER}"
    kill -CONT "${PID_SENDER}" # continue sender => should simply restart P()
    sleep 5
    record_resources_after
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${SMALL_BINARY_FILE}" "${SMALL_BINARY_FILE_RESULT}"
    then
        RV=1
    fi
    return $RV
}

#
# Test 16: Transfer of huge binary file
# 
function test_16() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 16: Transfer of huge binary file -----${EMPH_OFF}"
    record_resources_before
    "${EMPFAENGER}" -m 10000 > "${HUGE_BINARY_FILE_RESULT}" &
    local -r PID_EMPFAENGER="$!"
    "${SENDER}" -m 10000 < "${HUGE_BINARY_FILE}" &
    local -r PID_SENDER="$!"
    if [ "${DELAYTIME}" = "0" ]
    then
        wait "${PID_EMPFAENGER}"
    else
        sleep "${DELAYTIME}"
    fi
    record_resources_after
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${HUGE_BINARY_FILE}" "${HUGE_BINARY_FILE_RESULT}"
    then
        RV=1
    fi
    return $RV
}

#
# Test 17: Transfer of huge binary file - stop and continue processes in between
# 
function test_17() {
    local RV=0
    echo -e "${PROGNAME}: ${EMPH_ON}----- Test 17: Transfer of huge binary file - stop and continue processes in between -----${EMPH_OFF}"
    record_resources_before
    "${EMPFAENGER}" -m 10000 > "${HUGE_BINARY_FILE_RESULT}" &
    local -r PID_EMPFAENGER="$!"
    kill -STOP "${PID_EMPFAENGER}" # stop empfaenger for some time to trigger races
    "${SENDER}" -m 10000 < "${HUGE_BINARY_FILE}" &
    local -r PID_SENDER="$!"
    kill -CONT "${PID_EMPFAENGER}" # continue empfaenger
    kill -STOP "${PID_SENDER}" # stop sender for some time
    sleep 1
    kill -CONT "${PID_SENDER}"
    kill -STOP "${PID_EMPFAENGER}" # stop empfänger for some time
    sleep 1
    kill -CONT "${PID_EMPFAENGER}"
    kill -STOP "${PID_SENDER}" # stop sender for some time
    sleep 1
    kill -CONT "${PID_SENDER}"
    if [ "${DELAYTIME}" = "0" ]
    then
        wait "${PID_EMPFAENGER}"
    else
        sleep "${DELAYTIME}"
    fi
    record_resources_after
    if ! check_process_dead "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_process_dead "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_SENDER}" "${SENDER}"
    then
        RV=1
    fi
    if ! check_exit_status_ok "${PID_EMPFAENGER}" "${EMPFAENGER}"
    then
        RV=1
    fi
    if ! check_resources
    then
        RV=1
    fi
    if ! check_files_equal "${HUGE_BINARY_FILE}" "${HUGE_BINARY_FILE_RESULT}"
    then
        RV=1
    fi
    return $RV
}

#
# ------------------------------------------------------------------------------------- process args ---
#
readonly SHORT_OPTS="hqs:e:t:fc:"
readonly LONG_OPTS="help,quiet,sender:,empfaenger:,time:,force,color:"
# print nothing and just check for errors terminating the script 
if ! getopt --quiet-output -o "$SHORT_OPTS" --longoptions "$LONG_OPTS" -- "$@"; then
    show_usage 1
fi

set -- $(getopt -u -o "$SHORT_OPTS" --longoptions "$LONG_OPTS" -- "$@")

COLOR=auto
while [ "$#" -gt 0 ]; do
#    echo "$1"
    case "$1" in
	-h|--help)
        show_usage 0
        ;;
	-s|--sender)
        SENDER="$2"
        shift 2
        ;;
	-e|--empfaenger)
        EMPFAENGER="$2"
        shift 2
        ;;
	-t|--time)
        DELAYTIME="$2"
        shift 2
        ;;
	-f|--force)
        IGNORE_FAILED_TESTS=1
        shift
        ;;
	-c|--color)
        COLOR="$2"
#	    echo "$2"
        shift 2
        ;;
	-q|--quiet)
        QUIET=1
        shift
        ;;
	--)
        shift
        break
        ;;
	:)
        echo "${PROGNAME}: Option -$2 requires an argument." >&2
        show_usage 1
        ;;
	*)
        echo "${PROGNAME}: Invalid option: -$2" >&2
        show_usage 1
        ;;
    esac
done
readonly SENDER EMPFAENGER DELAYTIME IGNORE_FAILED_TESTS QUIET

ensure_existence_of_support_files

if [ -x "${SENDER}" ]
then
    if [[ ${SENDER} == *"/"* ]]
    then
	echo "${PROGNAME}: Using sender binary ${SENDER}"
    else
	echo "${PROGNAME}: Sender binary ${SENDER} is not in executable search path" >&2
	show_usage 1
    fi
else
    echo "${PROGNAME}: Cannot find sender binary ${SENDER}" >&2
    show_usage 1
fi

if [ -x "${EMPFAENGER}" ]
then
    if [[ ${EMPFAENGER} == *"/"* ]]
    then
	echo "${PROGNAME}: Using empfaenger binary ${EMPFAENGER}"
    else
	echo "${PROGNAME}: Empfaenger binary ${EMPFAENGER} is not in executable search path" >&2
	show_usage 1
    fi
else
    echo "${PROGNAME}: Cannot find empfaenger binary ${EMPFAENGER}" >&2
    show_usage 1
fi

if [ "${DELAYTIME}" = "0" ]
then
    echo "${PROGNAME}: Waiting infinitely till ${EMPFAENGER} has terminated for the tests 16 and 17"
else
    echo "${PROGNAME}: Using a delay time of ${DELAYTIME} seconds for the tests 16 and 17"
fi

if [ "${IGNORE_FAILED_TESTS}" = "0" ]
then
    echo "${PROGNAME}: Stopping on failed tests"
else
    echo "${PROGNAME}: Continuing after failed tests. Please note that we stop nevertheless if ressources are left"
    echo "${PROGNAME//*/ }  over as the following test won't work most likely anyways"
fi

echo "${PROGNAME}: Placing temporary files in ${MYTMPDIR}"

echo "${PROGNAME}: Using coloring ${COLOR}"

case "$COLOR" in
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
    show_usage 1
    ;;
esac

readonly EMPH_ON EMPH_SUCCESS EMPH_FAILED EMPH_OFF

#
# ----------------------------------------------------------------------------- install trap handler ---


trap "{ echo ${PROGNAME}: Terminated by signal - cleaning up ...; clean_up 1; }" SIGINT SIGTERM

#
# -------------------------------------------------------------------------------------------- Tests ---
#

RV=0
if [ "$#" -eq "0" ]
then
    for i in ${TESTS}
    do
        if ! "test_${i}"
        then
            RV=1
        fi
    done
else
    for i
    do
        if ! [[ "${TESTS}" =~ " ${i} " ]]
        then
            show_usage 1
        fi
    done
    for i
    do
        if ! "test_${i}"
        then
            RV=1
        fi
    done
fi

if [ $RV -eq 0 ]
then
    echo -e "${PROGNAME}: ${EMPH_SUCCESS}ALL TESTS SUCCESSFUL! :-)${EMPH_OFF}"
else
    echo -e "${PROGNAME}: ${EMPH_FAILED}THERE IS SOMETHING TO IMPROVE! :-(${EMPH_OFF}"
fi
