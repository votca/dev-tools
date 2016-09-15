#! /bin/bash -e

#TODO
#- allow $what to be more flexible


burl="git@github.com:votca/buildutil.git"
durl="git@github.com:votca/downloads.git"
branch=stable
testing=no
clean=no
#build manual before csgapps to avoid csgapps in the manual
what="tools csg csg-manual csgapps csg-tutorials xtp"
cmake_opts=()
usage="Usage: ${0##*/} [OPTIONS] rel_version builddir"

die () {
  echo -e "$*"
  exit 1
}

unset CSGSHARE VOTCASHARE

show_help() {
  cat << eof
This is the script to make release tarballs for VOTCA
$usage
OPTIONS:
    --help          Show this help
    --test BRANCH   Build test release from branch BRANCH (use with current rel ver)
    --clean         Clean tmp dirs  (SUPER DANGEROUS)
    --repos REL     Use repos instead of '$what'
-D*                 Extra option to give to cmake 

Examples:  ${0##*/} -q
           ${0##*/} --test stable 1.2.3 builddir

Report bugs and comments at https://github.com/votca/admin/issues
eof
}

shopt -s extglob
while [[ $# -gt 0 ]]; do
  if [[ ${1} = --*=* ]]; then # case --xx=yy
    set -- "${1%%=*}" "${1#*=}" "${@:2}" # --xx=yy to --xx yy
  elif [[ ${1} = -[^-]?* ]]; then # case -xy split
    if [[ ${1} = -[jpD]* ]]; then #short opts with arguments
       set -- "${1:0:2}" "${1:2}" "${@:2}" # -xy to -x y
    else #short opts without arguments
       set -- "${1:0:2}" "-${1:2}" "${@:2}" # -xy to -x -y
    fi
 fi
 case $1 in
   --clean)
     clean=yes
     shift;;
   --repos)
     what="$2"
     shift 2;;
   --test)
     branch="$2"
     testing=yes
     shift 2;;
   -D)
    cmake_opts+=( -D"${2}" )
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

[[ -z $2 ]] && die "${0##*/}: missing argument - no builddir!\nTry ${0##*/} --help"

[[ -d $2 ]] || mkdir -p "$2"
cd "$2"
builddir="${PWD}"

if [[ -d buildutil ]]; then
  cd buildutil
  git pull --ff-only "$burl" master
  [[ -z "$(git ls-files -mo --exclude-standard)" ]] || die "There are modified or unknown files in buildutil"
  cd ..
else
  git clone --depth 1 $burl buildutil
fi

rel="$1"
shopt -s extglob
[[ $testing = "no" && ${rel} != [1-9].[0-9]?(.[1-9]|_rc[1-9]) ]] && die "release has the wrong form"

set -e
instdir="instdir"
build="build"
if [[ -d $instdir ]]; then
  [[ $clean = yes ]] || die "Test install dir '$instdir' is already there, run 'rm -rf $PWD/$instdir' or add --clean"
  rm -vrf $PWD/$instdir
fi
if [[ -d $build ]]; then
  [[ $clean = yes ]] || die "$build is already there, run 'rm -rf $PWD/$build' or add --clean"
  rm -vrf $PWD/$build
fi

cleanup() {
  [[ $testing = "no" ]] || return
  cd ${builddir}
  for p in $what; do
    git -C ${p} reset --hard origin/${branch} || true
    git -C ${p} tag --delete "v${rel}" || true
  done
}
trap cleanup EXIT
#order matters for deps
for p in $what; do
  [[ -d ${p} ]] || git clone "git://github.com/votca/${p}.git"
  git -C ${p} pull --ff-only
  cd $p
  [[ -z "$(git ls-files -mo --exclude-standard)" ]] || die "There are modified or unknown files in $p"
  git checkout $branch || die "Could not checkout $branch"
  [[ -z "$(git ls-files -mo --exclude-standard)" ]] || die "There are modified or unknown files in $p"
  if [[ $testing = "yes" ]]; then
    :
  elif [[ $p = *manual ]]; then
    sed -i "s/^VER=.*$/VER=$rel/" Makefile || die "sed of Makefile failed"
    git add Makefile
  elif [[ -f CMakeLists.txt ]]; then
    sed -i "/set(PROJECT_VERSION/s/\"[^\"]*\"/\"$rel\"/" CMakeLists.txt || die "sed of CMakeLists.txt failed"
    git add CMakeLists.txt
  fi
  if [[ $testing = "no" ]]; then
    [[ -f CHANGELOG.md && -z $(grep "^## Version ${rel} " CHANGELOG.md) ]] && \
          die "Go and update CHANGELOG.md in ${p} before making a release"
    git remote set-url --push origin "git@github.com:votca/${p}.git"
    #|| true because maybe version has not changed
    git commit -m "Version bumped to $rel" || true
    git tag "v${rel}"
  fi
  git archive --prefix "votca-${p}-${rel}/" -o "../votca-${p}-${rel}.tar.gz" HEAD || die "git archive failed"
  cd ..
done
rm -rf $instdir
mkdir $instdir
[ -d $build ] && die "$build is already there, run 'rm -rf $PWD/$build'"
mkdir $build
cd $build

echo "Starting build check from tarball"

for p in $what; do
  cp ../votca-$p-${rel}.tar.gz .
  ../buildutil/build.sh --build-manual \
    --no-wait --prefix $PWD/../$instdir --no-relcheck --release "$rel" \
    --no-progcheck --warn-to-errors --selfdownload "${cmake_opts[@]}" $p
  [[ -d $p/.git ]] && die ".git dir found in $p"
  [[ -f $p/Makefile ]] || die "$p has no Makefile"
  [[ $p != *manual ]] || cp ${p}/manual.pdf ../votca-$p-${rel}.pdf 
  [[ -f ${p}/manual/${p}-manual.pdf ]] && cp ${p}/manual/${p}-manual.pdf ../votca-$p-manual-${rel}.pdf
  rm -rf *
done
cd ..
rm -rf $build
rm -rf $instdir

if [[ $testing = "no" ]]; then
  echo "####### TODO by you #########"
  echo cd $PWD
  echo "for p in $what; do git -C \$p log -p origin/${branch}..${branch}; done"
  echo "for p in $what; do git -C \$p  push --tags origin ${branch}:${branch}; done"
else
  echo cd $PWD
  echo "Take a look at" *$rel*
fi
