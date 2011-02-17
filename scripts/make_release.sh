#! /bin/bash -e

burl="https://votca.googlecode.com/hg/"

die () {
  echo -e "$*"
  exit 1
}

[ -z "$2" ] && die "${0##*/}: missing argument.\nUsage ${0##*/} rel_version buildir"

[ -d "$2" ] || die "Argument is not a dir"
cd "$2"

if [ -d buildutil ]; then
  cd buildutil
  hg pull $burl
  [ -z "$(hg status -mu)" ] || die "There are modified or unknown files in buildutil"
  hg update
  cd ..
else
  hg clone $burl buildutil 
fi

rel="$1"
shopt -s extglob
[ -z "${rel//[1-9].[0-9]?(_rc[1-9]?([0-9]))}" ] || die "release has the wrong form (X.X_rcX)"

set -e
[ -d "builddir" ] && die "builddir is already there, run 'rm -rf $PWD/builddir'"
mkdir builddir
#order matters for deps
#and pristine before not pristine to overwrite less files by more files
for p in tools_pristine tools csg; do
	[ -z "${p%%*_pristine}" ] && dist="dist-pristine" || dist="dist"
	prog="${p%_pristine}"
	./buildutil/build.sh --no-wait --just-update $prog || die "build -U failed" #clone and checkout
	cd $prog
	[ -z "$(hg status -mu)" ] || die "There are modified or unknown files in $p"
	hg checkout stable || die "Could not checkout stable"
	[ -z "$(hg status -mu)" ] || die "There are modified or unknown files in $p"
	sed -i "/AC_INIT/s/,[^,]*,\(bugs@votca.org\)/,$rel,\1/" configure.ac || die "sed of configure.ac failed"
	#maybe version has not changed
	hg commit -m "Version bumped to $rel" configure.ac || true
	cd ..
	./buildutil/build.sh --no-wait --no-rpath --prefix $PWD/build --$dist --clean-ignored $prog || die
	hg -R $prog tag -f "release_$rel"
done	
rm -rf builddir
cd buildutil
sed -i "s/^\(latest\)=\".*\"$/\1=\"$rel\"/" build.sh || die "sed of build.sh failed"
hg commit -m "bumped latest to $rel" build.sh || true

echo "####### TODO by you #########"
echo cd $PWD
for p in tools csg buildutil; do
	echo hg push -R $p
done
echo "upload_tarball" *$rel*

