#!/usr/bin/perl
use File::Find;
use Date::Format;

##### cleanup_master.pl
# Version 1.0:  Written by Peter Cheng for FET 2013-09-30
# Version 2.0:  Updated to support directories which need removing, but cannot remove on initial run because there are files still in there
# Version 2.1: 	Fixed bug in deleting queue directories
#####
$version = '2.1';

##### Define and read INI file
$configfile = '/home/logs/cleanup_master/cleanup_master.ini';
%cfg = ();
%cfg = &fill_ini($configfile);
#####

##### Bring in variables
$delete_confirm = $cfg{'system'}->{'delete'};
$log_dir = $cfg{'system'}->{'log_dir'};
if (!-d $log_dir) {
	mkdir($log_dir);
}
#####


##### Define Log file
$logfile = $cfg{'system'}->{'log_dir'} . 'cleanup_master-' . time2str("%Y-%m-%d", time) . '.log';
#####

##### Start Run
$pid_no = $$;
logger("::::: START RUN with PID: $pid_no VERSION $version");
# Init directory temp array
@dir_queue;
#####

while (my ($key, $value) = each %{ $cfg{'partitions'} } ) {
	$check_directory = $key;
	$max_days = $value;
	$AGE = $max_days * 86400;
	logger("[INFO] Scanning $check_directory for files older than $max_days days");
	find (\&wanted_file_check, $check_directory);
}

logger("[DEBUG] Deleting directory queue");
foreach $filename(@dir_queue) {
	# Double check if the directory is empty and that we have a directory type
	if (-d $filename) {
		if (is_folder_empty($filename)) {
			if ($delete_confirm == 1) {
				logger("[DELETE] Deleting directory $filename from temp queue");
				unlink $filename;
			} else {
				logger("[DEBUG] $filename should be removed DIRDATE:$filedate AGE:$max_days, but delete=0, not removing directory");
			}


		} else {
			logger("[ERROR] $filename is not an empty directory, not deleting");
		}
	} else {
		logger("[ERROR] $filename is not a directory");
	}
}


logger("::::: End of Run");

exit();

sub wanted_file_check {

	my $filename = $File::Find::name;

	if (-f $filename) {

		# We only delete for files ending with .log,.log.gz,.tar.gz,.tgz,.txt,.txt.gz,.xls,.xls.gz,secure*,.tar,.csv
		if (($filename =~ /\.log\.gz$/) || ($filename =~ /\.log$/) || ($filename =~ /\.tar.gz$/) || ($filename =~ /\.tgz$/) || ($filename =~ /\.txt$/) || ($filename =~ /\.txt.gz$/) || ($filename =~ /\.xls$/) || ($filename =~ /\.xls.gz/) || ($filename =~ /secure.*/) || ($filename =~ /\.tar$/) || ($filename =~ /\.csv$/)) {

			my $nowtime = time();
			my @filestats = stat($filename);
			my $filedate = time2str("%Y-%m-%d %H:%M:%S", $filestats[9]);
			if (($nowtime - $filestats[9]) > $AGE) {
				if ($delete_confirm == 1) {
					logger("[DELETE] Deleting file $filename FILEDATE:$filedate AGE:$max_days");
					unlink $filename;
				} else {
					logger("[DEBUG] $filename should be deleted FILEDATE:$filedate AGE:$max_days, but delete=0, not deleting file");
				}
			} else {
				logger("[DEBUG] $filename is less than AGE:$max_days FILEDATE $filedate, not deleting file");
			} 

		} else {
			
			logger("[INFO] $filename does not match file type, skipping file");
		}
	}

	if (-d $filename) {
			#logger("[INFO] $filename is a directory");
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

sub fill_ini (\$)

{
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



sub is_folder_empty {
    my $dirname = shift;
    opendir(my $dh, $dirname) or die "Not a directory";
    return scalar(grep { $_ ne "." && $_ ne ".." } readdir($dh)) == 0;
}
