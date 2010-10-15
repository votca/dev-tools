#! /bin/bash

#version 0.1   14.12.09 -- initial commit
#version 0.1.1 14.12.09 -- works with subfolders
#version 0.1.2 14.12.09 -- username should have real @
#version 0.1.3 18.12.09 -- add scp to csgth
#version 0.1.4 14.10.10 -- removed csgth stuff

usage="Usage: ${0##*/} file1 file2 ..."
googlebot="no"
gc_user="googlebot@votca.org"
gc_passwd="VB8kF5Sv9Dk4"
gc_upload="./googlecode_upload.py"
gc_opts="-l Featured,OpSys-Linux"
gc_project="votca"
echo="echo"

die () {
  echo -e "$*" >&2
  exit 1
}

show_help () {
  cat << eof
  Uploaded files to googlecode
$usage
OPTIONS:
-r, --really        Really do everything
    --googlebot     Use our googlebot to upload
-h, --help          Show this help
-v, --version       Show version
    --hg            Show last log message for hg (or cvs)

Examples:  ${0##*/} -q
           ${0##*/}

Send bugs and comment to junghans@mpip-mainz.mpg.de
eof
}

while [ "${1#-}" != "$1" ]; do
 if [ "${1#--}" = "$1" ] && [ -n "${1:2}" ]; then
    #short opt with arguments here: fc
    if [ "${1#-[fc]}" != "${1}" ]; then
       set -- "${1:0:2}" "${1:2}" "${@:2}"
    else
       set -- "${1:0:2}" "-${1:2}" "${@:2}"
    fi
 fi
 case $1 in 
   -r | --really)
    echo=""
    shift ;;
   --googlebot)
    googlebot="yes"
    shift ;;
   -h | --help)
    show_help
    exit 0;;
   --hg)
    echo "${0##*/}: $(sed -ne 's/^#version.* -- \(.*$\)/\1/p' $0 | sed -n '$p')"
    exit 0;;
   -v | --version)
    echo "${0##*/}, $(sed -ne 's/^#\(version.*\) -- .*$/\1/p' $0 | sed -n '$p') by C. Junghans"
    exit 0;;
  *)
   die "Unknown option '$1'";;
 esac
done

[ -z "$1" ] && die "Missing argument"
shopt -s extglob
for tarball in "$@"; do
  [ -f "$tarball" ] || die "Could not find $tarball"
  name="${tarball##*/}"
  [[ $name =~ ^votca-.*.tar.gz$ ]] || die "$name does not match '^votca-.*.tar.gz\$'"
  if [[ $name =~ ^votca-(.*)-(.*).tar.gz$ ]]; then
    [ -z "${BASH_REMATCH[1]}" ] && die "Could not fetch package name"
    [ -z "${BASH_REMATCH[2]}" ] && die "Could not fetch package version"
    summary="Votca ${BASH_REMATCH[1]} - Version ${BASH_REMATCH[2]}"
  elif [[ $name =~ ^votca-(.*).tar.gz$ ]]; then
    [ -z "${BASH_REMATCH[1]}" ] && die "Could not fetch package name"
    summary="Votca ${BASH_REMATCH[1]}"
  else
    die "$name has a strange pattern"
  fi
  [ -f "$gc_upload" ] || die "Could not find $gc_upload"
  [ "$googlebot" = "yes" ] && gc_opts="-u $gc_user -w $gc_passwd $gc_opts"
  $echo $gc_upload $gc_opts -s "$summary" -p "$gc_project" "$tarball" \
     || die " $gc_upload failed"
done
