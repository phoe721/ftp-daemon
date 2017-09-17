#!/usr/bin/perl
use Time::Format qw(%time %strftime %manip);
use Net::FTP;
use File::Path qw(mkpath);
use Filesys::Df;
use File::Copy;
use Data::Dumper;
use Test::Simple tests => 100;

##### Show Log Output #####
$output = 1;
###########################

print "##### Test valid minute value #####\n";
ok(validate_cron("Server", "5", "*", "*") eq 1, "validate_cron 5 * *");  
ok(validate_cron("Server", "0", "*", "*") eq 1, "validate_cron 0 * *");  
ok(validate_cron("Server", "9", "*", "*") eq 1, "validate_cron 9 * *");  
ok(validate_cron("Server", "10", "*", "*") eq 1, "validate_cron 10 * *");  
ok(validate_cron("Server", "59", "*", "*") eq 1, "validate_cron 59 * *");  
ok(validate_cron("Server", "*/2", "*", "*") eq 1, "validate_cron */2 * *");  
ok(validate_cron("Server", "*/59", "*", "*") eq 1, "validate_cron */59 * *");  

print "##### Test invalid minute value #####\n";
ok(validate_cron("Server", "*", "*", "*") eq 0, "validate_cron * * *");  
ok(validate_cron("Server", "-1", "*", "*") eq 0, "validate_cron -1 * *");  
ok(validate_cron("Server", "60", "*", "*") eq 0, "validate_cron 60 * *");  

print "##### Test valid hour value #####\n";
ok(validate_cron("Server", "10", "0", "*") eq 1, "validate_cron 10 0 *");  
ok(validate_cron("Server", "10", "1", "*") eq 1, "validate_cron 10 1 *");  
ok(validate_cron("Server", "10", "23", "*") eq 1, "validate_cron 10 23 *");  
ok(validate_cron("Server", "10", "*", "*") eq 1, "validate_cron 10 * *");  
ok(validate_cron("Server", "10", "*/5", "*") eq 1, "validate_cron 10 */5 *");  
ok(validate_cron("Server", "10", "*/23", "*") eq 1, "validate_cron 10 */23 *");  

print "##### Test invalid hour value #####\n";
ok(validate_cron("Server", "10", "-1", "*") eq 0, "validate_cron 10 -1 *");  
ok(validate_cron("Server", "10", "*/0", "*") eq 0, "validate_cron 10 */0 *");  
ok(validate_cron("Server", "10", "*/24", "*") eq 0, "validate_cron 10 */24 *");  

print "##### Test valid day value #####\n";
ok(validate_cron("Server", "10", "5", "1") eq 1, "validate_cron 10 5 1");  
ok(validate_cron("Server", "10", "5", "31") eq 1, "validate_cron 10 5 31");  
ok(validate_cron("Server", "10", "5", "30") eq 1, "validate_cron 10 5 30");  
ok(validate_cron("Server", "10", "5", "*") eq 1, "validate_cron 10 5 *");  
ok(validate_cron("Server", "10", "5", "*/5") eq 1, "validate_cron 10 5 */5");  
ok(validate_cron("Server", "10", "5", "*/10") eq 1, "validate_cron 10 5 */10");  
ok(validate_cron("Server", "10", "5", "*/31") eq 1, "validate_cron 10 5 */31");  

print "##### Test invalid day value #####\n";
ok(validate_cron("Server", "10", "5", "-1") eq 0, "validate_cron 10 5 -1");  
ok(validate_cron("Server", "10", "5", "*/0") eq 0, "validate_cron 10 5 */0");  
ok(validate_cron("Server", "10", "5", "*/32") eq 0, "validate_cron 10 5 */32");  

print "##### Test valid day range #####\n";
ok(validate_range("Server", "1") eq 1, "validate_range 1");
ok(validate_range("Server", "5") eq 1, "validate_range 5");
ok(validate_range("Server", "100") eq 1, "validate_range 100");

