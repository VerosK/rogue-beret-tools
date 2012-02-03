#!/usr/bin/perl -w
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

my $snmpwalk = '/usr/bin/snmpwalk';

my $iface;

use Getopt::Long;

my $result = GetOptions(
	"i=s" => \$iface,
	"h|help" => \&usage,
);

sub usage {
	print "Usage: $0 -i ifName -- [snmpwalk options]\n";
	exit STATUS_UNKNOWN;
}

if (!$iface) {
	&usage;
}

map { $_ = '"' . $_ . '"' if $_ =~ / /} @ARGV;
map { $_ = "'" . $_ . "'" if $_ =~ /"/} @ARGV;

my $STR = join(" ", @ARGV);

sub do_snmpwalk {
	my ($OID) = @_;

	my $ret = [];

	my $cmd = $snmpwalk . " " . $STR . " " . $OID;

	chomp(my $out = `$cmd 2> /dev/null`);

	if ($? != 0) {
		print "SNMP problem - no value returned\n";
		exit STATUS_UNKNOWN;
	}

	my @lines = split /\n/, $out;

	foreach my $line (@lines) {

		my $type;

		my ($jnk, $x) = split / = /, $line, 2;

		if ($x =~ /([a-zA-Z0-9]+): (.*)$/) {
			$type = $1;
			push @{$ret}, $2;
		}

	}

	return $ret;
}

my $ret = STATUS_OK;
my $status = "OK";

# get interface info

my $desc = do_snmpwalk("IF-MIB::ifDescr");
my $inoct = do_snmpwalk("IF-MIB::ifInOctets");
my $outoct = do_snmpwalk("IF-MIB::ifOutOctets");

my $ifaces = {};

for (my $i = 0; $i < scalar @{$desc}; $i++) {
	my $key = $desc->[$i];
	$ifaces->{$key} = {
		inOctets => $inoct->[$i],
		outOctets => $outoct->[$i],
	};
}

if (!$ifaces->{$iface}) {
	print "SNMP problem - interface '$iface' does not exist\n";
	exit STATUS_UNKNOWN;
}

my $i = $ifaces->{$iface};

print $iface . "; in=" . $i->{inOctets} . ", out=" . $i->{outOctets};
print " | inOctets=" . $i->{inOctets} . "c;;;; outOctets=" . $i->{outOctets} . "c;;;;\n";

exit STATUS_OK;


sub in_array {
	my ($needle, @haystack) = @_;

	foreach my $hay (@haystack) {
		return 1 if $hay eq $needle;
	}

	return 0;
}

