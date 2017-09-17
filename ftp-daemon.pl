#!/usr/bin/perl
use File::Basename;
use Time::Format qw(%time %strftime %manip);
use Net::FTP;
use File::Path qw(mkpath);
use File::Copy;
use Filesys::Df;
use Schedule::Cron;
use Sys::Hostname;
use Crypt::ECB;
use Crypt::Blowfish;
use Digest::MD5 qw(md5 md5_hex md5_base64);

##################################################################################
# Initialization
#########i#########i#########i####################################################

# Get program settings
$config_file = "/root/scripts/rssftp.conf";
if (-e $config_file) {
	%cfg = ();
	%cfg = &fill_ini($config_file);
	$program_name = $cfg{runtime}->{program_name};
	$version = $cfg{runtime}->{version};
	$version_date = $cfg{runtime}->{version_date};
	$license_key_file = $cfg{runtime}->{license_key_file};
	$license_host = hostname;
	$pidfile = $cfg{runtime}->{pidfile};
	$piddir = $cfg{runtime}->{piddir};
	$daemon_mode = $cfg{runtime}->{daemon_mode};
	$disk_limit = $cfg{runtime}->{disk_limit} * 1000;
	$ftp_debug = $cfg{runtime}->{ftp_debug};
	$ftp_timeout = $cfg{runtime}->{ftp_timeout};
	$retry_max = $cfg{runtime}->{retry_max};
	$delay = $cfg{runtime}->{delay};
	$logfile = $cfg{runtime}->{logfile};
	$errorlog = $cfg{runtime}->{errorlog};
	$uselog = $cfg{runtime}->{uselog};
	$log_level = $cfg{runtime}->{log_level};
	$collect = $cfg{runtime}->{collect};
	$sleep = $cfg{runtime}->{sleep_time};
} else {
	logfile("File does not exist: $config_file" , 0);
	exit(1);
}

# Get ftp server list
$config_file2 = "/home/logs/rssftp/rssftpserver.conf";
if (-e $config_file2) {
	%cfg2 = ();
	%cfg2 = &fill_ini($config_file2);
	$ftp_server = $cfg2{ftp_server}->{name};
	@server_list = split(/,/, $ftp_server);
} else {
	logfile("File does not exist: $config_file2" , 0);
	exit(1);
}

# Check if license is valid
check_license();

# Check if process pid directory exists
if (!-d $piddir) {
	if (mkdir($piddir)) {
		logfile("Directory created: $piddir", 2);
	} else {
		logfile("Failed to create directory: $piddir", 0);
		exit(1);
	}
}

# Create PID file
$pidno = $$;
`/bin/echo $pidno > $pidfile`;
if (!-e $pidfile) {
	logfile("Failed to create PID file: $pidfile", 0);
	exit(1);
}

##################################################################################
# Start program
##################################################################################
logfile("::::: Starting $program_name with $config_file PID=$pidno", 1);

# Kill ongoing daemons 
&cleanup();

# Generate daemons to collect logs
if ($collect) {
	for (my $i = 0; $i < @server_list; $i++) {
		if (create_dir($server_list[$i])) {
			if ($cfg2{$server_list[$i]}->{enable}) {
				$minute = $cfg2{$server_list[$i]}->{cron_min};
				$hour = $cfg2{$server_list[$i]}->{cron_hour};
				$day = $cfg2{$server_list[$i]}->{cron_day};
				$time_range = $cfg2{$server_list[$i]}->{time_range};
				my $check = validate_cron($server_list[$i], $minute, $hour, $day);
				my $check2 = validate_range($server_list[$i], $time_range); 
				if ($check && $check2) {
					logfile("Going to collect logs: $server_list[$i]", 2);
					if ($daemon_mode) {
						$cron[$i] = new Schedule::Cron(\&collect_log, nofork=>1, skip=>1);
						$cron[$i]->add_entry("$minute $hour $day * *", $server_list[$i], 0);
						$cron[$i]->run(detach=>1, pid_file=>"$piddir"."$server_list[$i].pid", nofork=>1, skip=>1);
					} else {	
						collect_log($server_list[$i], 0);
					}
				}
			} else {
				logfile("Not collecting logs ($server_list[$i] disabled)", 2);
			}
		}
	}
}