print "##### Test invalid day range #####\n";
ok(validate_range("Server", "a") eq 0, "validate_range a");
ok(validate_range("Server", "-1") eq 0, "validate_range -1");
ok(validate_range("Server", "-100") eq 0, "validate_range -100");

print "##### Test create_dir #####\n";
$config_file2 = "/root/scripts/test/test1.conf";
%cfg2 = ();
%cfg2 = &fill_ini($config_file2);
ok(create_dir("TEST1") eq 1, "create_dir TEST1");
`rm -r /root/scripts/test/TEST1/`;
ok(create_dir("TEST2") eq 1, "create_dir TEST2");
`rm -r /root/scripts/test/TEST2/`;
ok(create_dir("TEST3") eq 0, "create_dir TEST3");
`rm -r /root/scripts/test/TEST3/`;
ok(create_dir("TEST4") eq 0, "create_dir TEST4");

print "##### Test ftp_connect #####\n";
$config_file2 = "/root/scripts/test/test2.conf";
%cfg2 = ();
%cfg2 = &fill_ini($config_file2);
$ftp_debug = 0;
$ftp_timeout = 1;
$server_name = "TEST1";
ok(ftp_connect() eq 1, "ftp_connect TEST1");
$server_name = "TEST2";
ok(ftp_connect() eq 1, "ftp_connect TEST2");
$server_name = "TEST3";
ok(ftp_connect() eq 0, "ftp_connect TEST3");
$server_name = "TEST4";
ok(ftp_connect() eq 0, "ftp_connect TEST4");
$server_name = "TEST5";
ok(ftp_connect() eq 0, "ftp_connect TEST5");

print "##### Test ftp_list #####\n";
$config_file2 = "/root/scripts/test/test2.conf";
%cfg2 = ();
%cfg2 = &fill_ini($config_file2);
$ftp_debug = 0;
$ftp_timeout = 1;
$server_name = "TEST1";
ftp_connect();
ok(ftp_list("/var/log/"), "ftp_list /var/log/");
mkpath("/root/scripts/test/TEST1/", 0, "0444");
ok(ftp_list("/root/scripts/test/TEST1/") == "", "ftp_list /root/scripts/test/TEST1/");
`rm -r /root/scripts/test/TEST1/`;
# Bug 2015/06/08: ftp_list should return empty string if fail to change directory

print "##### Test check_time #####\n";
$time_range = 2;
ftp_connect();
ok(check_time("/var/log/secure") eq 1, "check_time /var/log/secure");
ok(check_time("/var/log/secure-20150525") eq 0, "check_time /var/log/secure-20150525");
ok(check_time("/var/log/abc") eq 0, "check_time /var/log/abc");

print "##### Test check_space #####\n";
$disk_limit = 500 * 1000;
ok(check_space("/home/", "test") eq 1, "check_space /home/");

print "##### Test ftp_get #####\n";
$splunk = 1;
ftp_connect();
ok(ftp_get("/var/log/secure", "/root/scripts/test/backup/secure", "/root/scripts/test/splunk/secure") eq 1, "ftp_get /var/log/secure, splunk = 1");
ok(-e "/root/scripts/test/backup/secure", "ftp_get file exists in /root/scripts/test/backup/secure, splunk = 1");
ok(-e "/root/scripts/test/splunk/secure", "ftp_get file exists in /root/scripts/test/splunk/secure, splunk = 1");
`rm /root/scripts/test/backup/secure`;
`rm /root/scripts/test/splunk/secure`;
$splunk = 0;
ok(ftp_get("/var/log/secure-20150525", "/root/scripts/test/backup/secure-20150525", "/root/scripts/test/splunk/secure-20150525") eq 1, "ftp_get /var/log/secure-20150525, splunk = 0");
ok(-e "/root/scripts/test/backup/secure-20150525", "ftp_get file exists in /root/scripts/test/backup/secure-20150525, splunk = 0");
ok(!-e "/root/scripts/test/splunk/secure-20150525", "ftp_get file not exists in /root/scripts/test/splunk/secure-20150525, splunk = 0");
`rm /root/scripts/test/backup/secure-20150525`;

