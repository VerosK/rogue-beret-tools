#!/usr/bin/perl -w
#
# Simple SNMP memory check - version 1.0
#
# Originally written by Corey Henderson
#
# Dual-Licensed - you may choose between:
#
# 1) Public Domain
# 2) WTFPL - see http://sam.zoy.org/wtfpl/
#

use strict;
use warnings;

use POSIX qw(mktime);

use constant STATUS_OK => 0;
use constant STATUS_WARN => 1;
use constant STATUS_CRITICAL => 2;
use constant STATUS_UNKNOWN => 3;

my $snmpget = '/usr/bin/snmpget';

my $warn;
my $crit;
my $offset;

use Getopt::Long;

my $result = GetOptions(
	"w=i" => \$warn,
	"c=i" => \$crit,
	"o=i" => \$offset,
	"h|help" => \&usage,
);

sub usage {
	print "Usage: $0 [-w NUM] [-c NUM] [-o offset] -- [snmpget options]\n";
	print "\t-w\twarning threshhold\n";
	print "\t-c\tcritical threshhold\n";
	print "\t-o\texpected offset in seconds\n";
	print "EXAMPLES:\n";
	print "\tsnmp v1:\n";
	print "\t$0 -w 85 -c 95 -- -c community example.com\n";
	print "\tsnmp v3:\n";
	print "\t$0 -w 85 -c 95 -- -v3 -l authPriv -a MD5 -u exampleuser -A \"example password\" example.com\n";
	exit STATUS_UNKNOWN;
}

map { $_ = '"' . $_ . '"' if $_ =~ / /} @ARGV;
map { $_ = "'" . $_ . "'" if $_ =~ /"/} @ARGV;

my $STR = join(" ", @ARGV);

sub do_snmp {
	my ($OID) = @_;

	my $cmd = $snmpget . " " . $STR . " " . $OID;

	chomp(my $out = `$cmd 2> /dev/null`);

	if ($? != 0) {
		return "ERROR";
	}

	my $type;

	my ($jnk, $x) = split / = /, $out, 2;

	if ($x =~ /([a-zA-Z0-9]+): (.*)$/) {
		$type = $1;
		$x = $2;
	}

	return $x;
}

my $time_str = do_snmp("HOST-RESOURCES-MIB::hrSystemDate.0");
my $time;

if ("ERROR" eq $time_str) {

	$time_str = do_snmp("UCD-SNMP-MIB::versionCDate.0");

	if ("ERROR" eq $time_str) {
		print "SNMP problem - no value returned from host\n";
		exit STATUS_UNKNOWN;
	} else {
		$time = versionCDate($time_str);
	}

} else {
	$time = hrSystemDate($time_str);
}

my $diff = $time - time();

if ($offset) {
	$diff += $offset;
}

my $ret;
my $status;

print "TIME ";

if ($crit && ($diff >= $crit || ($diff*-1) >= $crit)) {
	print "CRITICAL";
	$ret = STATUS_CRITICAL;
} elsif ($warn && ($diff >= $warn || ($diff*-1) >= $warn)) {
	print "WARNING";
	$ret = STATUS_WARN;
} else {
	print "OK";
	$ret = STATUS_OK;
}

print "; offset $diff seconds\n";

exit $ret;

sub hrSystemDate {
	my ($str) = @_;

	my ($year_str, $time_str, $tz_str) = split /,/, $str, 3;

	my ($year, $month, $day) = split /\-/, $year_str, 3;
	my ($hr, $min, $sec) = split /:/, $time_str, 3;
	my ($tz) = split /:/, $tz_str, 2;

	my $tm = mktime($sec, $min, $hr, $day, $month-1, $year-1900, 0, 0, 0);
	$tm -= (3600*($tz+7));

	return $tm;
}

sub versionCDate {
	my ($str) = @_;

	my $months = { "Jan" => 0, "Feb" => 1, "Mar" => 2, "Apr" => 3, "May" => 4, "Jun" => 5, "Jul" => 6, "Aug" => 7, "Sep" => 8, "Oct" => 9, "Nov" => 10, "Dec" => 11 };

	my ($x, $month_str, $day, $time_str, $year) = split /\s+/, $str, 5;

	my ($hr, $min, $sec) = split /:/, $time_str, 3;
	my $month = $months->{$month_str};

	my $tm = mktime($sec, $min, $hr, $day, $month, $year-1900, 0, 0, 0);

	return $tm;
}