logfile("::::: End $program_name",1);

# Exit the program
exit();

##################################################################################
# End program
##################################################################################

sub check_license {
	# Check license key
	if (-e $license_key_file) {
		open(KEYFILE,"< $license_key_file");
		$keyline=<KEYFILE>;
		chomp($keyline);
		close(KEYFILE);

		##### Generate Licence Key #####
		# Encryption Key
		$key = 'acom33131416';

		$crypt = Crypt::ECB->new;
		$crypt->padding(PADDING_AUTO);
		$crypt->cipher('Blowfish') || die $crypt->errstring;
		$crypt->key($key);
		$crypt_data = 'RSS_FTP:' . $license_host;

		# print "PLAIN KEY: $crypt_data\n";
		$enc = $crypt->encrypt("$crypt_data");
		$digest_enc = md5_base64($enc);
		################################

		if ($digest_enc eq $keyline) {
			# Valid Key
		} else {
			print "\n";
			print "RSS FTP COLLECTOR\n";
			print "VERSION: $version ($version_date)\n";
			print "ERROR:   The license key $keyline is not valid!\n";
			print "INFO:    Did you change the hostname or the server of installation?\n";
			print "INFO:    Please contact support if you think there is a problem\n";
			print "Copyright(C) Acom Networks Technology Co. Ltd.\n";
			print "\n";
			exit();
		}
	} else {
		print "\n";
		print "RSS FTP COLLECTOR\n";
		print "VERSION: $version ($version_date)\n";
		print "ERROR:   Missing $license_key_file License Key File\n";
		print "MESG:    Please contact support to obtain a valid license key or install the key file\n";
		print "Copyright(C) Acom Networks Technology Co. Ltd.\n";
		print "\n";
		exit();
	}
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

sub ftp_longlist {
	# Change working direcotyr & Get long listing of file list
	$remote_path = $_[0];
	$ftp->cwd("$remote_path");
	$ftp_code = $ftp->code();
	logfile("Change working directory $remote_path (code: $ftp_code)", 2);
	if ($ftp_code eq "250") {
		# List files in remote directory
		@file_list = $ftp->dir("$remote_path");
		$ftp_code = $ftp->code();
		logfile("List files in working directory $remote_path (code: $ftp_code)", 2);
		if ($ftp_code eq "226") {
			$size = @file_list;
			if ($size == 0) {
				logfile("No files in $remote_path", 0);
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
		return @file_list ;
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
					logfile("Copying to $file_to_copy for splunk", 1);
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

sub check_update {
	$rfile = $_[0];
	$lfile = $_[1];
	$rmdtm = $ftp->mdtm($rfile);	
	$lmdtm = (stat($lfile))[9];
	if ($rmdtm > $lmdtm) {
		logfile("Local file modified time: " . $strftime{"%Y-%m-%d %H:%M:%S", $rmdtm} . ", Remote file modified time: " . $strftime{"%Y-%m-%d %H:%M:%S", $lmdtm}, 2);
		logfile("File $rfile has newer modified time, update $lfile", 2);
		return 1;
	} else {
		logfile("File $rfile has already been collected", 2);
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

sub collect_log {
	# Bring in server config using the server name 
	$server_name = $_[0];
	$retry = $_[1];
	$splunk = $cfg2{$server_name}->{splunk};
	$time_range = $cfg2{$server_name}->{time_range};
	$localdir = $cfg2{$server_name}->{localdir};
	$splunkdir = $cfg2{$server_name}->{splunkdir};
	$remotedir = $cfg2{$server_name}->{remotedir};
	$remotefile = $cfg2{$server_name}->{remotefile};
	@remotefile_list = split(/,/, $remotefile);
	$list_size = @remotefile_list;
	$success = 0;
	$fail = 0;
	$retrieved = 0;

	# Connect to FTP
	$ftpsuccess = ftp_connect($server_name);

	# If FTP OK, attempts to retrieve file
	if ($ftpsuccess == 1 && $list_size > 0) {
		for (my $j = 0; $j < @remotefile_list; $j++) {
			if ($remotefile_list[$j] =~ /^~/) {	
				# Set remote path and remote file
				$remotedir =~ s/\/$//;
				$remotefile_list[$j] =~ s/^~//g;
				$remote_path = $remotedir . dirname($remotefile_list[$j]);
				$remote_file = $remotedir . $remotefile_list[$j];
	
				# Get Remote file pattern
				$remote_file_pattern = $remotedir . $remotefile_list[$j];
				$remote_file_pattern =~ s/\./\\\./g;
				$remote_file_pattern =~ s/\(\*\)/\.*/g;
			} else {
				# Set remote path and remote file
				$remote_path = dirname($remotefile_list[$j]);
				$remote_file = $remotefile_list[$j];

				# Get Remote file pattern
				$remote_file_pattern = $remotefile_list[$j];
				$remote_file_pattern =~ s/\./\\\./g;
				$remote_file_pattern =~ s/\(\*\)/\.*/g;
			}

			# Get list of remote files
			@file_list = ftp_list($remote_path);
			@match_list = grep(/^$remote_file_pattern$/, @file_list);
			my $size = @match_list;
			if ($size > 0) {
				# Get remote directory matched files 
				for (my $i = 0; $i < @match_list; $i++) {
					# Set the file path 
					$file_to_write = $localdir . basename($match_list[$i]);
					$file_to_copy = $splunkdir . basename($match_list[$i]);

					# Set local file pattern
					$local_file_pattern = $file_to_write;

					# Check time range
					if ($time_range != 0) {
						if (!check_time($match_list[$i])) {
							next;
						}
					}
					
					# Check if it has been collected or not
					if (!-e $local_file_pattern) {
						# Check disk space
						if (check_space($localdir, $match_list[$i])) {
							# Get the File
							if (ftp_get($match_list[$i], $file_to_write, $file_to_copy)) {
								$success++;
							} else {
								$fail++;
							}
						} else {
							$fail++;
						} 
					} else {
						if (check_update($match_list[$i], $local_file_pattern)) {
							# Check disk space
							if (check_space($localdir, $match_list[$i])) {
								# Get the File
								if (ftp_get($match_list[$i], $file_to_write, $file_to_copy)) {
									$success++;
								} else {
									$fail++;
								}
							} else {
								$fail++;
							} 
						} else {
							$retrieved++;
						}
					}
				} 
			} elsif ($size == 0) {
				logfile("Could not collect $remote_file!", 0);
				$fail++;	
			} 
		} 
	} elsif ($ftpsuccess == 1 && $list_size == 0) {
		# Set remote path, remote file pattern and get remote file list
		$remote_file_pattern = $remotedir . ".*";
		@file_list = ftp_longlist($remotedir);

		# Get remote directory matched files 
		for (my $i = 0; $i < @file_list; $i++) {
			# Split the string
			my ($flags, $blank1, $blank2, $blank3, $blank4, $blank5, $blank6, $blank7, $filename) = split(" ", $file_list[$i]);
			
			# Ignore directory
			if ($flags =~ /^d/) {
				logfile("File $filename is a directory, do nothing", 2);
				next;
			} 	

			# Set the file path & local file pattern
			$file_to_write = $localdir . $filename;
			$file_to_copy = $splunkdir . $filename;
			$local_file_pattern = $file_to_write;

			# Check if it has been collected or not
			if (!-e $local_file_pattern) {
				# Check disk space
				if (check_space($localdir, $file_list[$i])) {
					# Get the File
					if (ftp_get($filename, $file_to_write, $file_to_copy)) {
						$success++;
					} else {
						$fail++;
					}
				} else {
					$fail++;
				} 
			} else {
				$remote_file = $remotedir . $filename;
				if (check_update($remote_file, $local_file_pattern)) {
					# Check disk space
					if (check_space($localdir, $remote_file)) {
						# Get the File
						if (ftp_get($remote_file, $file_to_write, $file_to_copy)) {
							$success++;
						} else {
							$fail++;
						}
					} else {
						$fail++;
					} 
				} else {
					$retrieved++;
				}
			}
		} # Go through each remote file
	} # Check FTP connection & list size

	# Close FTP connection
	if (defined $ftp) {
		logfile("Close FTP connection", 1);
		$ftp->quit;
	}

	# Log Collect Report
	if ($ftpsuccess == 1) {
		# Output Collect Stats
		logfile("Collect stats: Success $success, Fail $fail, Retrieved $retrieved", 1);
		if ($fail == 0) {
			logfile("All files have been collected successfully", 1);
		} else {
			if ($retry < $retry_max) {
				++$retry;
				logfile("Going to wait $delay seconds before retry, retry times: $retry", 0);
				sleep($delay);
				collect_log($server_name, $retry);
			} else {
				logfile("Fail to collect all logs files", 0);
			}
		}
	} elsif ($ftpsuccess == 0) {
		if ($retry < $retry_max) {
			++$retry;
			logfile("Going to wait $delay seconds before retry, retry times: $retry", 0);
			sleep($delay);
			collect_log($server_name, $retry);
		} else {
			logfile("Fail to connect to FTP server", 0);
		}
	}
}

sub cleanup {
	opendir(DIR, $piddir);
	while ($file = readdir(DIR)) {
		if (defined($file) && $file ne "." && $file ne "..") {
			$filepath = $piddir . $file;
			open FILE, $filepath;
			@lines = <FILE>;
			$lines[0] =~ s/\n//;
			$exists = kill 0, $lines[0]; # Check if process exists
			$output = `/bin/ps aux | /bin/grep "Schedule" | /bin/grep -v "grep"`;
			if ($exists && ($output =~ /$lines[0]/)) {
				`/bin/kill $lines[0] 2> /dev/null`;
				logfile("Kill daemon process: $lines[0]", 2);
			} else {
				logfile("Process doesn't exist: PID $lines[0]", 2);
			}
			close(FILE);

			logfile("Remove PID file: $filepath", 2);
			`/bin/rm -f $filepath`;
		}
	}
	closedir(DIR);
}

sub gettime {
	return "$time{'yyyy/mm/dd hh:mm:ss'}";
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
	#print "$writestring[1] - $log_level - $writestring[0]\n"; # Use this for debugging

	if ($writestring[1] > $log_level) {
		# print "No need to log\n"; # Use this for debugging
		return;
	}

	if (defined $server_name && $server_name ne "") {	
		if ($writestring[1] == 0) {
			$writestring[0] = "[$server_name] [Error] " . $writestring[0];
			
			# Write errors to another file
			open(ERRORLOG, ">> $errorlog");
			print ERRORLOG "$timestring [$program_name] $writestring[0]\n";
			close(ERRORLOG);
		} elsif ($writestring[1] == 1) {
			$writestring[0] = "[$server_name] [Info] " . $writestring[0];
		} elsif ($writestring[1] == 2) {
			$writestring[0] = "[$server_name] [Verbose Info] " . $writestring[0];
		} 
	} else {
        if ($writestring[1] == 0) {
            $writestring[0] = "[Error] " . $writestring[0];

			# Write errors to another file
            open(ERRORLOG, ">> $errorlog");
            print ERRORLOG "$timestring [$program_name] $writestring[0]\n";
            close(ERRORLOG);
        } elsif ($writestring[1] == 1) {
            $writestring[0] = "[Info] " . $writestring[0];
        } elsif ($writestring[1] == 2) {
            $writestring[0] = "[Verbose Info] " . $writestring[0];
        }
	}

	if ($uselog == 1) {
		print "$timestring [$program_name] $writestring[0]\n";
	}
	if ($uselog == 2) {
		open(SYSLOGFILE, ">> $logfile");
		print SYSLOGFILE "$timestring [$program_name] $writestring[0]\n";
		close(SYSLOGFILE);
	}
	if ($uselog == 3) {
		open(SYSLOGFILE, ">> $logfile");
		print SYSLOGFILE "$timestring [$program_name] $writestring[0]\n";
		close(SYSLOGFILE);
		print "$timestring [$program_name] $writestring[0]\n";
	}
}