sub gettime {
	return "$time{'yyyy/mm/dd hh:mm:ss'}";
}

sub validate_cron {
	my $server = $_[0];
	my $minute = $_[1];
	my $hour = $_[2];
	my $day = $_[3];

	if ($minute =~ /^([1-5][0-9]|[0-9])$/) {
		# Valid minute format 1
	} elsif ($minute =~ /^\*\/([1-5][0-9]|[1-9])$/) {
		# Valid minute format 2
	} else {
		logfile("$server: crontab minute \"$minute\" is invalid!", 0);
		return 0;
	}

	if ($hour eq "*") { 
		# Valid hour format 1
	} elsif ($hour =~ /^(2[0-3]|1[0-9]|[0-9])$/) {
		# Valid hour format 2
	} elsif ($hour =~ /^\*\/(2[0-3]|1[0-9]|[1-9])$/) {
		# Valid hour format 3
	} else {
		logfile("$server: crontab hour \"$hour\" is invalid!", 0);
		return 0;
	}
		
	if ($day eq "*") { 
		# Valid day format 1
	} elsif ($day =~ /^(3[0-1]|[1-2][0-9]|[1-9])$/) {
		# Valid day format 2
	} elsif ($day =~ /^\*\/(3[0-1]|[1-2][0-9]|[1-9])$/) {
		# Valid day format 3
	} else {
		logfile("$server: crontab day \"$day\" is invalid!", 0);
		return 0;
	}
	return 1;
}

sub validate_range {
	my $server = $_[0];
	my $time_range = $_[1];
	if ($time_range =~ /^\d+$/) {
		# Valid time range	
	} else {
		logfile("$server: invalid time range \"$time_range\"!", 0);
		return 0;
	}
	return 1;
}

sub create_dir {
	my $server_name = $_[0];
	my $dir = $cfg2{$server_name}->{localdir};
	my $dir2 = $cfg2{$server_name}->{splunkdir};

	# Check if local directory exists. If not, create it
	if ($dir eq "") {
		logfile("Local directory is not defined, check configuration file", 0);
		return 0;
	} elsif (!-d $dir) {
		if (! mkpath($dir)) {
			logfile("Failed to create directory: $dir", 0);
			return 0;
		}
	} 
	
	if ($dir2 eq "") {
		logfile("Splunk directory is not defined, check configuration file", 0);
		return 0;
	} elsif (!-d $dir2) {
		if (! mkpath($dir2)) {
			logfile("Failed to create directory: $dir2", 0);
			return 0;
		}
	}
	return 1;
}

sub ftp_connect {
	$ftphost = $cfg2{$server_name}->{ftphost};
	$passive = $cfg2{$server_name}->{passive};
	$username = $cfg2{$server_name}->{username};
	$password = $cfg2{$server_name}->{password};

	# FTP to Remote Host 
    logfile("Connecting to $ftphost", 2);
    $ftp = Net::FTP->new("$ftphost", Debug => $ftp_debug, Timeout => $ftp_timeout, Passive => $passive);
    if ($ftp) {
        logfile("Connected to FTP Server $ftphost", 2);
        $ftp->login("$username","$password");
        $ftp_code = $ftp->code();
        logfile("Login $ftphost (code: $ftp_code)", 2);
        if ($ftp_code eq "230") {
            $ftp->type("I");
			return 1;
        } else {
            logfile("Could not login to $ftphost!", 0);
			return 0;
        }
    } else {
        logfile("Could not connect to FTP Server $ftphost", 0);
		return 0;
    }
}

