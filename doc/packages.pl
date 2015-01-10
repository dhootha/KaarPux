#!/usr/bin/perl -w
#
# KaarPux: http://kaarpux.kaarposoft.dk
#
# Copyright (C) 2012: Henrik Kaare Poulsen
#
# License: http://kaarpux.kaarposoft.dk/license.html
#

use strict;
use File::Basename;
#use Data::Dumper;
use YAML::Tiny;

my $debug=0;
my $n_retry=4;
my $insane=0;


# ============================================================

if ($#ARGV != 1 ) {
	die "*** Please specify <pkg_dir> and <tmp_dir> as arguments\n";
}

my $pkg_dir = $ARGV[0];
my $tmp_dir = $ARGV[1];


print "Including package version script\n";

my $pkg_inc_script=dirname(__FILE__) . "/../../master/tools/kx_version.plinc";
eval `cat $pkg_inc_script` or die $@;

my %package_versions;

my $pkg_version_script=dirname(__FILE__) . "/../../linux/plinc/kx_version.plinc";
eval `cat $pkg_version_script` or die $@;

mkdir "$tmp_dir/packages";


print "Processing packages\n";

my %package_headers = ();

while (<$pkg_dir/*>) {
	$package_headers{basename($_)} = [];
	my $d="$tmp_dir/packages/" . basename($_);
	mkdir($d) or die "cannot create directory [$d]: $!";
}

while (<$pkg_dir/*>) {
	process_dir($_);
}


print "Writing package headers\n";

write_package_headers();

exit 0;


# ============================================================

sub write_package_headers {
	for (keys %package_headers) {
		my $sub_dir = $_;
		mkdir "$tmp_dir/packages/$sub_dir";
		open(my $fh, ">", "$tmp_dir/packages/$sub_dir.xml");
		print $fh "<appendix id='pkg_$sub_dir'><?dbhtml filename='packages/$sub_dir/index.html' ?><title>KaarPux Packages: $sub_dir*</title>\n";
		my @pkgs = @{$package_headers{$sub_dir}};
		foreach my $p (@pkgs) {
			print $fh "<xi:include xmlns:xi='http://www.w3.org/2001/XInclude' href='$sub_dir/$p.xml'/>\n";
		}
		print $fh "</appendix>\n";
		close($fh);
	}
}


# ============================================================

sub process_dir {
	my ($dir) = @_;
	my $sub_dir = basename($dir);
	print "Processing package directory [$sub_dir]\n";
	mkdir "$tmp_dir/packages/$sub_dir";
	while (<$dir/*.yaml>) {
		my $p = basename($_);
		$p =~ s{\.[^.]+$}{};
		process_pkg($sub_dir, $p);
	}
}


# ============================================================

sub process_pkg {
	my ($sub_dir, $pkg) = @_;
	#print "\tPackage [$pkg]\n";
	my $pkg_ref = pkg_ref_from_name($pkg);
        my $yaml_file = "$pkg_dir/$sub_dir/$pkg.yaml";
	my $yaml = YAML::Tiny->read($yaml_file);
	if (!defined $yaml) {
		die "Could not read YAML for [${pkg}] in [${yaml_file}]: ". YAML::Tiny->errstr;
	}
	$yaml = $yaml->[0];
	if ($yaml->{'perl_modules'}) {
		process_perl_modules($sub_dir, $pkg, $pkg_ref, $yaml);
	} elsif ($yaml->{'haskell_modules'}) {
		process_haskell_modules($sub_dir, $pkg, $pkg_ref, $yaml);
	} elsif ($yaml->{'xorg'}) {
		process_xorg_modules($sub_dir, $pkg, $pkg_ref, $yaml);
	} else {
		process_yaml_pkg($sub_dir, $pkg, $pkg_ref, $yaml);
	}
}


# ============================================================

sub process_yaml_pkg {
	my ($sub_dir, $pkg, $pkg_ref, $yaml) = @_;

	open(my $fh, ">", "$tmp_dir/packages/$sub_dir/$pkg.xml");
	my $ypkg=$yaml->{"package"};

	print $fh section_top($sub_dir, $pkg, "KaarPux Package: $pkg");
	print $fh para($ypkg->{"short"});

	print $fh table_top();
	print $fh row("Name", $ypkg->{"name"});
	print $fh row("Version", $ypkg->{"version"});
	print $fh row_url("Homepage", $ypkg->{"www"});
	print $fh row_url("Tarball", $ENV{"KX_${pkg_ref}_TARBALL"} );
	print $fh row_step($yaml);
	print $fh row_definition($sub_dir, $pkg);
	print $fh row_lfs($yaml);
	print $fh table_bottom();

	my $doc = $yaml->{"doc"};
	if (defined $doc) { print $fh $doc; }

	print $fh section_bottom();

	close($fh);
	push($package_headers{$sub_dir}, $pkg);

}


# ============================================================

sub process_xorg_modules {
	my ($sub_dir, $pkg, $pkg_ref, $yaml) = @_;

	open(my $fh, ">", "$tmp_dir/packages/$sub_dir/$pkg.xml");
	my $ypkg=$yaml->{"package"};

	print $fh section_top($sub_dir, $pkg, "KaarPux Meta Package: $pkg");
	print $fh table_top();

	print $fh row("Name", $ypkg->{"name"});
	print $fh row("Version", $ypkg->{"version"});
	print $fh row_url("Homepage", "http://www.x.org");
	print $fh row_definition($sub_dir, $pkg);

	print $fh table_bottom();

	my $xorg = $yaml->{'xorg'};
	foreach my $g (@$xorg) {
		foreach my $group (keys %$g) {
			my @modules = split(/\n/, $g->{$group});
			$group =~s/(.*)_modules/$1/;
			print $fh "<section id='pkg_$pkg'>\n";
			print $fh "<title>xorg $group Modules</title>\n";
			print $fh "<itemizedlist>\n";
			foreach my $md5_module_file (@modules) {
				my ($parallel, $md5, $module_file) = ($md5_module_file =~ /\s*(\S*)\s*(\S*)\s*(\S*)\s*/);
				my ($module_name, $version) = ($module_file =~ /(.*)-([0-9\.]*)\.tar\.bz2/);
				one_xorg_module($sub_dir, $pkg, $module_name, $group, $version, $module_file);
				print $fh "<listitem><para><xref linkend='pkg_$module_name'/></para></listitem>\n";
			}
			print $fh "</itemizedlist>\n";
			print $fh "</section>\n";
		}
	}

	print $fh section_bottom();
	close($fh);
	push($package_headers{$sub_dir}, $pkg);
}


