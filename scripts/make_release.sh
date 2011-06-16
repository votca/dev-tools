#! /bin/bash -e

burl="https://votca.googlecode.com/hg/"
stable=stable

die () {
  echo -e "$*"
  exit 1
}

[[ $1 = "--test" ]] && stable="default" && shift

[[ -z $2 ]] && die "${0##*/}: missing argument.\nUsage ${0##*/} [--test] rel_version buildir"

[[ -d $2 ]] || die "Argument is not a dir"
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
[[ -z ${rel//[1-9].[0-9]?(_rc[1-9]?([0-9]))} ]] || die "release has the wrong form (X.X_rcX)"

set -e
instdir="$instdir"
[[ -d $instdir ]] && die "$instdir is already there, run 'rm -rf $PWD/$instdir'"
#order matters for deps
#and pristine before non-pristine to 'overwrite less components by more components'
for p in tools_pristine tools csg manual; do
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
	  :
	#autotools to be removed soon
	elif [[ -f configure.ac ]]; then
	  sed -i "/AC_INIT/s/,[^,]*,\(bugs@votca.org\)/,$rel,\1/" configure.ac || die "sed of configure.ac failed"
	  #|| true because maybe version has not changed
	  hg commit -m "Version bumped to $rel" configure.ac || true
	else
	  sed -i "/set(PROJECT_VERSION/s/\"[^\"]*\"/\"$rel\"/" CMakeLists.txt || die "sed of CMakeLists.txt failed"
	  #|| true because maybe version has not changed
	  hg commit -m "Version bumped to $rel" CMakeLists.txt || true
	fi
	cd ..
	if [[ $p = "manual" ]]; then
	  ./buildutil/build.sh --no-wait --prefix $PWD/$instdir --clean-ignored $prog || die
	  cp manual/manual.pdf votca-manual-$rel.pdf || die
	else
	  ./buildutil/build.sh --no-wait --prefix $PWD/$instdir --$dist --clean-ignored $prog || die
	fi
	#we tag the release when the non-pristine version was build
	[[ $stable = "stable" && -n ${p%%*_pristine} ]] && hg -R $prog tag -f "release_$rel"
done	
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
  for p in tools csg buildutil manual; do
  	echo hg push -R $p
  done
  echo "uploads tarball" *$rel* *.pdf
else
  echo cd $PWD
  echo "Take a look at" *$rel* *.pdf
fi
