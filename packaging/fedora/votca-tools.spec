Name:		votca-tools
Version:	1.0.1
Release:	1%{?dist}
Summary:	VOTCA tools library
Group:		Applications/Engineering
License:	ASL 2.0
URL:		http://www.votca.org
Source0:	http://votca.googlecode.com/files/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildRequires:	expat-devel
BuildRequires:	fftw-devel
BuildRequires:	gsl-devel
BuildRequires:	boost-devel

%description
Versatile Object-oriented Toolkit for Coarse-graining Applications (VOTCA) is
a package intended to reduce the amount of routine work when doing systematic
coarse-graining of various systems. The core is written in C++.

This package contains the basic tools library of VOTCA package.

%package devel
Summary:	Development headers and libraries for votca-tools
Group:		Development/Libraries
Requires:	%{name} = %{version}-%{release}

%description devel
Versatile Object-oriented Toolkit for Coarse-graining Applications (VOTCA) is
a package intended to reduce the amount of routine work when doing systematic
coarse-graining of various systems. The core is written in C++.

This package contains development headers and libraries for votca-tools.

%prep
%setup -q
# Get rid of bundled versions of boost and expat
rm -rf src/libboost
rm -rf src/libexpat

%build
%configure --disable-static --disable-la-files --disable-rc-files
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

%clean
rm -rf %{buildroot}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(-,root,root,-)
%doc CHANGELOG LICENSE NOTICE
%{_libdir}/libvotca_tools.so.*

%files devel
%defattr(-,root,root,-)
%{_includedir}/votca/
%{_libdir}/libvotca_tools.so
%{_libdir}/pkgconfig/libvotca_tools.pc

%changelog
* Thu Nov 25 2010 Jussi Lehtola <jussilehtola@fedoraproject.org> - 1.0-1
- First release.
* Thu Nov 30 2010 Christoph Junghans <junghans@votca.org> - 1.0.1-1
- Minor cleanup.
