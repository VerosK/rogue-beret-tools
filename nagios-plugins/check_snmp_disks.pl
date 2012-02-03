#!/usr/bin/perl -w
#
# Simple SNMP disks check - version 1.0
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

my $warn;
my $crit;
my @i;
my @d;

use Getopt::Long;

my $result = GetOptions(
	"w=i" => \$warn,
	"c=i" => \$crit,
	"i=s" => \@i,
	"d=s" => \@d,
	"h|help" => \&usage,
);

sub usage {
	print "Usage: $0 -w NUM -c NUM [-s] -- [snmpwalk options]\n";
	print "\t-w\twarning threshhold\n";
	print "\t-c\tcritical threshhold\n";
	print "\n";
	print "\tBy default, all disks are checked. You can supply -o or -d to change this:\n";
	print "\n";
	print "\t-i\tcheck only this disk, can be specified multiple times\n";
	print "\t-d\tdon't check this disk, can be specified multiple times\n";
	print "EXAMPLES:\n";
	print "\tsnmp v1:\n";
	print "\t$0 -w 85 -c 95 -- -c community example.com\n";
	print "\tsnmp v3:\n";
	print "\t$0 -w 85 -c 95 -- -v3 -l authPriv -a MD5 -u exampleuser -A \"example password\" example.com\n";
	exit STATUS_UNKNOWN;
}

if (!$warn or !$crit or ($warn and ($warn !~ /^[0-9]+$/ or $warn < 0 or $warn > 100)) or ($crit and ($crit !~ /^[0-9]+$/ or $crit < 0 or $crit > 100))) {
	print "You must supply -w and -c with integer values between 0 and 100\n";
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
my $disks = {};

sub check_disk {
	my ($name, $usage) = @_;

	return if in_array($name, @d);

	if ($usage >= $crit) {
		$status = "CRITICAL";
		$ret = STATUS_CRITICAL;
	} elsif ($usage >= $warn && $ret != STATUS_CRITICAL) {
		$status = "WARNING";
		$ret = STATUS_WARN;
	}

	my $str = $name . " " . $usage . "% full";

	$disks->{$name} = $usage;
}

# get disk info

my $disk_names = do_snmpwalk("UCD-SNMP-MIB::dskPath");
my $disk_usage = do_snmpwalk("UCD-SNMP-MIB::dskPercent");

if (scalar(@i)) {

	foreach my $disk (@i) {

		# make sure all disks exist, else exit unknown
		if (!in_array($disk, @{$disk_names})) {
			print "SNMP problem - the $disk disk does not exist\n";
			exit STATUS_UNKNOWN;
		}

		# find this disks's index in @{$disk_names}
		my $idx;

		for (my $i = 0; $i < scalar(@{$disk_names}); $i++) {
			if ($disk eq $disk_names->[$i]) {
				$idx = $i;
			}
		}

		check_disk($disk, $disk_usage->[$idx]);
	}

} else {

	for (my $i = 0; $i < scalar(@{$disk_names}); $i++) {
		check_disk($disk_names->[$i], $disk_usage->[$i]);
	}

}

print "DISK" . ( scalar(keys(%{$disks})) > 1 ? "S" : "" ) . " ";

if (scalar(keys(%{$disks})) == 0 ) {
	print "UNKNOWN - no disks were checked\n";
	$ret = STATUS_UNKNOWN;
} else {

	my @status;
	my @perf;

	foreach my $key (sort {$disks->{$b} <=> $disks->{$a} } keys %{$disks}) {
		push @status, "$key " . $disks->{$key} . "% full";
		push @perf, "$key=" . $disks->{$key} . ";;;;";
	}

	print "$status: " . join(", ", @status) . " |" . join(" ", @perf) . "\n";
}

exit $ret;


sub in_array {
	my ($needle, @haystack) = @_;

	foreach my $hay (@haystack) {
		return 1 if $hay eq $needle;
	}

	return 0;
}

