#!/bin/bash --norc
#
# Bernd Petrovitsch <bernd.petrovitsch@technikum-wien.at>
#
# Macht eine Directoryhierarchie um `find` zu testen
#


set -ue	# error out if we use uninitialized variables and on failed command
#set -vx # for debugging

#echo "Please customize the variables in the script!"; exit 0
#and comment then the previous line out!

if [ "$(id -u)" -ne 0 ]; then
    echo "You must be root run this script!"
    exit 1
fi

# customizing
readonly TOPDIR="/usr/local/etc/test-find" # where to install that
readonly NUM_USERNAME="160"
readonly NUM_UID="150"
readonly NUM_OTHERUSERNAME="karl"
readonly NOT_USED_UID="999999"
readonly NOT_USED_GID="999999"
readonly LONG_USERNAME="d836154a1ba14015bff78dad09f7dd82b41cd39c2a1347598215ad0622e87d03d2cc91334a4e4d8e9a5b4f35a8650d2cf5a6711d86de4b1bb227eb8ccb58bcf9197878c566d84050ae7f1aca5c6b97ab"
readonly SPECIAL_USERNAME="x%sx%px%n"

make_long_link() {
    local -r topdir="${1}"
# test with a long sym-link
    local LONG="$(uuidgen)"
    while ln -sf "${LONG}" "${topdir}/long-link" 2> /dev/null; do
#    for i in {1..112}; do
        LONG="${LONG}$(uuidgen)"       
    done
}

make_deep_directory() {
# und ein tiefes langes directory
    (
        set -e
        local topdir="$1"
        local name="$2"
        local pathname="${topdir}/${name}"
        local i=0
        while [ $i -lt 900 ] && [ "${#pathname}" -lt $(( 4095 - "${#name}" )) ]; do
            pathname="${pathname}/${name}"
        i=$(( $i + 1 ))
        done
        mkdir -p "${pathname}"
    ) || : # ignore errors
}

make_very_deep_directory() {
    local -r topdir="${1}"
# und ein tiefes langes directory
    (
        local uuid
        set -e
        local name="$1"
        local pathname="$name"
        for i in {1..2048}; do
            pathname="$pathname/$name"
            mkdir "${name}"
            cd "${name}" 2> /dev/null
        done
    ) || : # ignore errors
}


