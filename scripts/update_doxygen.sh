#! /bin/bash -e

# Make a crontab like this
#
# SHELL=/bin/bash
# PATH=/people/thnfs/homes/junghans/bin:/usr/bin:/usr/sbin:/sbin:/bin
# #min  hour  day  month  dow  user  command
# */30  *     *    *      *    . $HOME/.bashrc; $HOME/votca/src/admin/scripts/update_doxygen.sh $HOME/votca/src/doxygen >~/.votca_devdoc 2>&1

url="git@github.com:votca/doxygen.git"
burl="git://github.com/votca/buildutil.git"
msg="Documentation update"

[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || true

die () {
  echo -e "$*"
  exit 1
}

[ -z "$1" ] && die "${0##*/}: missing argument add the path where to build the docu"

[ -d "$1" ] || die "Argument is not a dir"
cd "$1"

if [ -d buildutil ]; then
  cd buildutil
  git pull --ff-only "$burl" master
  cd ..
else
  git clone $burl buildutil 
fi

[ -d devdoc ] || git clone --depth 1 --single-branch -b gh-pages $url devdoc

cd devdoc
git checkout gh-pages
git config user.name "Doxygen builder"
git config user.email "devs@votca.org"
git pull --ff-only "$url" gh-pages || die "git pull failed"
rm -f * #sometimes files disappear
cd ..

./buildutil/build.sh --no-wait --dev --just-update --devdoc tools csg ctp moo kmc || die "build of docu failed"

cd devdoc
git add --all
git commit -m "$msg" && git push $url gh-pages:gh-pages