sub ftp_list {
	# Change working directory & Get file list
	$remote_path = $_[0];
	$ftp->cwd("$remote_path");
	$ftp_code = $ftp->code();
	@file_list = ();
	logfile("Change working directory $remote_path (code: $ftp_code)", 2);
	if ($ftp_code eq "250") {
		# List files in remote directory
		@file_list = $ftp->ls("$remote_path");
		$ftp_code = $ftp->code();
		logfile("List files in working directory $remote_path (code: $ftp_code)", 2);
		if ($ftp_code eq "226") {
			$size = @file_list;
			if ($size == 0) {
				logfile("No log files in $remote_path", 0);
				return @file_list;
			} else {
				return @file_list;
			}
		} else {
			logfile("Could not list files in $remote_path", 0);
			return @file_list;
		}
	} else {
		logfile("Could not change directory to $remote_path", 0);
		return @file_list;
	}
}

sub check_time {
	$file = $_[0];
	$mdtm = $ftp->mdtm($file);
	$collect_time = time - ($time_range * 86400);	
	$collect_time_datestr = $strftime{"%Y-%m-%d %H:%M:%S", $collect_time}; 
	$mdtm_datestr = $strftime{"%Y-%m-%d %H:%M:%S", $mdtm};
	logfile("Collect file after: $collect_time_datestr, File Modified Time: $mdtm_datestr", 2);
	if ($mdtm > $collect_time) {
		return 1;
	} else {
		logfile("File $file is not in the time range to collect, ignore", 2);
		return 0;
	}
}

sub check_space {
	my $dir = $_[0];
	my $file = $_[1];
	my $disk = df($dir);
	my $avail = $disk->{bavail};
	if ($avail > $disk_limit) {
		logfile("Disk available: $avail KB, Disk limit: $disk_limit KB", 2);
		return 1;
	} else {
		logfile("No disk space available for $file", 0);
		return 0;
	}
}

sub ftp_get {
	$file_to_get = $_[0];
	$file_to_write = $_[1];
	$file_to_copy = $_[2];
	$rmdtm = $ftp->mdtm($file_to_get);
	$ftp->get($file_to_get, $file_to_write);
	$ftp_code = $ftp->code();
	logfile("Get file $file_to_get (code: $ftp_code)", 2);
	if ($ftp_code eq "226") {
		$remote_size = $ftp->size($file_to_get);
		$local_size = (stat($file_to_write))[7];
		logfile("Remote file size: $remote_size Bytes, Local file size: $local_size Bytes", 2);
		if ($remote_size == $local_size) {
			utime(time(), $rmdtm, $file_to_write);
			$lmdtm = (stat($file_to_write))[9];
			logfile("Remote file modified time: " . $strftime{"%Y-%m-%d %H:%M:%S", $rmdtm} . ", Local file modified time: " . $strftime{"%Y-%m-%d %H:%M:%S", $lmdtm}, 2);
			logfile("Collect the file $file_to_write OK", 1);

			if ($splunk) {
				if (copy($file_to_write, $file_to_copy)) {
					utime(time(), $rmdtm, $file_to_copy);
					logfile("Copying $file_to_write to $file_to_copy for splunk", 1);
				} else {
					logfile("Fail to copy $file_to_write to $file_to_copy for splunk", 0);
				}
			}
			return 1;
		} else {
			logfile("File size does not match", 0);
			`/bin/rm -f $file_to_write`;
			return 0;
		}
	} else {
		$message = $ftp->message;
		$message =~ s/\n/ /g;
		logfile("FTP error message: " . $message, 0);
		logfile("Could not get the file $file_to_get (code: $ftp_code)", 0);
		if ($ftp_code eq "000") {
			logfile("FTP server Timeout, reconnecting", 0);
			$ftp->quit;
			sleep($sleep);
			ftp_connect($server_name);
		}
		return 0;
	}
}

sub fill_ini (\$) {
	my ($array_ref) = @_;
	my $configfile = $array_ref;
	my %hash_ref;

	#print "SUB:CONFIGFILE:$configfile\n";
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

	return %hash_ref;
}

sub logfile {
	$timestring = gettime();
    @writestring = @_;
	
	if ($output) {
		print "$timestring $writestring[0]\n";
	}
}