# ============================================================


sub one_xorg_module {
	my ($parent_dir, $parent_pkg, $pkg, $group, $version, $file) = @_;

	my $xorg = "http://xorg.freedesktop.org/releases/individual";

	my $sub_dir = substr($pkg, 0, 1);
	$sub_dir =~ tr/A-Z/a-z/;

	my $f = "$tmp_dir/packages/$sub_dir/$pkg.xml";
	open(my $fh, ">", $f) or die "cannot open [$f]: $!";

	print $fh section_top($sub_dir, $pkg, "KaarPux xorg $group Module: $pkg");
	print $fh table_top();

	print $fh row("Name", $pkg);
	print $fh row("Version", $version);
	print $fh row_url("Tarball", "${xorg}/${group}/${file}" );
	print $fh row_definition($parent_dir, $parent_pkg);

	print $fh table_bottom();
	print $fh section_bottom();

	close($fh);
	push($package_headers{$sub_dir}, $pkg);
}


# ============================================================

sub process_perl_modules {
	my ($sub_dir, $pkg, $pkg_ref, $yaml) = @_;

	open(my $fh, ">", "$tmp_dir/packages/$sub_dir/$pkg.xml");
	my $ypkg=$yaml->{"package"};

	print $fh section_top($sub_dir, $pkg, "KaarPux Meta Package: $pkg");

	print $fh "<section id='pkg_perl_modules'><title>Perl Packages</title><itemizedlist>\n";

	my %perl_modules = %{$yaml->{'perl_modules'}};
	for (keys %perl_modules) {
		one_perl_module($_, $perl_modules{$_});
		print $fh "<listitem><para><xref linkend='pkg_$_'/></para></listitem>\n";
	}

	print $fh "</itemizedlist></section>\n";

	print $fh section_bottom();

	close($fh);
	push($package_headers{$sub_dir}, $pkg);
}


