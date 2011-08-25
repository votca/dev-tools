#! /bin/bash

#version 0.1   14.12.09 -- initial commit
#version 0.1.1 14.12.09 -- works with subfolders
#version 0.1.2 14.12.09 -- username should have real @
#version 0.1.3 18.12.09 -- add scp to csgth
#version 0.1.4 14.10.10 -- removed csgth stuff
#version 0.1.5 31.10.10 -- removed googlebot stuff

usage="Usage: ${0##*/} file1 file2 ..."
gc_upload="./googlecode_upload.pl"
gc_project="votca"
doit="no"
opts='--labels="Featured,OpSys-Linux"'
rel=""

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
    --relname NAME  Release name
    --user NAME     Googlecode username
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
    doit="yes"
    shift ;;
   --user)
    user="$2"
    shift 2;;
   --relname)
    rel="$2"
    shift 2;;
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

[[ -f $gc_upload ]] || die "Could not find $gc_upload"
[[ -z $user ]] && die "Please specify a user for the upload (--user option)"
opts="--user=\"$user\" $opts"
[[ -z $1 ]] && die "Missing argument"
if [[ -z $GOOGLECODE_PASS ]]; then
  [[ $doit = "no" ]] && echo "No password in GOOGLECODE_PASS variable found, so I will ask you if --really was specified."
  if [[ $doit = "yes" ]]; then
    echo "Please type in the password for user $user (or let $gc_upload ask you several times)"
    read -r pass || die "Read of password failed"
    [[ -n $pass ]] && opts="--pass=\"$pass\" $opts"
  fi
fi
shopt -s extglob
for tarball in "$@"; do
  [ -f "$tarball" ] || die "Could not find $tarball"
  name="${tarball##*/}"
  if [[ $name =~ ^votca-(.*)-(.*).(tar.gz|pdf)$ ]]; then
    [ -z "${BASH_REMATCH[1]}" ] && die "Could not fetch package name"
    [ -z "${BASH_REMATCH[2]}" ] && die "Could not fetch package version"
    if [[ ${BASH_REMATCH[2]} = *_pristine ]]; then
     ver="${BASH_REMATCH[2]%%_pristine}"
     extra=" without bundled libs"
    else
      ver="${BASH_REMATCH[2]}"
      extra=""
    fi
    [[ -n $rel ]] && extra=" ($rel)${extra}"
    summary="Votca ${BASH_REMATCH[1]} - Version ${ver}${extra}"
  else
    die "$name has a strange pattern"
  fi
  if [[ $doit = "yes" ]]; then
    $gc_upload $opts --summary="$summary" --project="$gc_project" --file="$tarball" || \
     die " $gc_upload failed"
  else
    echo "$gc_upload --summary='$summary' --project='$gc_project' --file='$tarball'"
   fi
done
