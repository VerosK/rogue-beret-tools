Name:		rb-nagios-plugins
Version:	1.0
Release:	1%{?dist}
Summary:	Cloudflare Apache Module

Group:		Applications/System
License:	Public Domain/WTFPL
URL:		http://rogue-beret.org/
Source01:	check_snmp.pl
Source02:	check_snmp_disks.pl
Source03:	check_snmp_memory.pl
Source04:	check_snmp_time.pl
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch:	noarch

Requires:	perl

%description
Nagios plugins provided by the Rogue Beret Repo.

%prep
%setup -c -T
for i in check_snmp.pl check_snmp_disks.pl check_snmp_memory.pl check_snmp_time.pl; do
	cp $RPM_SOURCE_DIR/$i .
done

%build

%install
rm -rf $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT/%{_libdir}/nagios/plugins/

install -m 755 *.pl $RPM_BUILD_ROOT/%{_libdir}/nagios/plugins/


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%{_libdir}/nagios/plugins/*.pl

%changelog
* Wed Jan 18 2012 Corey Henderson <corman@cormander.com> [1.0-1.el6]
- Initial build.