# ============================================================

sub one_perl_module {
	my ($pkg, $def) = @_;

	my $sub_dir = substr($pkg, 0, 1);
	$sub_dir =~ tr/A-Z/a-z/;

	my ($alias, $version, $author, $checksum, $bootstrap) = split(/\s+/, $def);
	my ($module, $rest) = split(/-/, $pkg);

	my $f = "$tmp_dir/packages/$sub_dir/$pkg.xml";
	open(my $fh, ">", $f) or die "cannot open [$f]: $!";

	print $fh section_top($sub_dir, $pkg, "KaarPux Perl Module: $pkg");
	print $fh table_top();

	print $fh row("Name", $pkg);
	print $fh row("Alias", $alias);
	print $fh row("Version", $version);
	print $fh row_url("Homepage", "http://search.cpan.org/~$author/$alias-$version");
	print $fh row_url("Tarball", "http://www.cpan.org/modules/by-module/${module}/${author}/${alias}-${version}.tar.gz" );
	print $fh row_definition("p", "perl_modules");

	print $fh table_bottom();
	print $fh section_bottom();

	close($fh);
	push($package_headers{$sub_dir}, $pkg);
}



# ============================================================

sub process_haskell_modules {
	my ($sub_dir, $pkg, $pkg_ref, $yaml) = @_;

	open(my $fh, ">", "$tmp_dir/packages/$sub_dir/$pkg.xml");
	my $ypkg=$yaml->{"package"};

	print $fh section_top($sub_dir, $pkg, "KaarPux Meta Package: $pkg");

	print $fh "<section id='pkg_haskell_modules'><title>Haskell Modules</title><itemizedlist>\n";

	my %haskell_modules = %{$yaml->{'haskell_modules'}};
	for (keys %haskell_modules) {
		one_haskell_module($_, $haskell_modules{$_});
		print $fh "<listitem><para><xref linkend='pkg_HASKELLMODULE_$_'/></para></listitem>\n";
	}

	print $fh "</itemizedlist></section>\n";

	print $fh section_bottom();

	close($fh);
	push($package_headers{$sub_dir}, $pkg);
}


# ============================================================

sub one_haskell_module {
	my ($pkg, $def) = @_;

	my $hpkg = "HASKELLMODULE_" . $pkg;
	my $sub_dir = "h";

	my ($version, $checksum) = split(/\s+/, $def);

	my $f = "$tmp_dir/packages/$sub_dir/$hpkg.xml";
	open(my $fh, ">", $f) or die "cannot open [$f]: $!";

	print $fh section_top($sub_dir, $hpkg, "KaarPux Haskell Module: $pkg");
	print $fh table_top();

	print $fh row("Name", $hpkg);
	print $fh row("Alias", $pkg);
	print $fh row("Version", $version);
	print $fh row_url("Homepage", "http://hackage.haskell.org/package/${pkg}");
	print $fh row_url("Tarball", "http://hackage.haskell.org/packages/archive/${pkg}/${version}/${pkg}-${version}.tar.gz" );
	print $fh row_definition("h", "haskell_modules");

	print $fh table_bottom();
	print $fh section_bottom();

	close($fh);
	push($package_headers{$sub_dir}, $hpkg);
}


# ============================================================

sub section_top {
	my ($sub_dir, $pkg, $title) = @_;
	my $s;
	$s = "<section id='pkg_$pkg'><?dbhtml filename='packages/$sub_dir/$pkg.html' ?>\n";
	$s .= "<title>$title</title>\n";
	return $s;
}


# ============================================================

sub section_bottom {
	return "</section>";
}


# ============================================================

sub table_top {
	my $s;
	$s = "<informaltable><tgroup cols='2' align='left' colsep='1' rowsep='1'>\n";
	$s .= "<colspec /><colspec /><tbody>\n";
	return $s;
}


# ============================================================

sub table_bottom {
	return "</tbody></tgroup></informaltable>\n";
}


# ============================================================

sub para {
	my ($txt) = @_;
	return unless defined $txt;
	"<para>$txt</para>\n";
}


# ============================================================

sub row {
	my ($c1, $c2) = @_;
	return unless defined $c2;
	"<row><entry>$c1</entry><entry>$c2</entry></row>\n";
}


# ============================================================

sub row_url {
	my ($c1, $c2) = @_;
	return unless defined $c2;
	$c2 =~ s|&|&amp;|g;
	row($c1, "<ulink url='$c2'>$c2</ulink>");
}


# ============================================================

sub row_definition {
	my ($sub_dir, $pkg) = @_;
#	return unless defined $pkg;
	my $ref="http://sourceforge.net/p/kaarpux/code/ci/HEAD/tree/master/packages/${sub_dir}/${pkg}.yaml";
#	$ref =~ s|&|&amp;|g;
	row("Definition", "<ulink url='$ref'>${pkg}.yaml</ulink>");
}


# ============================================================

sub row_lfs {
	my ($yaml) = @_;
	my $lfs = $yaml->{"lfs"};
	return unless defined $lfs;
	my $s = "<itemizedlist>\n";
	foreach (@$lfs) {
		$s .= "<listitem><ulink url='$_'>$_</ulink></listitem>\n";
	}
	$s .= "</itemizedlist>\n";
	row("LFS ref", $s);
}

# ============================================================

sub row_step {
	my ($yaml) = @_;
	my @steps = ();
	my $step;
	$step = $yaml->{"bootstrap_1"}; push(@steps, "Bootstrap 1") if $step;
	$step = $yaml->{"bootstrap_2"}; push(@steps, "Bootstrap 2") if $step;
	$step = $yaml->{"bootstrap_3"}; push(@steps, "Bootstrap 3") if $step;
	$step = $yaml->{"bootstrap_4"}; push(@steps, "Bootstrap 4") if $step;
	$step = $yaml->{"bootstrap_5"}; push(@steps, "Bootstrap 5") if $step;
	$step = $yaml->{"bootstrap_6"}; push(@steps, "Bootstrap 6") if $step;
	$step = $yaml->{"bootstrap_7"}; push(@steps, "Bootstrap 7") if $step;
	$step = $yaml->{"bootstrap_8"}; push(@steps, "Bootstrap 8") if $step;
	$step = $yaml->{"linux"}; push(@steps, "Linux") if $step;
	$step = $yaml->{"opt"}; push(@steps, "Opt") if $step;
	
	return unless @steps;

	my $s = "<itemizedlist>\n";
	foreach (@steps) {
		$s .= "<listitem><para>$_</para></listitem>\n";
	}
	$s .= "</itemizedlist>\n";
	row("Step", $s);
}


# ============================================================

sub pkg_ref_from_name {
	my ($pkg_name) = @_;
	my $pkg_ref = $pkg_name;
	$pkg_ref =~ tr/a-z/A-Z/;
	$pkg_ref =~ s/\+/_PLUS/g;
	$pkg_ref =~ tr/a-zA-Z0-9/_/cs;
	return $pkg_ref;
}

