#! /bin/bash -e

#TODO
#- allow $what to be more flexible


burl="git@github.com:votca/votca.git"
branch=stable
testing=no
clean=no
#build manual before csgapps to avoid csgapps in the manual
what="tools csg csg-manual csgapps csg-tutorials ctp xtp"
cmake_opts=()
usage="Usage: ${0##*/} [OPTIONS] rel_version builddir"

die () {
  echo -e "$*"
  exit 1
}

unset CSGSHARE VOTCASHARE

j="$(grep -c processor /proc/cpuinfo 2>/dev/null)" || j=0
((j++))

is_part() { #checks if 1st argument is part of the set given by other arguments
  [[ -z $1 || -z $2 ]] && die "${FUNCNAME[0]}: Missing argument"
  [[ " ${@:2} " = *" $1 "* ]]
}
export -f is_part

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

if [[ -d votca ]]; then
  cd votca
  git pull --ff-only "$burl" master
  #[[ -z "$(git ls-files -mo --exclude-standard)" ]] || die "There are modified or unknown files in votca"
  cd ..
else
  git clone --depth 1 $burl votca
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
  echo "####### ERROR ABOVE #########"
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
  git -C ${p} remote update --prune
  git -C ${p} pull --ff-only
  cd $p
  [[ -z "$(git ls-files -mo --exclude-standard)" ]] || die "There are modified or unknown files in $p"
  git checkout $branch || die "Could not checkout $branch"
  [[ -z "$(git ls-files -mo --exclude-standard)" ]] || die "There are modified or unknown files in $p"
  if [[ $testing = "yes" ]]; then
    :
  elif [[ -f CMakeLists.txt ]]; then
    sed -i "/set(PROJECT_VERSION/s/\"[^\"]*\"/\"$rel\"/" CMakeLists.txt || die "sed of CMakeLists.txt failed"
    git add CMakeLists.txt
    if [[ -f CHANGELOG.md ]]; then
      sed -i "/^## Version ${rel} /s/released ..\...\.../released $(date +%d.%m.%y)/" CHANGELOG.md
      git add CHANGELOG.md
    fi
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

cmake -DCMAKE_INSTALL_PREFIX=$PWD/../$instdir -DMODULE_BUILD=ON \
      -DVOTCA_TARBALL_DIR=${PWD}/.. -DVOTCA_TARBALL_TAG="${rel}" \
      -DENABLE_TESTING=OFF -DVOTCA_TEST_OPTS="-E (_imc|spce_cma_simple)" \
      $(is_part csg-manual ${what} && echo -DBUILD_CSG_MANUAL=ON) \
      $(is_part csgapps ${what} && echo -DBUILD_CSGAPPS=ON) \
      $(is_part ctp ${what} && echo -DBUILD_CTP=ON -DBUILD_CTP_MANUAL=ON ) \
      $(is_part xtp ${what} && echo -DBUILD_XTP=ON -DBUILD_XTP_MANUAL=ON ) \
      ${cmake_opts[@]} ../votca
make -j${j}
cp $PWD/../$instdir/share/doc/*/manual*.pdf ..
cd ..
rm -rf $build
rm -rf $instdir
trap - EXIT

if [[ $testing = "no" ]]; then
  echo "####### TODO by you #########"
  echo cd $PWD
  echo "for p in $what; do git -C \$p log -p origin/${branch}..${branch}; done"
  echo "for p in $what; do git -C \$p  push --tags origin ${branch}:${branch}; done"
else
  echo cd $PWD
  echo "Take a look at" *$rel*
fi
