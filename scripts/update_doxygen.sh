#! /bin/bash -e

url=https://doxygen.votca.googlecode.com/hg/
sim=75
author="Doxygen builder <devs@votca.org>"
msg="Documentation update"

die () {
  echo -e "$*"
  exit 1
}



cd $HOME/votca/src
[ -x build ] || die "build not found"
[ -d devdoc ] || hg clone $url devdoc

cd devdoc
hg pull || die "hg pull failed"
hg update || die "hg up failed"
rm -f *
cd ..

./build -U --devdoc tools csg || die "build of docu failed"

cd devdoc
hg addremove -s $sim
hg commit -u "$author" -m "$msg" && hg push $url

