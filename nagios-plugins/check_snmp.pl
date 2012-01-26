#!/usr/bin/perl -w
#
# Simple SNMP check - version 1.1
#
# Originally written by Corey Henderson
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

use constant STATUS_OK => 0;
use constant STATUS_WARN => 1;
use constant STATUS_CRITICAL => 2;
use constant STATUS_UNKNOWN => 3;

my $snmpget = '/usr/bin/snmpget';

my $warn;
my $crit;
my $u2c;
my $msg;

use Getopt::Long;

my $result = GetOptions(
        "w=i" => \$warn,
        "c=i" => \$crit,
	"u" => \$u2c,
	"m=s" => \$msg,
	"h|help" => \&usage,
);

sub usage {
	print "Usage: $0 [-w NUM] [-c NUM] [-m message] -- [snmpget options]\n";
	print "\t-w\twarning threshhold\n";
	print "\t-c\tcritical threshhold\n";
	print "\t-u\twhen status is unknown, report it as critical\n";
	print "\t-m\tappend given message to output\n";
	print "EXAMPLES:\n";
	print "\tsnmp v1:\n";
	print "\t$0 -w 85 -c 95 -- -c community example.com\n";
	print "\tsnmp v3:\n";
	print "\t$0 -w 85 -c 95 -- -v3 -l authPriv -a MD5 -u exampleuser -A \"example password\" example.com OID\n";
	exit STATUS_UNKNOWN;
}

map { $_ = '"' . $_ . '"' if $_ =~ / /} @ARGV;
map { $_ = "'" . $_ . "'" if $_ =~ /"/} @ARGV;

my $STR = join(" ", @ARGV);

my $cmd = $snmpget . " " . $STR;

chomp(my $out = `$cmd 2> /dev/null`);

if ($? != 0) {
	print "SNMP problem - no value returned\n";
	exit ( $u2c ? STATUS_CRITICAL : STATUS_UNKNOWN );
}

my $ret;
my $status;
my $type;

my ($jnk, $x) = split / = /, $out, 2;

if ($x =~ /([a-zA-Z0-9]+): (.*)$/) {
	$type = $1;
	$x = $2;
	$status = "OK";
	$ret = STATUS_OK;
} else {
	$status = "UNKNOWN";
	$ret = ( $u2c ? STATUS_CRITICAL : STATUS_UNKNOWN );
}

my $snmp_value = $x;

if ($crit && $snmp_value >= $crit) {
	$status = "CRITICAL";
	$ret = STATUS_CRITICAL;
} elsif ($warn && $snmp_value >= $warn) {
	$status = "WARNING";
	$ret = STATUS_WARN;
}

print "SNMP $status: $snmp_value" . ( $msg ? $msg : "" ) . "\n";

exit $ret;

