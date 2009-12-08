#!/bin/bash

usage="Usage: ${0##*/} [options] [progs]"
#mind the spaces
all=" tools csg moo kmc tof"
standard=" tools csg "
build="build"
exten=".tar.gz"
clean="no"
extra_opts=""

die () {
  echo "$*" >&2
  exit 1
}

show_help () {
  cat << eof
This is scripts, make and tests release of certain votca modules
Give multiple programs to build them. Nothing means:$standard
One can build:$all

The normal sequence of a build is:
- ./build -g --no-build prog
- make dist
  (stop here with --notest)
- cp tarball to a tmpdir (change with --tmpdir)
- unpack tarball
- ./build -g --prefix tmpdir prog
- rm tmpdir

$usage
OPTIONS:
-h, --help              Show this help
-t, --tmpdir DIR        Change tmp build dir
                        Default: \$(mktemp -d votca_XXX)
-b, --build NAME        Change the name of the build script
                        Defauilt: $build
    --exten XXX         Change tarball extension
                        Default: $exten
    --clean             Clean tmpdir at the end
    --ccache            Enable ccache


Examples:  ${0##*/} tools csg

eof
}

# parse arguments

while [ "${1#-}" != "$1" ]; do
 if [ "${1#--}" = "$1" ] && [ -n "${1:2}" ]; then
    #short opt with arguments here: tb
    if [ "${1#-[tb]}" != "${1}" ]; then
       set -- "${1:0:2}" "${1:2}" "${@:2}"
    else
       set -- "${1:0:2}" "-${1:2}" "${@:2}"
    fi
 fi
 case $1 in
   -h | --help)
    show_help
    exit 0;;
   -t | --tmpdir)
    tmpdir="$2"
    shift 2;;
   -b | --build)
    build="$2"
    shift 2;;
  --exten)
    exten="$2"
    shift 2;;
  --clean)
    clean="yes"
    shift 1;;
  --ccache)
    extra_opts="--ccache"
    shift 1;;
  *)
   die "Unknown option '$1'"
   exit 1;;
 esac
done

if [ -z "${tmpdir}" ]; then
  tmpdir="$(mktemp -d $PWD/votca_XXX)" || die "${0##*/}: mktemp failed"
else
  [ -d "$tmpdir" ] && die "${0##*/}: tmpdir is already there"
fi
echo tmpdir is $tmpdir
[ -z "$1" ] && set -- $standard
[ -x "$build" ] || die "${0##*/}: build script is wrong"
cp $build $tmpdir/build

set -e
for prog in "$@"; do
  oldpwd="$PWD"
  ./$build -g --prefix $tmpdir --no-build ${extra_opts} $prog
  cd $prog
  make dist
  tarball="$(ls *${exten})" || die "No tarball found"
  echo tarball is $tarball
  cp $tarball $tmpdir
  mv $tarball ..
  cd $tmpdir
  tar -xzf $tarball
  mv ${tarball%${exten}} $prog
  ./build -g --no-clean --prefix $tmpdir ${extra_opts} $prog
 cd $oldpwd 
done

if [ "$clean" = "yes" ]; then
  echo Removing $tmpdir
  rm -rf $tmpdir
fi
set +e

