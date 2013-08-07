#! /bin/bash -e

#TODO
#- allow $what to be more flexible


burl="https:/code.google.com/p/votca/"
branch=stable
testing=no

die () {
  echo -e "$*"
  exit 1
}

unset CSGSHARE VOTCASHARE

[[ $1 = "--test" ]] && branch="$2" && testing=yes && shift 2

[[ -z $2 ]] && die "${0##*/}: missing argument.\nUsage ${0##*/} [--test branch] rel_version builddir"

[[ -d $2 ]] || mkdir -p "$2"
cd "$2"

if [[ -d buildutil ]]; then
  cd buildutil
  hg pull "$burl"
  [[ -z "$(hg status -mu)" ]] || die "There are modified or unknown files in buildutil"
  hg update
  cd ..
else
  hg clone $burl buildutil
fi

rel="$1"
shopt -s extglob
[[ $testing = "no" && ${rel} != [1-9].[0-9]?(.[1-9]|_rc[1-9])?(_pristine) ]] && die "release has the wrong form"

set -e
instdir="instdir"
build="build"
#build manual before csgapps to avoid csgapps in the manual
what="tools csg csg-manual csgapps csg-tutorials"
[[ -d $instdir ]] && die "Test install dir '$instdir' is already there, run 'rm -rf $PWD/$instdir'"
[[ -d $build ]] && die "$build is already there, run 'rm -rf $PWD/$build'"
#order matters for deps
#and pristine before non-pristine to 'overwrite less components by more components'
for p in tools_pristine $what; do
  [[ -z ${p%%*_pristine} ]] && dist="dist-pristine" || dist="dist"
  prog="${p%_pristine}"
  ./buildutil/build.sh \
    --no-branchcheck --no-wait --just-update --prefix $PWD/$instdir $prog || \
    die "build -U failed" #clone and checkout
  cd $prog
  [[ -z "$(hg status -mu)" ]] || die "There are modified or unknown files in $p"
  hg checkout $branch || die "Could not checkout $branch"
  [[ -z "$(hg status -mu)" ]] || die "There are modified or unknown files in $p"
  if [[ $testing = "yes" ]]; then
    :
  elif [[ $p = *manual ]]; then
    sed -i "s/^VER=.*$/VER=$rel/" Makefile || die "sed of Makefile failed"
  elif [[ -f CMakeLists.txt ]]; then
    sed -i "/set(PROJECT_VERSION/s/\"[^\"]*\"/\"$rel\"/" CMakeLists.txt || die "sed of CMakeLists.txt failed"
  fi
  if [[ $testing = "no" ]]; then
    #remove old tags
    if [[ -f .hgtags ]]; then
      sed -i "/release_${rel}$/d" .hgtags
    fi
    #|| true because maybe version has not changed
    hg commit -m "Version bumped to $rel" || true
  fi
  cd ..

  if [[ $testing = "yes" ]]; then
    REL="$rel" ./buildutil/build.sh \
      --no-branchcheck --no-changelogcheck \
      --no-wait --prefix $PWD/$instdir \
      --$dist --clean-ignored \
      $prog || die
  else
    REL="$rel" ./buildutil/build.sh \
      --no-wait --prefix $PWD/$instdir \
      --$dist --clean-ignored \
      $prog || die
    #tag the release when the non-pristine version was build
    [[ -n ${p%%*_pristine} ]] && hg -R $prog tag "release_$rel"
  fi
done
rm -rf $instdir
mkdir $instdir
[ -d $build ] && die "$build is already there, run 'rm -rf $PWD/$build'"
mkdir $build
cd $build

echo "Starting build check from tarball"

r=""
for i in ../votca-tools-$rel*_pristine.tar.gz; do
  [[ -f $i ]] || die "Could not find $i"
  [[ -n $r ]] && die "There are two file matching votca-tools-$rel*_pristine.tar.gz"
  cp $i .
  [[ $i =~ ../votca-tools-(.*_pristine).tar.gz ]] && r="${BASH_REMATCH[1]}"
done
[[ -z $r ]] && die "Could not fetch rel"
../buildutil/build.sh \
  --no-wait --prefix $PWD/../$instdir --no-relcheck --release $r \
  -DEXTERNAL_BOOST=ON --selfdownload tools
rm -rf *

for p in $what; do
  [[ $p = *pristine ]] && die "Edit ${0##*/} as there are multiple pristine tarballs"
  [[ $p = *manual ]] && continue
  r=""
  for i in ../votca-$p-$rel*.tar.gz; do
    [[ $i = *_pristine* ]] && continue
    [[ -f $i ]] || die "Could not find $i"
    [[ -n $r ]] && die "There are two non-pristine file matching votca-$p-$rel*.tar.gz"
    cp $i .
    [[ $i =~ ../votca-$p-(.*).tar.gz ]] && r="${BASH_REMATCH[1]}"
  done
  [[ -z $r ]] && die "Could not fetch rel"
  ../buildutil/build.sh \
    --no-wait --prefix $PWD/../$instdir --no-relcheck --release $r \
    -DEXTERNAL_BOOST=OFF --selfdownload $p
  rm -rf *
done
cd ..
rm -rf $build
rm -rf $instdir

if [[ $testing = "no" ]]; then
  echo "####### TODO by you #########"
  echo cd $PWD
  echo "for p in $what buildutil; do hg out -p -R \$p; done"
  echo "for p in $what buildutil; do hg push -R \$p; done"
  echo "uploads tarball" *$rel*
else
  echo cd $PWD
  echo "Take a look at" *$rel*
fi