# make sure the necessary users and groups according to create-accounts.pl exist!
make_funny_files() {
    local -r topdir="${1}"
    : noch ein File, das fuer den Parametercheck genutzt wird > "${topdir}/so"
    : usercheck > "${topdir}/${NUM_OTHERUSERNAME}"
    chown "${NUM_OTHERUSERNAME}:${NUM_OTHERUSERNAME}" "${topdir}/${NUM_OTHERUSERNAME}" # und ein existenter user+gruppe ....

    # create a (text) file
    echo "Hello world" > "${topdir}/plain-file"
    echo "Hello world" > "${topdir}/.hidden-file"
    
# files with glob chars (and other ugly ones)
    : > "${topdir}/*"
    : > "${topdir}/?"
    : > "${topdir}/["
    : > "${topdir}/]"
    : > "${topdir}/file\\with\\escape\\character"
# files with names like the options
    for file in "-type" "-name" "-path" "-ls" "-print" "-user" "-group" "-nouser" "-nogroup"; do
        : > "${topdir}/$file"
    done
    chown "${NOT_USED_UID}" "${topdir}/-nouser" # und ein nicht existenter user ....
    chgrp "${NOT_USED_GID}" "${topdir}/-nogroup" # und eine nicht existente grupp ....

# files with names looking like format strings, especially pointer-like ones
    for ch in d u p s x; do
        : > "${topdir}/%$ch"
        : > "${topdir}/%*$ch"
        : > "${topdir}/%.*$ch"
        : > "${topdir}/%*.*$ch"
    done
    : > "${topdir}/%n"

    # create directories
    mkdir "${topdir}/empty" "${topdir}/not-empty" "${topdir}/.empty-hidden" "${topdir}/.not-empty-hidden"
    # and some contents
    echo "Hello world again" > "${topdir}/not-empty/another-plain-file"
    echo "Hello world again" > "${topdir}/not-empty/.another-hidden-file"
    echo "Hello world again" > "${topdir}/.not-empty-hidden/another-plain-file"
    echo "Hello world again" > "${topdir}/.not-empty-hidden/.another-hidden-file"
    chown "${LONG_USERNAME}:${LONG_USERNAME}" "${topdir}/not-empty/another-plain-file" "${topdir}/.not-empty-hidden/another-plain-file"
    chown "${SPECIAL_USERNAME}:${SPECIAL_USERNAME}" "${topdir}/not-empty/.another-hidden-file" "${topdir}/.not-empty-hidden/.another-hidden-file"

    # create a file (containing only zeroes) with holes in it (a.k.a. sparse file)
    dd of="${topdir}/not-empty/file-without-holes" if="/dev/zero" bs=1024 count=10
    cp --sparse=always "${topdir}/not-empty/file-without-holes" "${topdir}/not-empty/file-with-holes"
# create a file with a size that is not an integral multiple of 1024
    dd of="${topdir}/not-empty/file-with-size-not-divisible-by-1024" if="/dev/zero" bs=512 count=13

# create hard-link
    ln "${topdir}/plain-file" "${topdir}/linked-plain-file"
    ln "${topdir}/plain-file" "${topdir}/not-empty/linked-plain-file"
# create sym-links
    ln -s "this-should-not-exist" "${topdir}/dangling-sym-link"
    ln -s "plain-file" "${topdir}/working-sym-link"
# and a long chain of sym-links
    for i in {2..22}; do
        ln -s "sym-link-$((${i} - 1))" "${topdir}/sym-link-${i}"
    done
    ln -s "plain-file" "${topdir}/sym-link-1"

# block, char device and a fifo
    mkfifo "${topdir}/named-pipe"
    chmod u=s,go= "${topdir}/named-pipe"
    mknod "${topdir}/block-device" "b" 99 99
    chmod u=,g=s,o= "${topdir}/block-device"
    mknod "${topdir}/char-device"  "c" 98 98
    chmod ug=,o=t "${topdir}/char-device"
    mksock "${topdir}/socket"
    chmod u=t,go= "${topdir}/socket"

    make_long_link "${topdir}"
    make_deep_directory "${topdir}" "$(uuidgen)"
    make_deep_directory "${topdir}" " "
}

mksock() {
    local -r name="${1}"
    perl -e "use IO::Socket::UNIX; IO::Socket::UNIX->new(Type => SOCK_STREAM(), Local => '${name}', Listen => 1);"
}

umask 000

umount "${TOPDIR}/xfs" || :
# get device name for detatching
USED_LOOP_DEVICE=`losetup -j "${TOPDIR}/xfs-data"`
USED_LOOP_DEVICE="${USED_LOOP_DEVICE%%:*}"
if [ -n "${USED_LOOP_DEVICE}" ]
then
    losetup -d "${USED_LOOP_DEVICE}" || :
fi

rm -rf "${TOPDIR}"
mkdir -p "${TOPDIR}/simple" "${TOPDIR}/xfs"
#mkdir -p "${TOPDIR}/full"

# fixup the permissions
chmod -R go-w "${TOPDIR}"
chown "$(id -u):$(id -g)" "${TOPDIR}" "${TOPDIR}/simple" "${TOPDIR}/xfs"
#chown "$(id -u):$(id -g)" "${TOPDIR}/full"

###################
# generate a few simple test cases
#
make_funny_files "${TOPDIR}/simple"
make_long_link "${TOPDIR}/simple"
#make_very_deep_directory "${TOPDIR}/simple" "$(uuidgen)"

