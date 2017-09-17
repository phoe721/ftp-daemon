#!/usr/bin/perl
use Time::Format qw(%time %strftime %manip);
use Date::Parse;
use Sys::Hostname;
use Crypt::ECB;
use Crypt::Blowfish;
use Digest::MD5 qw(md5 md5_hex md5_base64);

##################################################################################
# Initialization
##################################################################################
$config_file = "/root/scripts/rssftp.conf";
%cfg = ();
%cfg = &fill_ini($config_file);
$program_name = $cfg{runtime}->{program_name};
$version = $cfg{runtime}->{version};
$version_date = $cfg{runtime}->{version_date};
$license_key_file = $cfg{runtime}->{license_key_file};
$license_host = hostname;
$mtime = $cfg{modified_time}->{mtime};
$pidfile = $cfg{runtime}->{pidfile};
$piddir = $cfg{runtime}->{piddir};
$logfile = $cfg{runtime}->{monitorlogfile};
$program_path = $cfg{runtime}->{program_path};
$monitor_name = $cfg{runtime}->{monitor_name};
$uselog = $cfg{runtime}->{uselog};
$log_level = $cfg{runtime}->{log_level};

$config_file2 = "/home/logs/rssftp/rssftpserver.conf";
%cfg2 = ();
%cfg2 = &fill_ini($config_file2);
$mtime2 = $cfg2{modified_time}->{mtime};

# Check if license is valid
check_license();

##################################################################################
# Start program
##################################################################################
logfile("::::: Starting $monitor_name with $config_file",1);

# Convert modified time to unix time
$lastmtime = str2time($mtime);
$lastmtime2 = str2time($mtime2);
$mtime = (stat($config_file))[9];
$mtime2 = (stat($config_file2))[9];

# Check if conf file is recently modified
if ($mtime2 > $lastmtime2) {
	logfile("Config file was recently modified, restart program to update changes", 1);
	restart();
	update($mtime, $config_file);
	update($mtime2, $config_file2);
} elsif ($mtime > $lastmtime) {
	logfile("Config file was recently modified, restart program to update changes", 1);
	restart();
	update($mtime, $config_file);
	update($mtime2, $config_file2);
} elsif (-d $piddir) {
	# Pid directory exists, check processes
	logfile("Directory $piddir exists, continue...", 2);
	@files = <$piddir/*>;
	$count = @files;
	if ($count == 0) {
		# If no pid files found, restart
		logfile("No PID files found in $piddir, restart program", 2);
		restart();
	} else {
		# If pid files exists, check if process still alive
		monitor();		
	}
} else {
	# Pid directories not exists, restart
	logfile("Directory $piddir not exist, restart program", 2);
	restart();
}

logfile("::::: End $monitor_name", 1);
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

sub monitor {
	$count = 0;
	opendir(DIR, $piddir);
	while ($file = readdir(DIR)) {
		if (defined($file) && $file ne "." && $file ne "..") {
			$filepath = $piddir . $file;
			open FILE, $filepath;
			while ($process = <FILE>) {
				$process =~ s/\n//;
				$exists = kill 0, $process; # Check if file exists
				$output = `/bin/ps aux | /bin/grep "Schedule" | /bin/grep -v "grep"`;
				if ($exists && ($output =~ /$lines[0]/)) {
					logfile("Process $process exists, OK", 2);
				} else {
					$count++;
					logfile("Process $process does not exist", 2);
					logfile("Inactive process count: $count", 2);
				}
			}
			close(FILE);
		}
	}
	closedir(DIR);

	if ($count > 0) {
		restart();
	}
}

sub restart {
	system($program_path);
	$process = `/bin/cat $pidfile`;		
	$exists = kill 0, $process; 
	if ($exists) {
		logfile("Program $program_name restarted", 2);
	}
}

sub update {
	my $file = $_[1];
	my $data = "";
	open FILE, $file;
	while ($line = <FILE>) {
		$data .= $line;
	}
	close(FILE);

	my $mtime = $_[0];
	$new_mtime = "$time{'yyyy/mm/dd hh:mm:ss', $mtime}";
	$data =~ s/mtime.*/mtime = $new_mtime/g;
	$data =~ s/\r//g;

	open FILE, ">", $file;
	print FILE $data;
	close(FILE);

	utime $mtime, $mtime, $file;
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
			#Ignore starting hash
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

    if ($writestring[1] == 0) {
        $writestring[0] = "[Error] " . $writestring[0];
    } elsif ($writestring[1] == 1) {
        $writestring[0] = "[Info] " . $writestring[0];
    } elsif ($writestring[1] == 2) {
        $writestring[0] = "[Verbose Info] " . $writestring[0];
    }

	if ($uselog == 1) {
		print "$timestring [$monitor_name] $writestring[0]\n";
	}
	if ($uselog == 2) {
		open(SYSLOGFILE, ">> $logfile");
		print SYSLOGFILE "$timestring [$monitor_name] $writestring[0]\n";
		close(SYSLOGFILE);
	}
	if ($uselog == 3) {
		open(SYSLOGFILE, ">> $logfile");
		print SYSLOGFILE "$timestring [$monitor_name] $writestring[0]\n";
		close(SYSLOGFILE);
		print "$timestring [$monitor_name] $writestring[0]\n";
	}
}
