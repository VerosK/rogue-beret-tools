#!/usr/bin/perl -w
#
# Simple SNMP memory check - version 1.0
#
# Originally written by Corey Henderson, modified by Věroš Kaplan
# 
# Dual-Licensed - you may choose between:
#
# 1) Public Domain
# 2) WTFPL - see http://sam.zoy.org/wtfpl/
#
# Find this and other interesting things at:
# https://github.com/cormander/rogue-beret-tools
#

use strict;
use warnings;

use POSIX qw(mktime);
use DateTime;

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

my $time_str = do_snmp(".1.3.6.1.2.1.25.1.2.0");
my $time;

if ("ERROR" eq $time_str) {

		print "SNMP problem - no value returned from host\n";
		exit STATUS_UNKNOWN;
} else {
	print 'snmp: ' . $time_str . "\n";
	$time = hrSystemDate($time_str);
}

my $diff_obj = $time - DateTime->now();
my $diff = $diff_obj->in_units('seconds');

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

print "; offset $diff seconds |offset=$diff;;;;\n";

exit $ret;

sub hrSystemDate {
	# 2013-6-3,21:49:39.0,+2:0

	my ($str) = @_;

	my ($year_str, $time_str, $tz_str) = split /,/, $str, 3;

	my ($year, $month, $day) = split /\-/, $year_str, 3;
	my ($hr, $min, $sec) = split /:/, $time_str, 3;
	my ($tz) = split /:/, $tz_str, 2;
	if (length($tz) == 2) {
		$tz = substr($tz,0,0) . '0' . substr($tz, 1,1);
	}

	my $dt = DateTime->new(
		year => $year, month => $month, day=> $day,
		hour => $hr, minute => $min, second => int($sec),
		nanosecond => 0,
			time_zone=>$tz."00");

	return $dt;
}

