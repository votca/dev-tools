Name:		votca-csg
Version:	1.0.1
Release:	1%{?dist}
Summary:	VOTCA coarse-graining engine
Group:		Applications/Engineering
License:	ASL 2.0
URL:		http://www.votca.org
Source0:	http://votca.googlecode.com/files/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildRequires:	gromacs-devel
BuildRequires:	votca-tools-devel
Requires:	%{name}-common = %{version}-%{release}
Requires:	%{name}-libs = %{version}-%{release}

%description
Versatile Object-oriented Toolkit for Coarse-graining Applications (VOTCA) is
a package intended to reduce the amount of routine work when doing systematic
coarse-graining of various systems. The core is written in C++.

This package contains the Coarse Graining Engine of VOTCA package.

%package libs
Summary:	Libraries for VOTCA coarse graining engine
Group:		System Environment/Libraries

%description libs
Versatile Object-oriented Toolkit for Coarse-graining Applications (VOTCA) is
a package intended to reduce the amount of routine work when doing systematic
coarse-graining of various systems. The core is written in C++.

This package contains libraries for the Coarse Graining Engine of VOTCA package.

%package devel
Summary:	Development headers and libraries for VOTCA Coarse Graining Engine
Group:		Development/Libraries
Requires:	%{name}-libs = %{version}-%{release}
Requires:	votca-tools-devel

%description devel
This package contains development headers and libraries for the Coarse Graining
Engine of VOTCA.

%package common
Summary:	Architecture independent data files for VOTCA CSG
Group:		Applications/Engineering
BuildArch:	noarch

%description common
Versatile Object-oriented Toolkit for Coarse-graining Applications (VOTCA) is
a package intended to reduce the amount of routine work when doing systematic
coarse-graining of various systems. The core is written in C++.

This package contains architecture independent data files for VOTCA CSG.

%package bash
Summary:	Bash completion for votca
Group:		System Environment/Shells
Requires:	%{name} = %{version}-%{release}
Requires:	bash-completion
BuildArch:	noarch

%description bash
Versatile Object-oriented Toolkit for Coarse-graining Applications (VOTCA) is
a package intended to reduce the amount of routine work when doing systematic
coarse-graining of various systems. The core is written in C++. Iterative
methods are implemented using bash + perl.

This package contains bash completion support for votca-csg.

%prep
%setup -q

%build
%configure --disable-static --disable-la-files --disable-rc-files --with-libgmx=gmx_d
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

%clean
rm -rf %{buildroot}
# Move bash completion file to correct location
mkdir -p %{buildroot}%{_sysconfdir}/bash_completion.d
cp scripts/csg-completion.bash %{buildroot}%{_sysconfdir}/bash_completion.d/votca

%post libs -p /sbin/ldconfig
%postun libs -p /sbin/ldconfig

%files
%defattr(-,root,root,-)
%doc CHANGELOG NOTICE README
%{_bindir}/csg_*
%{_bindir}/multi_g_*

%files common
%defattr(-,root,root,-)
%{_datadir}/votca

%files libs
%defattr(-,root,root,-)
%doc LICENSE
%{_libdir}/libvotca_csg.so.*

%files devel
%defattr(-,root,root,-)
%{_includedir}/votca/csg/
%{_libdir}/libvotca_csg.so
%{_libdir}/pkgconfig/libvotca_csg.pc

%files bash
%defattr(-,root,root,-)
%{_sysconfdir}/bash_completion.d/votca

%changelog
* Thu Nov 25 2010 Jussi Lehtola <jussilehtola@fedoraproject.org> - 1.0-1
- First release.
* Thu Nov 30 2010 Christoph Junghans <junghans@votca.org> - 1.0.1-1
- Minor cleanup.
