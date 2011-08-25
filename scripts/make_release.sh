#! /bin/bash -e

#TODO
#- allow $what to be more flexible


burl="https://votca.googlecode.com/hg/"
stable=stable

die () {
  echo -e "$*"
  exit 1
}

unset CSGSHARE VOTCASHARE

[[ $1 = "--test" ]] && stable="default" && shift

[[ -z $2 ]] && die "${0##*/}: missing argument.\nUsage ${0##*/} [--test] rel_version builddir"

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
[[ $stable = "stable" && ${rel} != [1-9].[0-9]?(.[1-9]|_rc[1-9])?(_pristine) ]] && die "release has the wrong form"

set -e
instdir="instdir"
build="build"
what="tools csg csgapps manual tutorials"
[[ -d $instdir ]] && die "Test install dir '$instdir' is already there, run 'rm -rf $PWD/$instdir'"
#order matters for deps
#and pristine before non-pristine to 'overwrite less components by more components'
for p in tools_pristine $what; do
	[[ -z ${p%%*_pristine} ]] && dist="dist-pristine" || dist="dist"
	prog="${p%_pristine}"
	./buildutil/build.sh --no-wait --just-update $prog || die "build -U failed" #clone and checkout
	cd $prog
	[[ -z "$(hg status -mu)" ]] || die "There are modified or unknown files in $p"
	hg checkout $stable || die "Could not checkout $stable"
	[[ -z "$(hg status -mu)" ]] || die "There are modified or unknown files in $p"
	if [[ $stable != "stable" ]]; then
          :
	elif [[ $p = "manual" ]]; then
	  sed -i "s/^VER=.*$/VER=$rel/" Makefile || die "sed of Makefile failed"
	elif [[ -f CMakeLists.txt ]]; then
	  sed -i "/set(PROJECT_VERSION/s/\"[^\"]*\"/\"$rel\"/" CMakeLists.txt || die "sed of CMakeLists.txt failed"
	fi
	if [[ $stable = "stable" ]]; then
	  #remove old tags
	  if [[ -f .hgtags ]]; then
	    sed -i "/release_${rel}$/d" .hgtags
	  fi
	  #|| true because maybe version has not changed
	  hg commit -m "Version bumped to $rel" || true
	fi
	cd ..
	REL="$rel" ./buildutil/build.sh --no-wait --prefix $PWD/$instdir --$dist --clean-ignored $prog || die
	#we tag the release when the non-pristine version was build
	[[ $stable = "stable" && -n ${p%%*_pristine} ]] && hg -R $prog tag "release_$rel"
done	
rm -rf $instdir
mkdir $instdir
[ -d $build ] && die "$build is already there, run 'rm -rf $PWD/$build'"
mkdir $build
cd $build
for p in tools_pristine $what; do
  prog="${p%_pristine}"
  [[ $prog = "manual" ]] && continue
  [[ -z ${p%%*_pristine} ]] && r="${rel}_pristine" || r="$rel"
  [[ -z ${p%%*_pristine} ]] && opts="-DEXTERNAL_BOOST=ON" || opts="-DEXTERNAL_BOOST=OFF"
  cp ../votca-$prog-$r.tar.gz . 
  ../buildutil/build.sh --no-wait --prefix $PWD/../$instdir --release $r $opts --selfdownload $prog
  rm -rf *
done
cd ..
rm -rf $build
rm -rf $instdir

cd buildutil
if [[ $stable = "stable" ]]; then
  sed -i "s/^\(latest\)=\".*\"$/\1=\"$rel\"/" build.sh || die "sed of build.sh failed"
  ver="$(./build.sh --version)"
  ver="${ver##*version }"
  oldver="#version $ver"
  last="${ver:0-1:1}"
  [ -z "${last//[0-9]}" ] || die "Could grep minor version build - got $last"
  ((last++))
  ver=${ver:0:${#ver}-1}
  ver="#version $ver$last -- $(date +%d.%m.%g) bumped latest to $rel"
  sed -i "/^$oldver/a $ver" build.sh
  #|| true because maybe version has not changed
  hg commit -m "$(./build.sh --hg)" build.sh || true
fi
cd ..

if [[ $stable = "stable" ]]; then
  echo "####### TODO by you #########"
  echo cd $PWD
  echo "for p in $what; do hg out -p -R \$p; done"
  echo "for p in $what; do hg push -R \$p; done"
  echo "uploads tarball" *$rel* *.pdf
else
  echo cd $PWD
  echo "Take a look at" *$rel* *.pdf
fi
