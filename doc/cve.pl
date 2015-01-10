#!/usr/bin/perl -w
#
# KaarPux: http://kaarpux.kaarposoft.dk
#
# Copyright (C) 2014: Henrik Kaare Poulsen
#
# License: http://kaarpux.kaarposoft.dk/license.html
#

use strict;
use File::Basename;
use File::stat;
use POSIX;

# ============================================================

sub read_cve_list {
	my ($filename, $cve_list) = @_;
	open(my $f, $filename) or die "Couldn't open file [$filename]: $!";
	my $timestamp = (stat($f))->mtime;
	while(<$f>) {
		chomp;
		next if /^\s*$/;
		next if /^\s*#/;
		my @line = split /\s/,$_,4;
		if ($line[1] eq "ignore") { next; } 
		$cve_list->{$line[0]} = [ $line[1], $line[2], $line[3] ];
	}
	close $f;
	return localtime($timestamp);
}

# ============================================================

sub print_cve_list {
	my ($filename, $cve_list, $stimestamp) = @_;
	open FILE, ">", $filename or die "Couldn't open file [$filename] for writing: $!";
	print FILE <<EOF;
<section id="cve">
<title>Relevant Common Vulnerabilities and Exposures</title>
<para>
List of <ulink url="http://en.wikipedia.org/wiki/Common_Vulnerabilities_and_Exposures">
Common Vulnerabilities and Exposures</ulink> relevant for &kx;
</para><para>
Last updated $stimestamp
</para><para>
<table id="cve_table">
	<title></title>
	<tgroup cols='4' align='center' colsep='1' rowsep='1'>
	<colspec colname='CVE' align='left'/>
	<colspec colname='status' align='left'/>
	<colspec colname='package' align='left'/>
	<colspec colname='comment' align='left'/>
	<thead>
		<row>
		<entry>CVE</entry>
		<entry>status</entry>
		<entry>package</entry>
		<entry>comment</entry>
		</row>
	</thead>
	<tbody>
EOF
	foreach my $cve (sort {$b cmp $a} keys %$cve_list) {
		my $val = $cve_list->{$cve};
		my $role = "";
		if ( (@{$val})[0] eq "open" ) {
			$role = "role='security_open'";
		}
		print FILE "<row>\n";
		print FILE "<entry $role><ulink url='http://web.nvd.nist.gov/view/vuln/detail?vulnId=$cve'>$cve</ulink></entry>\n";
		foreach my $v (@$val) {
			$v =~ s|COMMIT\s+(\w{8})(\w+)|commit <ulink url="http://sourceforge.net/p/kaarpux/code/ci/$1$2/">$1</ulink>|g;			
			$v =~ s|URL\s+(\S+)|see <ulink url="$1">reference</ulink>|g;
			print FILE "<entry $role>$v</entry>\n";
		}
		print FILE "</row>\n";
	}
	print FILE << 'EOF';
	</tbody>
</tgroup></table>
</para><para>
See <xref linkend="identifying_cve" /> for information on how to update this list.
</para>
</section>
EOF
	close FILE;
}

# ============================================================

if ($#ARGV != 1 ) {
	die "*** Please specify <master_dir> and <tmp_dir> as arguments\n";
}

my $pkg_dir = "REMOVEME";

my $master_dir = $ARGV[0];
my $tmp_dir = $ARGV[1];

my %cve_list = ();

print "Reading CVE list\n";
my @timestamp = read_cve_list("$master_dir/cve_list.txt", \%cve_list);


my $stimestamp = POSIX::strftime("%Y-%h-%d", @timestamp);

print "Processing CVE list\n";
print_cve_list("$tmp_dir/cve.xml", \%cve_list, $stimestamp);

