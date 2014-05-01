#!/usr/bin/perl

# tuptime - Report how long the system or other components has been running, count it between restarts.
# Copyright (C) 2013 - Ricardo F.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Time::Duration;
use Scalar::Util qw(looks_like_number);
#use diagnostics;

# Directory for the variables
my $driftD = "/var/lib/tuptime/";
# Directory for the configuration file
my $confD = "/etc/tuptime/";
# FILE1 asigned down to /proc/uptime 
# FILE6 asigned down to /proc/stat 
# File which store last value read from /proc/uptime
my $last_uptimeF = $driftD . "lastuptime"; # FILE2
# File which store the count of system starts 
my $sys_startsF = $driftD . "sysstarts"; # FILE3
# File which stores the total amount of time since the program began
my $total_timeF = $driftD . "totaltime"; # FILE4
# File which store the configuration of tuptime
my $conf_fileF = $confD . "tuptime.conf"; # FILE5
# File which store last value read from /proc/stat  
my $last_btimeF = $driftD . "lastbtime"; # FILE7
# File which store first boot date  
my $first_bootF = $driftD . "firstboot"; # FILE8
# Some varibles used in the program, other in the subroutines
my ($uptime, $total, $prev_uptime, $prev_btime, $total_starts, $result_total, $temp_total, @param, @uptime_date, $tmp1, $first_boot) = '';


# Default value for any option
if (@ARGV == 0){
        $ARGV[0] = '-p';        
}

