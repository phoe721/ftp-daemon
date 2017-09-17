#!/usr/bin/perl
use File::Find;
use File::Copy;
use File::Basename;
use Date::Format;

##### moving_master.pl
# Version 1.0:  Written by Aaron Lin for CHT 05-29-2015 
#####
$version = '1.0';

##### Define and read INI file
$configfile = '/home/logs/cleanup_master/moving_master.ini';
%cfg = ();
%cfg = &fill_ini($configfile);
#####

##### Bring in variables
$log_dir = $cfg{'system'}->{'log_dir'};
$target_dir = $cfg{'system'}->{'target_dir'};
$max_depth = $cfg{'system'}->{'max_depth'};
#####

##### Define Log file
$logfile = $cfg{'system'}->{'log_dir'} . 'moving_master-' . time2str("%Y-%m-%d", time) . '.log';
#####

##### Start Run
$pid_no = $$;
logger("::::: START RUN with PID: $pid_no VERSION $version");

# Init directory temp array
@dir_queue;
#####

while (my ($key, $value) = each %{ $cfg{'partitions'} } ) {
	$check_dir= $key;
	$max_days = $value;
	$moving_dir = $check_dir. '/' . $target_dir;
	create_dir($moving_dir);
	$AGE = $max_days * 86400;
	logger("INFO:Scanning $check_dir for files less than $max_days days old");
	find({ preprocess => \&preprocess, wanted => \&wanted_file_check }, $check_dir);
}

logger(":::: End of Run");

exit();

# Subroutines
sub wanted_file_check {
	my $filename = $File::Find::name;
	my $targetfile = $moving_dir . '/'. basename($filename);
	if (-f $filename) {
		# We only delete for files ending with .log,.log.gz,.tar.gz,.tgz,.txt,.txt.gz,.xls,.xls.gz,secure*,.tar
		if (($filename =~ /\.log\.gz$/) || ($filename =~ /\.log$/) || ($filename =~ /\.tar.gz$/) || ($filename =~ /\.tgz$/) || ($filename =~ /\.txt$/) || ($filename =~ /\.txt.gz$/) || ($filename =~ /\.xls$/) || ($filename =~ /\.xls.gz/) || ($filename =~ /secure.*/) || ($filename =~ /\.tar$/)) {
			my $nowtime = time();
			my @filestats = stat($filename);
			my $filedate = time2str("%Y-%m-%d %H:%M:%S", $filestats[9]);
			if (($nowtime - $filestats[9]) < $AGE) {
				logger("COPYING:$filename DESTINATION:$targetfile FILEDATE:$filedate AGE:$max_days");
				copy($filename, $targetfile);
			} else {
				logger("DEBUG:$filename is greater than AGE:$max_days FILEDATE $filedate, not moving file");
			} 
		} else {
			logger("INFO:$filename does not match file type, skipping file");
		}
	}

	if (-d $filename) {
		logger("INFO:$filename is a directory, skipping directory");
	}
}

sub logger {
	@log_array = @_;
	$log_line = $log_array[0];
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900; $mon++; $mon = sprintf("%02d", $mon); $mday = sprintf("%02d", $mday);
	$sec = sprintf("%02d", $sec); $min = sprintf("%02d", $min); $hour = sprintf("%02d", $hour);
	$log_datestring = $year . '-' . $mon . '-' . $mday;
	$log_timestring = $log_datestring . ' ' . $hour . ':' . $min . ':' . $sec;
	
	open(LOGFILE,">> $logfile");
	print LOGFILE "[$log_timestring] $log_line\n";
	close(LOGFILE);

	print "[$log_timestring] $log_line\n";

	return;
}

sub fill_ini (\$) {
	my ($array_ref) = @_;
	my $configfile = $array_ref;
	my %hash_ref;
		
	# print "SUB:CONFIGFILE:$configfile\n";
	open(CONFIGFILE,"< $configfile");
	my $main_section = 'main';
	my ($line,$copy_line);
	while ($line=<CONFIGFILE>) {
		chomp($line);
		$line =~ s/\n//g;
		$line =~ s/\r//g;
		$copy_line = $line;
		if ($line =~ /^#/) {
			# Ignore starting hash
		} else {
			if ($line =~ /\[(.*)\]/) {
				# print "SUB:FOUNDSECTION:$1\n";
				$main_section = $1;
			}
			if ($line eq "") {
				# print "SUB:BLANKLINE\n";
			}
			if ($line =~ /(.*)=(.*)/) {
				my ($key,$value) = split('=', $copy_line);
				$key =~ s/ //g;
				$key =~ s/\t//g;
				$value =~ s/^\s+//g;
				$value =~ s/\s+$//g;
				# print "SUB:KEYPAIR:$main_section -> $key -> $value\n";
				$hash_ref{"$main_section"}->{"$key"} = $value; 
			}
		}
	}
	close(CONFIGFILE);
	# $ftphost = $hash_ref{'ftp'}->{'ftphost'};
	# print "SUB:FTPHOST:$ftphost\n";
	return %hash_ref;
}

sub create_dir {
	my $dirname = shift;
	if (!-d $dirname) {
		my $check = mkdir($dirname);
		if (!$check) {
			logger("DEBUG:Failed to create directory: $dirname");
		} else {
			logger("DEBUG:Directory created: $dirname");
		}
	}	
	return $check;
}

sub is_folder_empty {
    my $dirname = shift;
    opendir(my $dh, $dirname) or die "Not a directory";
    return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
}

sub preprocess {
    my $depth = $File::Find::dir =~ tr[/][];
    return @_ if $depth < $max_depth;
    return grep { not -d } @_ if $depth == $max_depth;
    return;
}
