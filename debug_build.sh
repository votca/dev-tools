#! /bin/bash

usage="Usage: ${0##*/} [OPTIONS] path/to/artifacts.zip"
dockertag="latest"

die () {
  echo -e "$*"
  exit 1
}

show_help() {
  cat << eof
This script will start an environment to debug CI builds
$usage
OPTIONS:
    --help          Show this help
-t, --tag TAG       Specify the docker tag of votca/buildenv to use
                    Default: $dockertag

Examples:  ${0##*/} ./artifacts.zip
           ${0##*/} --tag ubuntu ./storage/old_build.zip

Report bugs and comments at https://github.com/votca/dev-tools/issues
eof
}

shopt -s extglob
while [[ $# -gt 0 ]]; do
  if [[ ${1} = --*=* ]]; then # case --xx=yy
    set -- "${1%%=*}" "${1#*=}" "${@:2}" # --xx=yy to --xx yy
  elif [[ ${1} = -[^-]?* ]]; then # case -xy split
    if [[ ${1} = -[t]* ]]; then #short opts with arguments
       set -- "${1:0:2}" "${1:2}" "${@:2}" # -xy to -x y
    else #short opts without arguments
       set -- "${1:0:2}" "-${1:2}" "${@:2}" # -xy to -x -y
    fi
 fi
 case $1 in
   -t|--tag)
     dockertag="$2"
     shift 2;;
   --help)
     show_help
     exit $?;;
   -*)
     die "Unknown options $1";;
   --)
     break;;
   *)
     break;;
 esac
done

for prog in unzip docker mktemp; do
  [[ -n $(type -p $prog) ]] || die "Could not find program '$prog'"
done


[[ -z $1 || -z $2 ]] && die "Missing argument - need module and artifact.zip!\nTry ${0##*/} --help"
module="$1"
zip="$2"
[[ -f $zip ]] || die "Cannot read '$zip'"
[[ $zip != /* ]] && zip="$PWD/$zip"
[[ $module = @(tools|csg|csg-manual|csg-tutorials|csgapps|ctp|xtp) ]] || die "Unknown module"

set -e
tmpdir=$(mktemp -d /tmp/votca_debug.XXXXXX)
cd ${tmpdir}
unzip -d votca "$zip"
docker pull votca/buildenv:${dockertag}
cat > Dockerfile <<EOF
FROM votca/buildenv:${dockertag}
WORKDIR /builds/votca/${module}/votca/build
EOF
docker build -t votca_debug .
docker run -it -v ${tmpdir}/votca:/builds/votca/${module} votca_debug /bin/bash