# Parse options
foreach (@ARGV) {
        # test if the argument start with '-'
        if ($_ =~ m/^-/){
                # Split each character into the array
                @param = split(//, $_);
                # Shift first value, the '-'
                shift(@param);
                
                # Parse every param
                foreach (@param){
                        # If is a real option...
                        if ($_ =~ m/[i,p,m,u,h,V]/){

                                if ($_ =~ 'i' ){ 
                                        &i;
                                }

                                if ($_ =~ 'u' ){
                                        &u;
                                }

                                if ($_ =~ 'p' ){
                                        &pm('p');
                                }
                
                                if ($_ =~ 'm' ){
                                        &pm('m');
                                }
                
                                if ($_ =~ 'V' ){
                                        &V;
                                }
                
                                if ($_ =~ 'h') {
                                        &h;
                                }

                        # ...if not mach any real option
                        } else {
                                &invalid_option
                        } 

                }
        } else {
                &invalid_option
        }
}

# End program
exit 0;

##############
# Initialize #
##############
sub i {


             # Checking permissions
             if (-w "/var/lib/" || -w "/etc/" ) {
             } else {
                printf "This user can't create program directories.\n";
                printf "Execute this command with privileged user.\n";
                exit 1;
        }

        # Checking directories
        foreach ($driftD, $confD)
        {
                if (-d "$_") {
                        printf("Exists: " . $_ . " - Don't do anything.\n");
                } else {
                        printf("Not exists: " . $_ . " - Making! \n");
                        mkdir "$_", 655;
                }
        }

	# Checking files
	foreach ($last_uptimeF, $last_btimeF, $total_timeF, $sys_startsF)
	{
		if (-e "$_" ) {
         	       printf ("Exists: " . $_ . " - Don't do anything.\n");
	        } else {
        	        printf ("Not exists: ". $_ . " - Making! \n");
                	open(FILE,"> $_") || return 1;
	                print FILE 0;
        	        close FILE || return 1;
	        }
	}

        # Cheking the $conf_fileF
        if (-e "$conf_fileF" ) {
                printf ("Exists: " . $conf_fileF . " - Don't do anything.\n");
        } else {
                printf ("Not exists: ". $conf_fileF . " - Making!\n");
                open(FILE5,"> $conf_fileF") || return 1;
                print FILE5 "# tuptime configuration file\n# Usage: \n# Name:+MoreTime (in minutes)\n# or\n# Name:-LessTime (in minutes)\n# \n# Keep historical time in removed hardware:\n# Name:+Time:RM (Time = total time in minutes when the hardware was removered)\n# \nSystem:+0\n";
                close FILE5 || return 1;
        }

        # Cheking the $first_bootF
        if (-e "$first_bootF" ) {
                printf ("Exists: " . $first_bootF . " - Testing if is ok.\n");

		# Get first boot date
	        open(FILE8,"< $first_bootF") || return 1;
        	$first_boot = <FILE8>;
	        close FILE8 || return 1;
		# If is empty, write the date
		if ($first_boot == 0) {
			# Go to the following else condition
			goto date_write;
		}
		
        } else {
		
		date_write:
		# Read date and write
		open(FILE6, "< /proc/stat") || return 1;
	        ($tmp1) = grep( { m/btime/ } <FILE6>);
        	close FILE6 || return 1;
		@uptime_date = split (' ', $tmp1, 2);
		
                printf ("Not exists: ". $first_bootF . " - Making!\n");
                open(FILE8,"> $first_bootF") || return 1;
                print FILE8 "$uptime_date[1]";
                close FILE8 || return 1;
        	my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	        my ($sec, $min, $hour, $day,$month,$year) = (localtime($uptime_date[1]))[0,1,2,3,4,5,6];
        	printf ("Saved first boot date: \t%02s:%02s:%02s   %02s-$months[$month]-%04s\n", $hour, $min, $sec, $day, ($year+1900));
        }

return 0;
}

##########
# Update #
##########
sub u {

        ## Check if the computer is restarted

        # Checking permissions
        if (-w "$sys_startsF" || -w "$last_uptimeF" || -w "$total_timeF" ) {
        } else {
                printf "This user can't write in program files.\n";
                printf "Execute this command with privileged user.\n";
                exit 1;
        }

        # Read actual uptime value from system
        open(FILE1, "< /proc/uptime") || return 1;
        ($uptime) = split (/\s+/, <FILE1>, -1);
        close FILE1 || return 1;

        # Read last read time from /proc/uptime save in the $last_uptimeF file
        open(FILE2, "< $last_uptimeF") || return 1;
        $prev_uptime = <FILE2>;
        close FILE2 || return 1;

        # Save the actual system uptime in the file for the following check
        open(FILE2,"> $last_uptimeF") || return 1;
        print FILE2 $uptime;
        close FILE2 || return 1;
        

	# Read actual boot time from /proc/stat
	open(FILE6, "< /proc/stat") || return 1;
        ($tmp1) = grep( { m/btime/ } <FILE6>);
        close FILE6 || return 1;
	@uptime_date = split (' ', $tmp1, 2);
	chomp($uptime_date[1]);

	# Read last time from /proc/uptime save in the $last_btimeF file
        open(FILE7, "< $last_btimeF") || return 1;
        $prev_btime = <FILE7>;
        close FILE7 || return 1;
	chomp($prev_btime);

        # If the last read time is more than the actual system uptime...
        if ($prev_btime < $uptime_date[1]) {
                # ...the system is restarted, so, actualize the $last_btimeF
                open(FILE7, "> $last_btimeF") || return 1;
                print FILE7 $uptime_date[1];
                close FILE7 || return 1;

		# so, previous uptime is 0 value
		$prev_uptime = 0;
        
                # and, actualize system starts. Read value, increase count, save value
                open(FILE3,"< $sys_startsF") || return 1;
                $total_starts = <FILE3>;
                close FILE3 || return 1;
                $total_starts ++;
                open(FILE3,"> $sys_startsF") || return 1;
                print FILE3 $total_starts;
                close FILE3 || return 1;

        # ...the system wasn't restarted
        } else {
        }

        # Get the differente between the $uptime and $prev_uptime...
        # ...the result is the time elapsed in secods since the last tuptime files update.
        $total = $uptime - $prev_uptime;
        
        # Open the file which stores the total amount of time since the program began for read the value
        open(FILE4,"< $total_timeF") || return 1;
        $temp_total = <FILE4>;
        close FILE4 || return 1;

        # Get the sum between the value that have the file and the time elapsed in secods since the last update.
        $temp_total += $total;
        
        # Save the new value of the time elapsed in the file
        open(FILE4,"> $total_timeF") || return 1;
        print FILE4 $temp_total;
        close FILE4 || return 1;
        # If is update
        if ($_ =~ 'u'){
                print ("Updating tuptime.\n");
        }
return 0;
}       

################
# Print values #
################
sub pm {

        # Receive arguments passed
        my($pm_arg0) = $_;

	# Some varibles used only in this subroutine
	my (@content, @split_line, $rate) = '';

	# Variable for print date
	my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	my ($sec, $min, $hour, $day,$month,$year);


        # Read actual uptime value from system
        open(FILE1, "< /proc/uptime") || return 1;
        ($uptime) = split (/\s+/, <FILE1>, -1);
        close FILE1 || return 1;

        # Read last read time from /proc/uptime save in the $last_uptimeF file
        open(FILE2, "< $last_uptimeF") || return 1;
        $prev_uptime = <FILE2>;
        close FILE2 || return 1;

        # Get the differente between the $uptime and $prev_uptime...
        # ...the result is the time elapsed in secods since the last update.
        $total = $uptime - $prev_uptime;

        # Open the file which stores the total amount of time since the program began for read the value
        open(FILE4,"< $total_timeF") || return 1;
        $temp_total = <FILE4>;
        close FILE4 || return 1;

        # Get the sum between the value that have the file and the time elapsed in secods since the last update.
        $temp_total += $total;

        # Print System startups and date
	# Get startup count
        open(FILE3,"< $sys_startsF") || return 1;
        $total_starts = <FILE3>;
        close FILE3 || return 1;

	# Get first boot date
        open(FILE8,"< $first_bootF") || return 1;
        $first_boot = <FILE8>;
        close FILE8 || return 1;
        
	# Print all
        ($sec, $min, $hour, $day,$month,$year) = (localtime($first_boot))[0,1,2,3,4,5,6];
        print("System startups:\t" . $total_starts. "   ");
	printf ("since   %02s:%02s:%02s   %02s-$months[$month]-%04s\n", $hour, $min, $sec, $day, ($year+1900));
        

        # Print medium uptime...
        if ($pm_arg0 =~ 'p' ){
                # ...in correct format
                printf("Average uptime:\t\t" . duration_exact(($temp_total) / $total_starts) . "\n");
        } else {
                # ...in minutes
                printf("Average uptime:\t\t%u minutes\n", (($temp_total / 60) / $total_starts));
        }

	# Print date uptime...
	# Get date when the system start from /proc/stat and convert into nomral date
	open(FILE6, "< /proc/stat") || return 1;
        ($tmp1) = grep( { m/btime/ } <FILE6>);
        close FILE6 || return 1;
	@uptime_date = split (' ', $tmp1, 2);
	($sec, $min, $hour, $day,$month,$year) = (localtime($uptime_date[1]))[0,1,2,3,4,5,6];
	
        # Print actual uptime time...
        if ($pm_arg0 =~ 'p' ){
                # ...in correct format
                printf("Current uptime:\t\t" . duration_exact($uptime) . "   ");
		printf ("since   %02s:%02s:%02s   %02s-$months[$month]-%04s\n", $hour, $min, $sec, $day, ($year+1900));
        } else {
                # ...in minutes
                printf("Current uptime:\t\t%u minutes   ", ($uptime / 60));
		printf ("since   %02s:%02s:%02s   %02s-$months[$month]-%04s\n", $hour, $min, $sec, $day, ($year+1900));
        }
	
	# Print uptime rate
	# Total total uptime time x 100 between time elapsed since first boot date
	$rate = ((($temp_total ) * 100 ) / (($uptime_date[1] + $uptime) - $first_boot));
	printf("Uptime rate:\t\t%.5f \%% \n", $rate);

        # Read the configuration file and put it into an array
        open(FILE5,"< $conf_fileF") || return 1;
        @content = <FILE5> ;
        close FILE5 || return 1;
        
        # Parse each line in the array ...
        foreach my $line (@content) {
                chomp ($line);   
                # if is a blank line or a comment line, jump it
                next if ( ($line =~ /^\s*$/) || ($line =~ m/^#/ ) );
                # Divide each value in the line (three max)
                @split_line = split(/:/, $line, 3);
                print ($split_line[0] . " time:\t\t" );
                                
                # If there are second value...
                if ( ($split_line[1]) && (looks_like_number($split_line[1])) ){
                        # sum or rest the values
                        $result_total = $temp_total + ($split_line[1] * 60 );
                # ... else, if there are only one value...
                } else {
                        #...asign directly the value
                        $result_total = $temp_total;
                        # put default value for second value
                        $split_line[1] = 0;
                }
                        #if there are third value and the third value is 'RM' reset the values
                        if ( ($split_line[2]) && ( $split_line[2] =~ 'RM')){
                                $result_total = ($split_line[1] * 60 );
                        }
                # ...anyway, print times values in correct format
                # If the value isn't negative...
                if ($result_total >= 0){
                        if ($pm_arg0 =~ 'p' ){
                                print (duration_exact($result_total) . "\n");
                        } else {
                                printf (("%u" ) . " minutes\n", $result_total / 60 );
                        }
                # ...if is negative
                } else {
                        printf("Error, is negative value!: %0.0f minutes\n", ($result_total / 60));  
                }
        }
return 0;       
}

###########
# Version #
###########
sub V {

        print("\n\ttuptime - Version 1.6.2.\n\n\t14/May/2013\n\tRicardo F <rikr_\@hotmail.com>\n\tGNU License.\n\n");
        print("\ttuptime - Copyright (C) 2013 -  Ricardo F. \n");
        print("\tThis program comes with ABSOLUTELY NO WARRANTY.\n");
        print("\tThis is free software, and you are welcome to redistribute it\n");
        print("\tunder certain conditions.\n\n");
return 0;
}

########
# Help #
########
sub h {

        print("Help:\n\ttuptime - Report about historical and statistical run time of the system, keeping it between reboots.\n\n");
        &print_usage;
return 0;
}

###############
# Print Usage #
##############
sub print_usage {
        print("Usage: tuptime [OPTION...]\n");
        print("\t-i \t Initialize the files which uses.\n");
        print("\t-p \t Print the values in human readable style.\n");
        print("\t-m \t Print the values in minutes.\n");
        print("\t-u \t Update and save the values to disk.\n");
        print("\t-h \t Display this help.\n");
        print("\t-V \t Version information.\n\n");
return 0;
}

##################
# Invalid Option #
##################
sub invalid_option {
        print("\ntuptime: Invalid option " . $_ . "\n\n");
        &print_usage;
        exit 1;
}

exit 2;