###################
# generate a few simple test cases into an xfs filesystem
# (with ftype explicitly set to 0) to trigger d_type of
# struct dirent to be DT_UNKNOWN and thus cause all implementations
# to fail that do not use the st_mode member of the struct stat.
#
set -vx
dd if=/dev/zero of="${TOPDIR}/xfs-data" count=1 bs=$((16 * 1024 * 1024))
chmod -R go-w "${TOPDIR}/xfs-data"
# use first free loop device
losetup -f "${TOPDIR}/xfs-data"
mkfs.xfs -f -n ftype=0 -m crc=0 "${TOPDIR}/xfs-data"
mount ${TOPDIR}/xfs
make_funny_files "${TOPDIR}/xfs"
make_long_link "${TOPDIR}/xfs"



###################
# build a quite large set of files and the like with lots of combinations
#

if false; then
make_funny_files "${TOPDIR}/full"
make_long_link "${TOPDIR}/full"
#make_very_deep_directory "${TOPDIR}/full" "$(uuidgen)"


declare -a filetypes=(b c d f l p s)
for dir in "${TOPDIR}/full"; do
    i=0
# and a few files for the various types and permissions
    for perms in u={r,w,x,s,xs},go= u=,g={r,w,x,s,xs},o= ug=,o={r,w,x,t,xt}; do
        case $(($i % 6)) in
            0) mknod "${dir}/block-device-${perms}" b 47 11
               chmod "${perms}" "${dir}/block-device-${perms}"
               ;;
            1) mknod "${dir}/char-device-${perms}" c 08 15
               chmod "${perms}" "${dir}/char-device-${perms}"
               ;;
            2) mkdir "${dir}/directory-${perms}"
               chmod "${perms}" "${dir}/directory-${perms}"
               ;;
            3) mkfifo "${dir}/fifo-${perms}"
               chmod "${perms}" "${dir}/fifo-${perms}"
               ;;
            4) : > "${dir}/plain-file-${perms}"
               chmod "${perms}" "${dir}/plain-file-${perms}"
               ln -sf "plain-file-${perms}" "${dir}/sym-link-${perms}"
               chmod "${perms}" "${dir}/sym-link-${perms}"
               ;;
            5) mksock "${dir}/socket-${perms}"
               chmod "${perms}" "${dir}/socket-${perms}"
               ;;
        esac
        i=$(( $i + 1 ))
    done

# play permission games
    for perms in u={r,-}{w,-}{x,-}{s,},g={r,-}{w,-}{x,-}{s,},o={r,-}{w,-}{x,-}{t,}; do
        mknod "${dir}/block-device-${perms}" b 47 11
        mknod "${dir}/char-device-${perms}" c 08 15
        mkdir "${dir}/directory-${perms}"
        mkfifo "${dir}/fifo-${perms}"
        : > "${dir}/plain-file-${perms}"	# save fork(2)+exec(2) avoiding "touch"
        ln -sf "plain-file-${perms}" "${dir}/sym-link-${perms}"
        mksock "${dir}/socket-${perms}"
        chmod "${perms//-}" "${dir}/block-device-${perms}" "${dir}/char-device-${perms}" "${dir}/directory-${perms}" "${dir}/fifo-${perms}" "${dir}/plain-file-${perms}" "${dir}/sym-link-${perms}" "${dir}/socket-${perms}"
    done

# now create some more files
    : > "${dir}/test-${NUM_USERNAME}"	# save fork(2)+exec(2) avoiding "touch"
    : > "${dir}/test-${NUM_OTHERUSERNAME}"	# save fork(2)+exec(2) avoiding "touch"
    chown "${NUM_USERNAME}:${NUM_UID}" "${dir}/test-${NUM_USERNAME}"
    chown "${NUM_OTHERUSERNAME}:${NUM_UID}" "${dir}/test-${NUM_OTHERUSERNAME}"
done
fi

exit 0

# Local Variables:
# sh-basic-offset: 4
# End:
