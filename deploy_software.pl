#!/usr/bin/env perl

use strict;
use warnings;

use Cwd 'abs_path';
use Getopt::Long;
use File::Basename;
use JSON;
use File::Temp;
#use LWP::UserAgent;
use Data::Dumper;

1;



my $target = "/home/ubuntu/";

my $default_repository = 'https://raw.github.com/wgerlach/DeploySoftware/master/repository.json';

#########################################
my %already_installed;
my $h = {};

sub systemp {
	print "cmd: ".join(' ', @_)."\n";
	return system(@_);
}

sub downloadFile {
	my %args = @_;
	
	my $url = $args{'url'};
	my $dir = $args{'target-dir'};
	my $targetname = $args{'target-name'};
	#my $output = $args{'output'};

	unless (defined $dir) {
		die;
	}
	
	unless (defined $url) {
		die;
	}
	
	if (substr($dir, -1, 1) ne '/') {
		$dir .= '/';
	}
	
	
	my $file;
	unless (defined $targetname) {
		
		my $basefilename = (split qr{/}, $url)[-1];  # detect filename if possible
		
		unless (defined $basefilename) {
			die "filename could not be detected from url $url";
		}
		
		
		$targetname = $basefilename;
	}
	
	$file = $dir. $targetname;
	
	if (-e $file) {
		if (defined $h->{'new'}) {
			systemp("rm $file");
		} else {
			print "skip file: $file already exists....\n";
			return $file;
		}
	}
	
	
	systemp("cd $dir && curl -o $targetname --retry 1 --retry-delay 5 \"$url\"") == 0 or die;
	
	unless (-s $file) {
		die "file $file was not downloaded!?";
	}
	
	#my $fh = File::Temp->new(DIR => $dir, TEMPLATE => 'temp_XXXXXXXXX');
	#my $fname = $fh->filename;
	
	return $file;
	
}

sub process_scalar {
	my $text = shift;
	
	$text =~ s/\$target/$target/g ;
	$text =~ s/\$\{target\}/$target/g ;
	
	return $text;
}

sub datastructure_walk {
    my ($datastructure, $sub, $arg) = @_;
	
	if (ref($datastructure) eq 'HASH') {
		while (my ($k, $v) = each %$datastructure) {
			print "goto $k\n";
			if (ref($v) eq '') {
				print "scalar: ".$datastructure->{$k}."\n";
				$datastructure->{$k} = $sub->($v, $arg);
				print "scalar: ".$datastructure->{$k}."\n";
			} else {
				datastructure_walk($v, $sub, $arg);
			}
		}
	} elsif (ref($datastructure) eq 'ARRAY') {
		for (my $i = 0 ; $i < @$datastructure ; $i++ ) {
			if (ref($datastructure->[$i]) eq '') {
				print "scalar: ".$datastructure->[$i]."\n";
				$datastructure->[$i] = $sub->($datastructure->[$i], $arg);
				print "scalar: ".$datastructure->[$i]."\n";
			} else {
				datastructure_walk($datastructure->[$i], $sub, $arg);
			}
		}
	
	} elsif (ref($datastructure) ne '') {
		die "got: ".ref($datastructure);
	} else {
		# non-ref scalar !?
		print "scalar: $datastructure\n";
		die;
		
	}
	
	return;
}


sub setenv {
	my ($key, $value) = @_;
	my $envline = "$key=$value";
	systemp("grep -q -e '$envline' ~/.bashrc || echo '$envline' >> ~/.bashrc");
	
	
	if ($value =~ /\$/ || $value =~ /\~/) {
		#make sure that environment variables are evaluated
		my $echocmd = "echo \"$value\"";
		$value = `$echocmd`;
		chomp($value);
	}
	
	$ENV{$key}=$value; # makes sure variable can be used even if bashrc is not sourced yet.
	return;
}

sub git_clone {
	my ($source, $dir) = @_;
	
	
	my $gitname;
	
	#example git://github.com/qiime/qiime-deploy.git
	#example kbase@git.kbase.us:dev_container
	$gitname = (split(/\/|:/, $source))[-1]; # split on "/" and ":"
	
	if ($gitname =~ /\.git$/) { # remove .git suffix
		($gitname) = $gitname =~ /(.*)\.git/;
	}
		
	unless (defined $gitname){
		die "git string unkown: $source";
	}
	
	my $gitdir = $dir.$gitname.'/';
	
	if (-d $gitdir) {
		if (defined $h->{'update'}) {
			systemp("cd $gitdir && git pull") == 0 or die;
			return $gitdir;
		}
		if (defined $h->{'new'}) {
			systemp("rm -rf $gitdir") == 0 or die;
		}
	}
	systemp("cd $dir && git clone $source") == 0 or die;
	
	return $gitdir;
}

sub hg_clone {
	my ($source, $dir) = @_;
	
	my $hgname = (split('/', $source))[-1];
	
	unless (defined $hgname) {
		die;
	}
	
	my $hgdir = $dir.$hgname;
	
	if (-d $hgdir) {
		if (defined $h->{'update'}) {
			systemp("cd $hgdir && hg update") == 0 or die;
			return $hgdir;
		}
		if (defined $h->{'new'}) {
			systemp("rm -rf $hgdir") == 0 or die;
		}
	}
	
	systemp("cd $dir && hg clone ".$source) == 0 or die;
	
	return $hgdir;
}


# replaces ${i} variables
sub replaceArguments {
	my $exec = shift(@_);
	my $package_args_ref = shift(@_);
	
	unless (defined $package_args_ref) {
		return $exec;
	}
	
	print "exec: $exec\n";
	print "package_args: ".@$package_args_ref."\n";
	if (@$package_args_ref > 0) {
		for (my $i = 0 ; $i < @$package_args_ref; $i++) {
			my $k = $i+1;
			my $j = $package_args_ref->[$i];
			
			#print "j: ".$j."\n";
			$exec =~ s/\$\{$k\}/$j/g;
		}
		
		my $package_args_string = join(' ', @$package_args_ref);
		$exec =~ s/\$\{arguments\}/$package_args_string/g;
		
		
		
	}
	print "exec: $exec\n";
	return $exec;
}

sub replaceVersionNumbers {
	my $exec = shift(@_);
	my $version_numbers_ref = shift(@_);
	
	unless (defined $version_numbers_ref) {
		return $exec;
	}
	
	print 'ref: '.ref($version_numbers_ref)."\n";
	
	print "exec: $exec\n";
	print "version_numbers: ".@$version_numbers_ref."\n";
	if (@$version_numbers_ref > 0) {
		for (my $i = 0 ; $i < @$version_numbers_ref; $i++) {
			my $k = $i+1;
			my $j = $version_numbers_ref->[$i];
			
			#print "j: ".$j."\n";
			$exec =~ s/\$\{v$k\}/$j/g;
		}
	} else {
		die;
	}
	print "exec: $exec\n";
	return $exec;
}

sub replacePtarget {
	my $exec = shift(@_);
	my $ptarget = shift(@_);
	
	unless (defined $ptarget) {
		die;
	}
	
	#print 'ref: '.ref($version_numbers_ref)."\n";
	
	print "exec: $exec\n";
	$exec =~ s/\$\{ptarget\}/$ptarget/g;
	
	print "exec: $exec\n";
	return $exec;
}


sub parsePackageString{
	my $package_string = shift(@_);
	
	print "package_string: $package_string\n";
	
	my $package = undef;
	my ($p, $package_arg_line) = $package_string =~ /^(.*)\((.*)\)$/;
	
	my @package_args=();
	if (defined $package_arg_line) {
		$package = $p;
		@package_args = split(' ', $package_arg_line) ;

		
	} else {
		$package = $package_string;
	}
	
	
	my $argref = undef;
	if (@package_args > 0) {
		$argref = \@package_args;
	}

	
	my ($p2, $version) = $package =~ /^(.*)\=\=(.*)$/;
	
	if (defined $p2 && defined $version) {
		$package = $p2;
		
		my @version_array = split(/\./, $version); # make it an array_ref
		
		if (@version_array == 0) {
			die "version string parsing failed: \"$version\"";
		}
		
		$version = \@version_array;
		
	} else {
		$version = undef;
	}
	
	
	return ($package, $version, $argref);
	
}


my $functions = {};


sub function_kbasemodules {
	my %arghash = @_;
	
	my $server = $arghash{'server'} or die;
	my $target = $arghash{'target'} or die;
	my $package_list = $arghash{'package-list'} or die;
	
	
	if (substr($target, -1, 1) ne "/") {
		$target .= '/';
	}
	
	my @kbase_modules = split(' ', $arghash{'package-list'});
	
	my $downloaded_modules = {};
	while (@kbase_modules > 0) {
		my $module = shift(@kbase_modules);
		unless (defined $downloaded_modules->{$module}) {
			my $gitdir = git_clone($server.$module, $target);
			$downloaded_modules->{$module} = 1;
			
			
			
			my $filename = $gitdir.'DEPENDENCIES';
			if (-e $filename) {
				open my $fh, "<", $filename
				or die "could not open $filename: $!";
				my @deps = <$fh>;
				chomp(@deps);
				push(@kbase_modules, @deps);
			}
				
			
			
			
		}
		
	}
	
	
}

$functions->{'kbasemodules'} = \&function_kbasemodules;

sub install_package {
	my ($package_rules, $package, $version, $package_args_ref) = @_;
	
	print 'ref1: '.ref($version)."\n";
	
	if (defined($package_args_ref)) {
		# replace arguments if they have been used
		datastructure_walk($package_rules, \&replaceArguments, $package_args_ref);
	}
	
	print "install package: $package\n";
	print "args: ".join(' ',@$package_args_ref)."\n" if defined $package_args_ref;
	
	
	my $pack_hash;
	
	if ($package eq "subpackage") {
		$pack_hash = $package_rules;
	} else {
		$pack_hash = $package_rules->{$package};
	}
	
	unless (defined $pack_hash) {
		print STDERR "error: no configuration found for package $package\n";
		exit(1);
	}
	
	# START installation ########################
	if (defined $already_installed{$package} && $already_installed{$package}==1) {
		print "package $package already installed, skip it...\n";
		next;
	}
	
	if (defined $version) {
		print 'ref2: '.ref($pack_hash->{'version'})."\n";
		$pack_hash->{'version'} = $version;
	}
	if ((defined $pack_hash->{'version'}) && ($package ne "subpackage")) {
		print 'ref3: '.ref($pack_hash->{'version'})."\n";
		datastructure_walk($package_rules, \&replaceVersionNumbers, $pack_hash->{'version'});
	}
	
	my $ptarget = $pack_hash->{'ptarget'} || $target;
	if (substr($ptarget, -1, 1) ne '/') {
		$ptarget .= '/';
	}
	if ((defined $pack_hash->{'ptarget'})) {
		datastructure_walk($package_rules, \&replacePtarget, $ptarget);
	}
	
	
	
	my $packagedir = $ptarget.$package.'/';
	if (defined($pack_hash->{'dir'}) && ! -d $packagedir ) {
		systemp("mkdir -p ".$packagedir);
	}

	
	#dependencies
	if (defined $pack_hash->{'depends'}) {
		foreach my $dependency (@{$pack_hash->{'depends'}}) {
			
			my ($dep_package, $dep_version, $dep_package_args_ref) = parsePackageString($dependency);
			
			if (defined $already_installed{$package} && $already_installed{$package}==1) {
				print "dependency $dependency already installed\n";
			}else {
				print "install dependency $dependency for $dep_package...\n";
				install_package($package_rules, $dep_package, $dep_version, $dep_package_args_ref);
			}
		}
	}
	
	if ($package ne "subpackage") {
		if (defined($pack_hash->{'dir'})) {
			print "chdir $packagedir\n";
			chdir($packagedir);
		} else {
			if (-d $ptarget) {
				print "chdir $ptarget\n";
				chdir($ptarget);
			} else {
				print STDERR "warning: could not chdir $ptarget\n";
			}
		}
	}
	
	#subpackages
	if (defined $pack_hash->{'subpackages'}) {
		my $subpackages =$pack_hash->{'subpackages'};
		foreach my $dependency (@{$subpackages}) {
			print "install subpackage for $package...\n";
			install_package($dependency, "subpackage", $version, $package_args_ref); #recursive !
		}
	}
	
	
	if ($pack_hash->{'depend-function'}) {
		
		foreach my $function_hash (@{$pack_hash->{'depend-function'}}) {
			my $function_name = $function_hash->{'name'};
			&{$functions->{$function_name}}(%$function_hash);
		}
		
		
	}
	
	
	if (defined $pack_hash->{'source-as-parameter'} && $pack_hash->{'source-as-parameter'} ==1) {
		if (defined $package_args_ref) {
			push(@{$pack_hash->{'source'}}, @{$package_args_ref});
			print "source total: ".join(',', @{$pack_hash->{'source'}})."\n";
		}
	}

	if (defined $pack_hash->{'source'}) {
		my @sources;
		if (ref($pack_hash->{'source'}) eq 'ARRAY') {
			@sources = @{$pack_hash->{'source'}};
		} else {  # scalar or hash
			@sources = ($pack_hash->{'source'});
		}
		
		my $build_type = $pack_hash->{'build-type'} || 'exec';
		
		my $source_type = $pack_hash->{'source-type'} || 'auto';
		foreach my $source_obj (@sources) {
			
			my $source;
			my $source_filename;
			if (ref($source_obj) eq 'HASH') {
				$source = $source_obj->{'url'};
				$source_filename=$source_obj->{'filename'};
			} else {
				$source = $source_obj;
			}
			
			
			# detect source type
			my $st = $source_type;
			if ($st eq 'auto') {
				#autodetect source type
				if ($source =~ /^git:\/\//) {
					$st = 'git';
				} elsif (defined($pack_hash->{'git-server'})) {
					$st = 'git';
				} elsif ($source =~ /^http.*\.git/) {
					$st = 'git';
				} elsif ($source =~ /^ssh.*\.git/) {
					$st = 'git';
				} else {
					$st='download';
				}
				
			}
			
			my $temp_dir_obj = undef;
			my $temp_dir = $ptarget;
			my $sourcedir=undef;
			
			if ($st eq 'git' && defined($pack_hash->{'git-server'})) {
				$source = $pack_hash->{'git-server'}.$source;
			}
			
			if ($st eq 'git' || $st eq 'mercurial' || $st eq 'go') {
				
				
				
				if (defined $pack_hash->{'source-temporary'} && $pack_hash->{'source-temporary'}==1) {
					$temp_dir_obj = File::Temp->newdir( TEMPLATE => 'deployXXXXX' );
					$temp_dir = $temp_dir_obj->dirname.'/';
				}
				
				
				if ($st eq 'git') {
					$sourcedir = git_clone($source, $temp_dir);
				} elsif ($st eq 'mercurial') {
					$sourcedir = hg_clone($source, $temp_dir);
				} elsif ($st eq 'go') {
					#-fix -u  github.com/MG-RAST/AWE/...
					
					my $update_works = 0;
					if (defined $h->{'update'}) {
						if (systemp("go get -fix -u ".$source) == 0){
							$update_works = 1;
						}
					}
					
					if (defined $h->{'new'}) {
					#rm -rf gopath/src/github.com/
						if (defined $ENV{GOPATH} && -d $ENV{GOPATH} ) {
							my $src_dir = $ENV{GOPATH}.'/src/'.$source;
							while (substr($src_dir, -1, 1) eq'.') {
								chop($src_dir);
							}
							if (-d $src_dir) {
								systemp("rm -rf ".$src_dir)
							}
						}
						
					}
					if ($update_works == 0) {
						systemp("go get ".$source) == 0 or die;
					}
				} else {
					die;
				}
				
				
			} elsif ($st eq 'apt') {
				systemp("sudo apt-get --force-yes -y install ".$source);
			} elsif ($st eq 'download') {
				#simple download
				
				my $download_dir = undef ;
				if (defined $pack_hash->{'dir'}) {
					$download_dir = $packagedir;
				} else {
					$download_dir = $ptarget;
				}
				
				my $downloaded_file = downloadFile('url' => $source, 'target-dir' => $download_dir, 'target-name' => $source_filename);
				unless (defined $downloaded_file) {
					die;
				}
				
				if (defined $pack_hash->{'source-extract'} && $pack_hash->{'source-extract'} == 1) {
					if ($downloaded_file =~ /\.tar\.gz$/) {
						systemp("tar xvfz ".$downloaded_file." -C ".$download_dir);
					} else {
						die "unknown archive";
					}
				}
				
			} else {
				die;
			
			}
			
			
			
			# different build-types
			if (defined($pack_hash->{'build-exec'})) {
				my $exec = $pack_hash->{'build-exec'};
				if (defined $sourcedir) {
					$exec =~ s/\$\{source\}/$sourcedir/g;
				}
				print "build-exec:\n";
				systemp($exec) == 0 or die;
				
			} elsif ($build_type eq 'make'){
				die;
			} else {
				# no build
			}
			
			
				
			
			
			
			#temp_dir goes out of scope here
		}
		
	}


	if (defined $pack_hash->{'set-env'}) {
		my $env_pairs = $pack_hash->{'set-env'};
		foreach my $key (keys %{$env_pairs} ) {
			setenv($key, $env_pairs->{$key}) ;
		}
	}
	
	if (defined $pack_hash->{'exec'}) {
		
		my @execs;
		if (ref($pack_hash->{'exec'}) eq 'ARRAY') {
			@execs = @{$pack_hash->{'exec'}};
		} else {
			@execs = ($pack_hash->{'exec'});
		}
		foreach my $exec (@execs) {
			
			print "exec:\n";
			systemp($exec) == 0 or die;
		}
	}
	
	if (defined $pack_hash->{'test'}) {
		print "test_exec:\n";
		systemp($pack_hash->{'test'}) == 0 or die;
	}
	

	unless ($package eq "subpackage") {
		$already_installed{$package} = 1;
	}
	
	#if (defined $pack_hash->{'finish-package'}) {
	#	if (ref($pack_hash->{'finish-package'}) eq 'ARRAY' ) {
	#		return $pack_hash->{'finish-package'};
	#	} else {
	#		return ($pack_hash->{'finish-package'});
	#	}
	#}
	
}

#############################################################


GetOptions ($h, 'target=s', 'version=s', 'update', 'new', 'root', 'all', 'repository');

unless ( @ARGV  || @ARGV > 1) {
	print "usage: deploy_software.pl [--target=] [packages]\n";
	#print "default target=$target\n";
	print "example: deploy_software.pl --target=/home/ubuntu/ aweclient\n";
	print "     --update to update existing repositories if possible \n";
	print "     --new to delete repositories before cloning \n";
	print "     --all to install all packages in repository \n";
	exit 1;
}


if (defined $h->{'update'} && defined $h->{'new'} ) {
	die;
}


if ( ! defined($h->{'root'}) && ($< == 0) ) {
	print "error: please do not run me as root unless you know what you are doing.\n";
	exit(0);
}

if (defined($h->{'root'}) &&  ($< != 0) ) {
	print "error: you gave option --root but you are not root.\n";
	exit(0);
}

#my $target = "/kb/runtime/";

# in case we use cached installation
#maybe add to .bashrc : source /home/ubuntu/data/qiime_software/activate.sh

#cd data && wget ftp://ftp.metagenomics.anl.gov/data/misc/private/wolfgang_epaghsmh/qiime_software.tar.gz


if (defined $ENV{'TARGET'} ) {
	$target = $ENV{'TARGET'};
}

if (defined $h->{'target'}) {
	$target = $h->{'target'};
}

if (defined $target) {
	unless (-d $target) {
		die "target \"$target\" not found!\n";
	}
}

if (substr($target, -1, 1) ne "/") {
	$target .= "/";
}



my $package_rules_json = <<'EOF';
{
	xxxxx
}
EOF

#my $package_rules = decode_json($package_rules_json);
my $package_rules = undef;


my $use_repository;
if (defined $h->{'repository'}) {
	$use_repository = $h->{'repository'};
} else {
	$use_repository = $default_repository;
}

print "fetching repository: ".$use_repository."\n";
my $curl_cmd = "curl -S -s -o /dev/stdout ".$use_repository;
$package_rules_json = `$curl_cmd`;
chomp($package_rules_json);


$package_rules = decode_json($package_rules_json);


datastructure_walk($package_rules, \&process_scalar, undef); # for my "environment variables"... ;-)



my @package_list = @ARGV;

print "target: $target\n";




foreach my $package_string (@package_list) {
	
	my ($package, $version, $package_args_ref) = parsePackageString($package_string);
	
	print 'ref0: '.ref($version)."\n";
	
	install_package($package_rules, $package, $version, $package_args_ref);
	
}

print "all packages installed.\n";










