#!/usr/bin/perl
# Utility drawer for Appliance.
# $Id: KVM.pm.in,v 1.6 2011/07/07 20:29:55
#
# $Log: KVM,v $
# Revision 1.0  2011/07/07 20:29:55  Abhinav
#package KVM;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK =
  qw(&write_log $PATH_TO_APPLIANCE_LOG &fail &success &initialize &search  &addVIRTUALMACHINE &assignPIP &rebootVM &checkUPTIME &enableprivateNET &createnetworkXML &disprivNETWORK &vmCLONE &createBACKUP &createcustomIMAGE &delBACKUP &delcustomIMAGE &vmREVERTSS &vmSNAPSHOT &attachVolume &detachVolume &deallocatePIP &restorecustomIMAGE &restoreSTIMAGE &assignPIPwin);
#
$debug = 0;    # set to zero to turn off debugging

$PATH_TO_APPLIANCE_LOG = "/var/log/kvmrpc.log";

sub fail    { 0 }
sub success { 1 }

#use strict;
use DBI;
use File::Remote;
use Symbol;
$ENV{'PATH'} = "/bin:/usr/bin:/sbin:/usr/sbin:/bin:/usr/local/bin";

## FUNCTIONS start here .
####################################################################
# write_log($msg): appends a time/date stamp and $msg to the log file.
####################################################################
sub write_log {
    my $msg = $_[0];

    $msg = date_string() . $msg;

    if ( open( LOGFILE, ">> $PATH_TO_APPLIANCE_LOG" ) ) {
        print LOGFILE $msg . "\n";
        close LOGFILE;
    }
    else {
        print("Couldn't open $PATH_TO_APPLIANCE_LOG!!!");
    }

    if ($debug) {
        print $msg. "\n";
    }

}

####################################################################
# date_string: returns a timestamp suitable for log files.
####################################################################
sub date_string {

    # This should be fast -- no shell commands in here.
    # This routine benchmarked at approx .18 ms,
    # so we can run this more than 1000 times/second
    # QF March 31 1998 (code ripped from bunyan --gb)

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);

    $mon++;    # Map 0-11 => 1-12

    return sprintf "%s:%s:%s:%s:%s:%s # ",
      $year + 1900,
      $mon < 10  ? "0$mon"  : $mon,
      $mday < 10 ? "0$mday" : $mday,
      $hour < 10 ? "0$hour" : $hour,
      $min < 10  ? "0$min"  : $min,
      $sec < 10  ? "0$sec"  : $sec;
}

####################################################################
# Change: alters a line in a file
# Change($file, $find, $replacewith)
####################################################################
sub Change {
    my $file    = $_[0];
    my $find    = $_[1];
    my $replace = $_[2];
    my $foundit = 0;
    my @infile;
    write_log("Changing [$find] to [$replace] in $file...");
    if ( -f $file ) {
        unless ( -w $file ) {
            write_log(
                "  $file isn't writeable! Can't change [$find] to [$replace]!");
            return fail;
        }
    }
    else {
        write_log("  Can't \"Change\" a file that doesnt exist! [$file]");
        return fail;
    }
    unless ( open( INFILE, "$file" ) ) {
        write_log("  Unable to open $file for reading");
        return fail;
    }
    @infile = <INFILE>;
    close INFILE;
    unless ( open( OUTFILE, "> $file" ) ) {
        write_log("  Unable to truncate $file for writing");
        return fail;
    }
    foreach (@infile) {
        $foundit++ if /$find/;
        s/$find/$replace/;
        print OUTFILE;
    }
    close OUTFILE;
    if ( $foundit == 0 ) {
        write_log("WARNING: Never found [$find] in $file");
    }
    return success;
}

####################################################################
# search: search a line in file
# search($find, $file)
####################################################################
sub search {
    my $find = $_[0];
    my $file = $_[1];
    my @infile;

    write_log("Searching [$find]  in $file...");

    if ( -f $file ) {
    }
    else {
        write_log("  Can't \"Change\" a file that doesnt exist! [$file]");
        return fail;
    }

    unless ( open( INFILE, "$file" ) ) {
        write_log("  Unable to open $file for reading");
        return fail;
    }
    @infile = <INFILE>;
    close INFILE;

    foreach (@infile) {
        return $_ if /$find/;
    }

    return fail;
}

####################################################################
# Append: adds a line to a file
# Append($file, $line);
####################################################################
sub Append {
    my $file = $_[0];
    my $line = $_[1] or return fail;

    write_log("Appending [$line] to [$file]");

    if ( -f $file ) {
        unless ( -w $file ) {
            write_log("  $file isn't writeable! Can't append [$line]!");
            return fail;
        }
    }

    if ( open( OUT, ">> $file" ) ) {
        print OUT "$line\n";
        close OUT;
    }
    else {
        write_log("Couldn't open $file for appending!");
        return fail;
    }

    return success;
}

####################################################################
# inititalize: Initialize a blank file
# initialize($file);
####################################################################
sub initialize {
    my $file = $_[0] or return fail;

    write_log("Initializing [$file]");

    if ( -f $file ) {
        unless ( -w $file ) {
            write_log("  $file isn't writeable! Can't append [$line]!");
            return fail;
        }
    }

    if ( open( OUT, "> $file" ) ) {
        print OUT "";
        close OUT;
    }
    else {
        write_log("Couldn't open $file for Initializing!");
        return fail;
    }

    return success;
}

####################################################################
# replace:  Replace a file with other
# replace($file, $line);
####################################################################
sub replace {
    my $file = $_[0];
    my $file2 = $_[1] or return fail;

    write_log("Moving [$file] if it exists to $file2");
    system("rm -rf  $file2");
    system("mv $file $file2");
    return success;

}

####################################################################
# remove:  Remove a file
# remove($file);
####################################################################
sub remove {
    my $file = $_[0] or return fail;

    write_log("REMoving [$file] if it exists ");
    system("rm -rf  $file");
    return success;

}

###################################################################
# ModifyFile: It modifies a file for deleting a stanza which is
# between Marks
#
# Usage : ModifyFile --delete /path/file startmark.endmark
##################################################################
sub ModifyFile {
    my $file    = shift;
    my $opening = shift;
    my $closing = shift;
    chomp($opening);
    chomp($closing);

    write_log("Parameters :: $file , $opening ,$closing");
    open FILE, "$file" or print "FATAL:: Failed to  open  $file";
    my $copy = 1;
    write_log("Reading the file $file ");
    while (<FILE>) {
        chomp $_;
        if ( /$opening/ && $copy eq 1 ) {
            $copy = 0;
            write_log("Found Starting of the Share Block ");
        }

        if ( $copy eq 1 ) {
            $newfiletext .= $_ . "\n";
        }
        if ( $_ eq $closing && $copy eq 0 ) {
            write_log("Found Closing of the Share Block ");
            $copy = 1;
        }

    }
    close FILE;
    open FILE, ">$file" or print "FATAL::can't write  on $file";
    print FILE $newfiletext;
    close FILE;
}

###########################################################################
## Append- Appedsa line in the file.
############################################################################
sub Append {
    my $file = $_[0];
    my $line = $_[1] or return fail;
    write_log("Appending [$line] to [$file]");
    if ( -f $file ) {
        unless ( -w $file ) {
            write_log("  $file isn't writeable! Can't append [$line]!");
            return fail;
        }
    }
    if ( open( OUT, ">> $file" ) ) {
        print OUT "$line\n";
        close OUT;
    }
    else {
        write_log("Couldn't open $file for appending!");
        return fail;
    }
    return success;
#################################################################################################
# Assign Additional Public IP's to guest machines
# #################################################################################################
    sub assignPIP {
        my $cust_id         = shift;
        my $server_id       = shift;
        my $cust_name       = shift;
        my $os_type         = shift;
        my $os_name         = shift;
        my $wan_primary_ip  = shift;
        my $wan_sec_ip_list = shift;
        my $noaddip         = shift;
######################################################################################################
        # Check for Machine's Existance
        write_log("WAN Primary ip : $wan_primary_ip and WAN Secondry ip list :$wan_sec_ip_list and noaddip :$noaddip \n");
        my @ips = split( ',', $wan_sec_ip_list );
        my $ipsno = scalar(@ips);
        if ( !-f "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
            write_log("Machine $cust_id-$server_id doesn't exists");
            return fail;
        }
        else {
            write_log("Machine name $cust_id-$server_id  exist ");
            system("virsh list | grep -i $cust_id-$server_id >/dev/null");
              ###### Check for guest machine state
            if ( $? == 0 ) {
                write_log(" Machine is Running.Powering it off ");
                system("virsh shutdown $cust_id-$server_id >/dev/null");
                while($? == 0) {
                    write_log(" Machine still shutting down.");
                    system("virsh list|grep -i $cust_id-$server_id >/dev/null");
                    sleep(5);
                }
                if ( -d "/mnt/$cust_id-$server_id" ) {
                    write_log(
                        " Machine is already Monuted. Assigning IP's to it");
                }
                else {
                    write_log("Mouting Disk");
                    system("mkdir -p /mnt/$cust_id-$server_id");
                    system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id");
                }
            }
            if ( $os_type eq "linux" ) {
                my $nooldip = $ipsno + $noaddip;
                if ( ( $os_name eq "centos" ) || ( $os_name eq "redhat" ) ) {
                    for ( $i = $noaddip ; $i < $nooldip ; $i++ ) {
                        open( OUT,"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3:$i");
                        my $filei ="/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3:$i";
                        $line7  = "DEVICE=ens3:$i";
                        $line8  = "ONBOOT=yes";
                        $line9  = "IPADDR=$ips[$i]";
                        $line10 = "NETMASK=255.255.255.0";
                        if ( $response =
                               Append( $filei, $line7 )
                            && Append( $filei, $line8 )
                            && Append( $filei, $line9 )
                            && Append( $filei, $line10 ) )
                        {
                            write_log(
                                "Additional IP- $ips[$i] assigned successfully"
                            );
                        qx{perl -i.bak -pe "s#(\s*)(?=<parameter name='IP' value='$wan_primary_ip'/>)#\$1<parameter name='IP' value='$ips[$i]'/>\n#\n" /etc/libvirt/qemu/$cust_id-$server_id.xml};
                        }
                    }
                    system("umount /mnt/$cust_id-$server_id");
                    system("rm -rf /mnt/$cust_id-$server_id");
                    system("cp /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml-bak");
                    system("virsh undefine $cust_id-$server_id >/dev/null");
                    system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml-bak /etc/libvirt/qemu/$cust_id-$server_id.xml");
                    system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml >/dev/null");
                    system("virsh start $cust_id-$server_id >/dev/null");
                    return success;
                }
                elsif ( ( $os_name eq "debian" ) || ( $os_name eq "ubuntu" ) ) {
                    my $file = "/mnt/$cust_id-$server_id/etc/network/interfaces";
                    for ( $i = $noaddip ; $i < $nooldip ; $i++ ) {
                        $line7  = "auto eth0:$i";
                        $line8  = "iface eth0:$i inet static";
                        $line9  = "address $ips[$i-$noaddip]";
                        $line10 = "netmask 255.255.255.0";
                        if ( $response =
                               Append( $file, $line7 )
                            && Append( $file, $line8 )
                            && Append( $file, $line9 )
                            && Append( $file, $line10 ) )
                        {
                            write_log("Additional IP- $ips[$i-$noaddip] assigned successfully");
			    qx{perl -i.bak -pe "s#(\s*)(?=<parameter name='IP' value='$wan_primary_ip'/>)#\$1<parameter name='IP' value='$ips[$i-$noaddip]'/>\n#\n" /etc/libvirt/qemu/$cust_id-$server_id.xml};
                        }
                    }
                    system("umount /mnt/$cust_id-$server_id");
                    system("rm -rf /mnt/$cust_id-$server_id");
                    system("cp /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml-bak");
                    system("virsh undefine $cust_id-$server_id >/dev/null");
                    system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml-bak /etc/libvirt/qemu/$cust_id-$server_id.xml");
                    system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml  >/dev/null");
                    system("virsh start $cust_id-$server_id  >/dev/null");
                    return success;
                }
                else {
                    write_log(
                        "Something Went Wrong. Additional IP's assigmnet failed"
                    );
                    return fail;
                }
            }
	 } }
############################################################/########################
## ADD Virtual Machine
##
#####################################################################################

    sub addVIRTUALMACHINE {
        my $cust_id           = shift;
        my $server_id         = shift;
        my $cust_name         = shift;
        my $os_type           = shift;
        my $os_name           = shift;
        my $os_version        = shift;
        my $os_arch           = shift;
        my $os_image_location = shift;
        my $host_name         = shift;
        my $ram               = shift;
        my $vcpu              = shift;
        my $storage           = shift;
        my $disk_path = "/var/lib/libvirt/images/$cust_id-$server_id.qcow2";
        my $iso_path  = "/var/lib/libvirt/images/$cust_id-$server_id.iso"
          ;    # Cloud Init ISO, generated later.
        my $admin_password   = shift;
        my $wan_mac_address  = shift;
        my $wan_primary_ip   = shift;
        my $wan_sec_ip_list  = shift;
        my $vm_host_vnc_port = shift;
        my $vnc_password     = shift;
        my $ram              = $ram * 1024;
        my $dm               = "G";
        my $host_ip_address  = "1.1.1.1";
	my $resized	     = 0;
###########################################################################################
######## Check whether same hostname machine is not created previously#######################
        if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
            write_log("Machine name $cust_id-$server_id  exist:: ");
            return fail;
        }
        else
###################  Create Virtual Machine #######################################################
        {
            system(
"qemu-img create -f qcow2  -o preallocation=metadata /var/lib/libvirt/images/$cust_id-$server_id.qcow2 20$dm >/dev/null 2>/dev/null "
            );
            write_log(
"QCOW2 IMAGE HAS BEEN CREATED UNDER VAR-LIB-LIBVIRT-IMAGES-$cust_id-$server_id.qcow2"
            );
            write_log(
"qemu-img create -f qcow2  -o preallocation=metadata /var/lib/libvirt/images/$cust_id-$server_id.qcow2 20$dm"
            );
            system("touch $iso_path");    # create a dummy
            system("virt-install --connect qemu:///system --name $cust_id-$server_id --ram $ram --vcpus $vcpu --disk /var/lib/libvirt/images/$cust_id-$server_id.qcow2,format=qcow2 --graphics vnc,password=$vnc_password,port=$vm_host_vnc_port,listen=$host_ip_address --cdrom $iso_path --network network:phybrid,mac=$wan_mac_address >>/tmp/log 2>>/tmp/log");
            write_log("virt-install --connect qemu:///system --name $cust_id-$server_id --ram $ram --vcpus $vcpu --disk /var/lib/libvirt/images/$cust_id-$server_id.qcow2,format=qcow2 --graphics vnc,password=$vnc_password,port=$vm_host_vnc_port,listen=$host_ip_address --cdrom $iso_path --network network:phybrid,mac=$wan_mac_address >>/tmp/log 2>>/tmp/log");

            write_log("VIRT-INSTALL COMMAND CALLED FOR CUSTOMER ID $cust_id AND SERVER ID $server_id");
            system("virsh destroy $cust_id-$server_id >>/tmp/log 2>>/tmp/log");
            write_log("VIRSH DESTROY $cust_id-$server_id   :: $?");
            if ( $? != 0 ) {
                write_log("Virtual Machine Not Created");

                system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                write_log("REMOVE QCOW2 IMAGE FROM PATH : VAR-LIB-LIBVIRT-IMAGES-$cust_id-$server_id.qcow2 ");
                return fail;
            }
            if (
                -e "/mnt/$os_image_location/$os_name-$os_version-$os_arch.qcow2"
              )
            {
                write_log(
"COPYING IMAGE FROM /mnt/$os_image_location/'$os_name-$os_version-$os_arch.qcow2' TO /var/lib/libvirt/images/$cust_id-$server_id.qcow2"
                );
	        system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                system(
"cp /mnt/$os_image_location/'$os_name-$os_version-$os_arch.qcow2' /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null"
                );
            }
            else {
                write_log("PATH : $os_image_location \n");
                write_log(
"IMAGE IS NOT EXIST AT /mnt/$os_image_location/$os_name-$os_version-$os_arch.qcow2 \n"
                );

                system("virsh undefine $cust_id-$server_id ");
                write_log("HOST UNDEFINED :: $cust_id-$server_id\n");
                return fail;
            }
############ Check for HDD Size to be increased ###########################################
            if ( $storage != 20 ) {
#                write_log("IMAGE IS MORE THAN 20 GB : TAKING BACKUP OF EXITING IMAGE \n");
#                system("cp -rp /var/lib/libvirt/images/$cust_id-$server_id.qcow2 /iso/backupimages/$cust_id-$server_id.qcow2 > /dev/null");
#                write_log("cp -rp /var/lib/libvirt/images/$cust_id-$server_id.qcow2 /iso/backupimages/$cust_id-$server_id.qcow2");
                system("qemu-img create -f qcow2 -o preallocation=metadata  /iso/tempimages/$cust_id-$server_id.qcow2 $storage$dm > /dev/null");
                write_log("qemu-img create -f qcow2 -o preallocation=metadata  /iso/tempimages/$cust_id-$server_id.qcow2 $storage$dm");
                if ( $os_type eq "linux" ) {
                    write_log("Linux VIRT-RESIZE CALLED :\n ");
                    system("virt-resize --expand /dev/sda1 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 /iso/tempimages/$cust_id-$server_id.qcow2 >/dev/null");
		    if ( $? != 0 )
                        {
                         write_log("DELETING BACKUP IMAGE");
                         system("rm -rf /iso/backupimages/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                         write_log("DELETING TEMP IMAGE AS WELL");
                         system("rm -rf /iso/tempimages/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                         system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                         system("virsh undefine $cust_id-$server_id >/dev/null 2>/dev/null");
                         write_log("HOST UNDEFINED :: $cust_id-$server_id\n");
                         system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                         write_log("SOMETHING WENT WRONG WHILE RESIZEING :: $?");
                         return fail;
                        }


  system("mv /iso/tempimages/$cust_id-$server_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 > /dev/null");
                    write_log("mv /iso/tempimages/$cust_id-$server_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2");


                }
                else {
	            write_log("VIRT-RESIZE CALLED (os version $os_version and storage size $storage)\n ");
		    if($storage < 60) {
                        write_log("Image will be too small for Windows Server 2012. $storage GB requested, 60 GB required.\n");
			return fail;
	            }
                    elsif($os_version eq "2012" && $storage > 60) { 
			write_log("OS version $os_version Windows 2012 image is expanding.\n");
                        system("virt-resize --expand /dev/sda2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 /iso/tempimages/$cust_id-$server_id.qcow2 >>/tmp/resizelog");
			$resized = 1;
                    }
                    elsif($os_version eq "2008" && $storage > 60) { 
			write_log("Windows 2008 image is expanding.\n");
                        system("virt-resize --expand /dev/sda2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 /iso/tempimages/$cust_id-$server_id.qcow2 >>/tmp/resizelog");
			$resized = 1;
                    }
                    else { write_log("Resize skipped. Image was already the correct size.\n"); system("true"); }
		    if ( $? != 0 )
                        {
                         write_log("SOMETHING WENT WRONG WHILE RESIZEING :: $?");
                         write_log("DELETING BACKUP IMAGE");
                         system("rm -rf /iso/backupimages/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                         write_log("DELETING TEMP IMAGE AS WELL");
                         system("rm -rf /iso/tempimages/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                         system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                         system("virsh undefine $cust_id-$server_id >/dev/null 2>/dev/null");
                         write_log("HOST UNDEFINED :: $cust_id-$server_id\n");
                         system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
                         return fail;
                        }

                }
                if($resized == 1) {
                    system("mv /iso/tempimages/$cust_id-$server_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 > /dev/null");
                    write_log("mv /iso/tempimages/$cust_id-$server_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2");
                }
                write_log("Disk Resized Successful, Moving Ahead");
		write_log("DELETING BACKUP IMAGE /iso/backupimages/$cust_id-$server_id.qcow2 ");
                system("rm -rf /iso/backupimages/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");

            }
################# Setting Hostname and Public IP #######################
            system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");
            system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null");
################ Calculate Gateway #############################################
            my @array1 = split( /\./, $wan_primary_ip );   # Perl Code to split strings of an ip address by delimiter "."
            splice @array1, 3, 4; # perl Code to get the first three strings out of the splitted array
            my $wan_ip_gateway = join( ".", @array1 );    # Perl Code to join the first three spliced strings of array
####################################################################################################
####################### IP Assignment ###########################################################
            if ( $os_type eq "linux" ) {
                if ( ( $os_name eq "centos" ) || ( $os_name eq "redhat" ) ) {
                    if ( ( $os_name eq "centos" ) && ( $os_version eq "7.0" ) )
                    {
                        my $file ="/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3";
                        system(">/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3");
                        $line1 = "DEVICE=ens3";
                        $line2 = "ONBOOT=yes";
                        $line3 = "HOTPLUG=no";
                        $line4 = "IPADDR=$wan_primary_ip";
                        $line5 = "NETMASK=255.255.255.0";
                        $line6 = "GATEWAY=$wan_ip_gateway.1";
                        write_log("Adding IP $wan_primary_ip to file");

                        if ( $response =
                               Append( $file, $line1 )
                            && Append( $file, $line2 )
                            && Append( $file, $line3 )
                            && Append( $file, $line4 )
                            && Append( $file, $line5 )
                            && Append( $file, $line6 ) )
                        {
                            write_log(
                                " IP Assignment $wan_primary_ip Successful ");
                            my @ips = split( ',', $wan_sec_ip_list );
                            my $ipsno = scalar(@ips);
                            if ( $ipsno != 0 ) {
                                for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                                    open( OUT,
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3:$i"
                                    );
                                    my $filei =
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3:$i";
                                    $line7  = "DEVICE=ens3:$i";
                                    $line8  = "ONBOOT=yes";
                                    $line9  = "IPADDR=$ips[$i]";
                                    $line10 = "NETMASK=255.255.255.0";
                                    if ( $response =
                                           Append( $filei, $line7 )
                                        && Append( $filei, $line8 )
                                        && Append( $filei, $line9 )
                                        && Append( $filei, $line10 ) )
                                    {
                                        write_log(
"Additional IP- $ips[$i] assigned successfully"
                                        );
                                    }
                                }
                            }
                        }
                        else {
                            write_log(
"Something Went Wrong. Additional IP's assigmnet failed"
                            );
                        }
                        system(">/mnt/$cust_id-$server_id/etc/hostname");
                        my $file = "/mnt/$cust_id-$server_id/etc/hostname";
                        $line11 = "$host_name";
                        Append( $file, $line11 );
                        write_log(" Unmounting Disk");
                        write_log("OS Version : $os_version \n");

                    }
                    else {
                        my $file =
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0";
                        system(
">/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0"
                        );
                        $line1 = "DEVICE=eth0";
                        $line2 = "ONBOOT=yes";
                        $line3 = "HOTPLUG=no";
                        $line4 = "IPADDR=$wan_primary_ip";
                        $line5 = "NETMASK=255.255.255.0";
                        $line6 = "GATEWAY=$wan_ip_gateway.1";
                        write_log("Adding IP $wan_primary_ip to file");

                        if ( $response =
                               Append( $file, $line1 )
                            && Append( $file, $line2 )
                            && Append( $file, $line3 )
                            && Append( $file, $line4 )
                            && Append( $file, $line5 )
                            && Append( $file, $line6 ) )
                        {
                            write_log(
                                " IP Assignment $wan_primary_ip Successful ");
                            my @ips = split( ',', $wan_sec_ip_list );
                            my $ipsno = scalar(@ips);
                            if ( $ipsno != 0 ) {
                                for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                                    open( OUT,"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i");
                                    my $filei ="/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i";
                                    $line7  = "DEVICE=eth0:$i";
                                    $line8  = "ONBOOT=yes";
                                    $line9  = "IPADDR=$ips[$i]";
                                    $line10 = "NETMASK=255.255.255.0";
                                    if ( $response =
                                           Append( $filei, $line7 )
                                        && Append( $filei, $line8 )
                                        && Append( $filei, $line9 )
                                        && Append( $filei, $line10 ) )
                                    {
                                        write_log(
"Additional IP- $ips[$i] assigned successfully"
                                        );
                                    }
                                }
                            }
                        }
                        else {
                            write_log(
"Something Went Wrong. Additional IP's assigmnet failed"
                            );
                        }
                        my $file =
                          "/mnt/$cust_id-$server_id/etc/sysconfig/network";
                        $line11 = "HOSTNAME=$host_name";
                        Append( $file, $line11 );
                        write_log(" Unmounting Disk");
                        write_log("OS Version : $os_version \n");
                    }
                }

                elsif ( ( $os_name eq "debian" ) || ( $os_name eq "ubuntu" ) ) {
                    my $file =
                      "/mnt/$cust_id-$server_id/etc/network/interfaces";
                    $line6 = "auto eth0";
                    $line1 = "iface eth0 inet static";
                    $line2 = "address $wan_primary_ip";
                    $line3 = "gateway $wan_ip_gateway.1";
                    $line4 = "netmask 255.255.255.0";
                    $line5 = "dns-nameservers 8.8.8.8";
                    if ( $response =
                           Append( $file, $line6 )
                        && Append( $file, $line1 )
                        && Append( $file, $line2 )
                        && Append( $file, $line3 )
                        && Append( $file, $line4 )
                        && Append( $file, $line5 ) )
                    {
                        write_log(" IP Assignment $wan_primary_ip Successful ");
################# Adding Additional IP's##############################################################################
                        my @ips = split( ',', $wan_sec_ip_list );
                        my $ipsno = scalar(@ips);
                        if ( $ipsno != 0 ) {
                            for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                                $line7  = "auto eth0:$i";
                                $line8  = "iface eth0:$i inet static";
                                $line9  = "address $ips[$i]";
                                $line10 = "netmask 255.255.255.0";
                                if ( $response =
                                       Append( $file, $line7 )
                                    && Append( $file, $line8 )
                                    && Append( $file, $line9 )
                                    && Append( $file, $line10 ) )
                                {
                                    write_log("Additional IP- $ips[$i] assigned successfully");
                                }
                            }
                        }
                    }
                    else {
                        write_log(
"Something Went Wrong. Additional IP's assigmnet failed"
                        );
                    }
######################## Set Hostname ##################################################
                    $line7 = "$host_name";
                    my $file = "/mnt/$cust_id-$server_id/etc/hostname";
                    Append( $file, $line7 );
                    write_log(" Unmounting Disk");
                }
                else {
                    write_log("IP Assignment went wrong. Either disk was not mounted or file was not accessible");
                }

######################### SET PASSWORDS ######################################################################
                $password_salt = qx{openssl passwd -1 $admin_password};    ##### Generate Password Salt
                $old_password_salt =qx{cat /mnt/$cust_id-$server_id/etc/shadow | grep root | cut -d: -f2};
                chomp($password_salt);
                chomp($old_password_salt);
##Un Commented by Abhinav
                #$output=`lsattr /mnt/$cust_id-$server_id/etc/shadow`;
                system(
"cp /root/cloud.cfg-$os_name /mnt/$cust_id-$server_id/etc/cloud.cfg"
                );

#system("cp /mnt/$cust_id-$server_id/etc/shadow /mnt/$cust_id-$server_id/etc/shadow-bak >/dev/null");   ###### Backup Shadow File
#qx{sed -i 's|$old_password_salt|$password_salt|' /mnt/$cust_id-$server_id/etc/shadow};
#sed 's/old/new/g' input.txt > output.txt
                system(
"sed 's|$old_password_salt|$password_salt|g' /mnt/$cust_id-$server_id/etc/shadow > /mnt/$cust_id-$server_id/etc/shadow.new"
                );
                system(
"cp -p /mnt/$cust_id-$server_id/etc/shadow /mnt/$cust_id-$server_id/etc/shadow.orig >/dev/null"
                );
                system(
"cp -p /mnt/$cust_id-$server_id/etc/shadow.new /mnt/$cust_id-$server_id/etc/shadow >/dev/null"
                );

         #system("sed 's|root|$password_salt|g' /tmp/shadow > /tmp/shadow.new");
                write_log(
"sed -i 's|$old_password_salt|$password_salt|' /mnt/$cust_id-$server_id/etc/shadow"
                );
##      if (($os_name eq "centos") || ($os_name eq "redhat"))
##      {
##              system("chattr +e /mnt/$cust_id-$server_id/etc/shadow");
##      }
                #$output=`lsattr /mnt/$cust_id-$server_id/etc/shadow`;
#######
                write_log("SALTED password : $password_salt");
                write_log("OLD SALTED password : $old_password_salt");
                write_log("Password Changed to $admin_password");

######################################################################################################################
#################### UnMount File system ############################################################################
                #$thehostname = `cat /mnt/$cust_id-$server_id/etc/hostname`;
                #chomp($thehostname);
                #$thehostname =~ s/\s+//g; # Why is chomp not working?
                write_log(
"/usr/local/sbin/cloudconfig $host_name $wan_primary_ip /var/lib/libvirt/images/$cust_id-$server_id.iso"
                );
                system(
"/usr/local/sbin/cloudconfig $host_name $wan_primary_ip /var/lib/libvirt/images/$cust_id-$server_id.iso"
                );
                system("umount /mnt/$cust_id-$server_id");
                system("rm -rf /mnt/$cust_id-$server_id");
            }

            #Staring windows machine script
            #
            elsif ( $os_type eq "windows" ) {
                system("virsh shutdown $cust_id-$server_id >/dev/null");
                while($? == 0) {
                    write_log(" Machine still shutting down.");
                    system("virsh list|grep -i $cust_id-$server_id >/dev/null");
                    sleep(5);
                }
                system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");
                write_log("MAKING SCRIPT FOR WINDOWS IMAGE :: mkdir -p /mnt/$cust_id-$server_id");
                system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null");
                system("cp -p /iso/set-config.bat /iso/set-config$cust_id-$server_id.bat");
                qx{sed -i 's|SVR-2K8-10|$host_name|g' /iso/set-config$cust_id-$server_id.bat};
                qx{sed -i 's|password|$admin_password|g' /iso/set-config$cust_id-$server_id.bat};
                qx{sed -i 's|192.168.1.10|$wan_primary_ip|g' /iso/set-config$cust_id-$server_id.bat};
                qx{sed -i 's|192.168.1.1|$wan_ip_gateway|g' /iso/set-config$cust_id-$server_id.bat};
		if ( $os_version eq "2012" ) { # 2012 names interfaces differently. - Ryan
                    qx{sed -i 's|Local Area Connection|Ethernet|g' /iso/set-config$cust_id-$server_id.bat};
                }
                system("head -n -2 /iso/set-config$cust_id-$server_id.bat > /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");
                system("cp /root/cloudbase.msi /mnt/$cust_id-$server_id/cloudbase.msi > /dev/null");
                write_log("WINDOWS SERVER PASSWORD FOR $cust_id-$server_id : $admin_password IP : $wan_primary_ip");

#                system("umount /mnt/$cust_id-$server_id");
#                system("rm -rf /mnt/$cust_id-$server_id");

                #system("virsh start $cust_id-$server_id >/dev/null");
                # end cloud-init configuration
#                system("sleep 10");

            }
## end of windows machine script
################## Modifying XML ##################################################################################################################
qx{perl -i.bak -pe "s#(\s*)(?=<source network='phybrid'/>)#\$1<filterref filter='clean-traffic'>\n\$1 <parameter name='IP' value='$wan_primary_ip'/>\n\$1</filterref>#\n"    /etc/libvirt/qemu/$cust_id-$server_id.xml};
            my @ips = split( ',', $wan_sec_ip_list );
            my $ipsno = scalar(@ips);
            my $string2008 = 'echo netsh interface ipv4 add address \"Local Area Connection\"';
            system("echo >> /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");
            if ( $ipsno != 0 ) {
                for ( $i = 0 ; $i < $ipsno ; $i++ ) {
		qx{perl -i.bak -pe "s#(\s*)(?=<parameter name='IP' value='$wan_primary_ip'/>)#\$1<parameter name='IP' value='$ips[$i]'/>\n#\n" /etc/libvirt/qemu/$cust_id-$server_id.xml};
                write_log("Adding IP $ips[$i]\n");
                if($os_version eq "2012") {
                    system("echo netsh interface ipv4 add address Ethernet $ips[$i] 255.255.255.0 '> C:/iplog.txt' >> /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");
                    write_log("echo netsh interface ipv4 add address Ethernet $ips[$i] 255.255.255.0 >> /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");
		    }
                elsif($os_version eq "2008") {
                    system("$string2008 $ips[$i] 255.255.255.0 >> /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");
                    write_log("echo netsh interface ipv4 add address \"Local Area Connection\" $ips[$i] 255.255.255.0 >> /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");
		    }
                }
            }
            if($os_version eq "2008" || $os_version eq "2012") {
                write_log("Appending DEL %~f0\n");
	        qx{echo DEL %~f0 >> /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat};
            }
	    system("cp /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat /tmp/set-config-tmp.bat");
            system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml-bak > /dev/null");
            system("virsh undefine $cust_id-$server_id >/dev/null");
            system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml-bak /etc/libvirt/qemu/$cust_id-$server_id.xml > /dev/null");
            system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml >/dev/null");
#####################################################################################################################
############################################################################################
            system("virsh attach-disk --targetbus ide --type ide --live --persistent `virsh list|grep $cust_id-$server_id|cut -f2 -d' '` /var/lib/libvirt/images/$cust_id-$server_id.iso hdd >>/tmp/disklog 2>&1");
            system("umount /mnt/$cust_id-$server_id; rmdir /mnt/$cust_id-$server_id");
            system("virsh start $cust_id-$server_id >/dev/null");
	    system("sleep 10");
            return success;
        }
        return success;
    }
    return success;

}

#####################################################################################################################
################
################            Create New  Virtual Machine from Backup image or Custom Image
################
#####################################################################################################################

#/usr/local/sbin/qcreatevmfrombkup '29448' '1475' 'DEMO LTD' 'nfs1' '14' '2' 'linux' 'debian' '6.0' '32' 'server00023230123.com' '1' '1' '20' 'cumPGtppD0UhsxeJ0Aao' '16:00:00:00:00:68' '162.222.32.234' '' '5909' 'xDXfelvdST6BPKwxpQGX'}{ERROR_CODE = 1}

sub createVMFROMBKUP {

    my $cust_id           = shift;
    my $server_id         = shift;
    my $old_cust_id       = shift;
    my $old_server_id     = shift;
    my $cust_name         = shift;
    my $os_image_location = shift;
    my $backup_id         = shift;
    my $image_type        = shift;
    my $os_type           = shift;
    my $os_name           = shift;
    my $os_version        = shift;
    my $os_arch           = shift;
    my $hostname          = shift;
    my $ram               = shift;
    my $vcpu              = shift;
    my $storage           = shift;
    my $admin_password    = shift;
    my $wan_mac_address   = shift;
    my $wan_primary_ip    = shift;
    my $wan_sec_ip_list   = shift;
    my $vm_host_vnc_port  = shift;
    my $vnc_password      = shift;
    my $disk_path         = "/var/lib/libvirt/images/$cust_id-$server_id.qcow2";
    my $iso_path          = "/var/lib/libvirt/images/$cust_id-$server_id.iso";
    my $ram               = $ram * 1024;
    my $dm                = "G";
    my $host_ip_address   = "104.152.176.194";

    write_log("RESTORE VIRTUAL MACHINE FROM BACKUP SCRIPT CALLED :: \n");

###################  Create Virtual Machine #######################################################

    system("qemu-img create -f qcow2  -o preallocation=metadata /var/lib/libvirt/images/$cust_id-$server_id.qcow2 20$dm >/dev/null 2>/dev/null ");
    write_log("QCOW2 IMAGE HAS BEEN CREATED UNDER VAR-LIB-LIBVIRT-IMAGES-$cust_id-$server_id.qcow2");
    write_log("qemu-img create -f qcow2  -o preallocation=metadata /var/lib/libvirt/images/$cust_id-$server_id.qcow2 20$dm");
    system("touch $iso_path");    # create a dummy
    system("virt-install --connect qemu:///system --name $cust_id-$server_id --ram $ram --vcpus $vcpu --disk /var/lib/libvirt/images/$cust_id-$server_id.qcow2,format=qcow2 --graphics vnc,password=$vnc_password,port=$vm_host_vnc_port,listen=$host_ip_address --cdrom $iso_path --network network:phybrid,mac=$wan_mac_address >>/tmp/log 2>>/tmp/log");
    write_log("virt-install --connect qemu:///system --name $cust_id-$server_id --ram $ram --vcpus $vcpu --disk /var/lib/libvirt/images/$cust_id-$server_id.qcow2,format=qcow2 --graphics vnc,password=$vnc_password,port=$vm_host_vnc_port,listen=$host_ip_address --cdrom $iso_path --network network:phybrid,mac=$wan_mac_address");
    write_log("VIRT-INSTALL COMMAND CALLED FOR CUSTOMER ID $cust_id AND SERVER ID $server_id");
    system("virsh shutdown $cust_id-$server_id >/dev/null 2>/dev/null");
    while($? == 0) {
        write_log(" Machine still shutting down.");
        system("virsh list|grep -i $cust_id-$server_id >/dev/null");
        sleep(5);
    }
    write_log("VIRSH DESTROY $cust_id-$server_id   :: $?");
    if ( $? != 0 ) {
        write_log("Virtual Machine Not Created");
        system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
        write_log("REMOVE QCOW2 IMAGE FROM PATH : VAR-LIB-LIBVIRT-IMAGES-$cust_id-$server_id.qcow2 ");
        return fail;
    }
    if ( $image_type == 2 ) {
        if (-e "/$os_image_location/os_backup_images/$old_cust_id/$old_cust_id-$old_server_id/$old_cust_id-$old_server_id-$backup_id.qcow2") {
            write_log("cp -p /$os_image_location/os_backup_images/$old_cust_id/$old_cust_id-$old_server_id/$old_cust_id-$old_server_id-$backup_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2");
            system("cp -p /$os_image_location/os_backup_images/$old_cust_id/$old_cust_id-$old_server_id/$old_cust_id-$old_server_id-$backup_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null ; sleep 5"); 
        }
        else {
            system("virsh undefine $cust_id-$server_id");
            system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2");
            write_log("BACKUP ID NOT EXIST : /$os_image_location/os_backup_images/$cust_id/$cust_id-$server_id/$old_cust_id-$old_server_id-$backup_id.qcow2");
            return fail;
        }
    }
    else {
        if (
            -e "/$os_image_location/os_custom_images/$old_cust_id/$old_cust_id-$old_server_id/$old_cust_id-$old_server_id-$backup_id.qcow2"
          )
        {
            write_log("cp /$os_image_location/os_custom_images/$old_cust_id/$old_cust_id-$old_server_id/$old_cust_id-$old_server_id-$backup_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2");
            system("cp /$os_image_location/os_custom_images/$old_cust_id/$old_cust_id-$old_server_id/$old_cust_id-$old_server_id-$backup_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
            system("sleep 5");
        }
        else {
            system("virsh undefine $cust_id-$server_id");
            system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2");
            write_log("IMAGE ID NOT EXIST : /$os_image_location/os_custom_images/$old_cust_id/$old_cust_id-$old_server_id/$old_cust_id-$old_server_id-$backup_id.qcow2");
            return fail;
        }
    }

################# Setting Hostname and Public IP #######################
    system("mkdir -p /mnt/$cust_id-$server_id > /dev/null 2>&1");
    system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /tmp/mountlog 2>&1");

################# Calculate Gateway #############################################
    my @array1 = split( /\./, $wan_primary_ip );
    splice @array1, 3,4;    # perl Code to get the first three strings out of the splitted array
    my $wan_ip_gateway = join( ".", @array1 );     # Perl Code to join the first three spliced strings of array
####################################################################################################
######################## IP Assignment ###########################################################
write_log("Not touching IPs at all. Leaving them exactly as they were in the image. (image restore)");
=begin comment
    if ( $os_type eq "linux" ) {
        if ( ( $os_name eq "centos" ) || ( $os_name eq "redhat" ) ) {

            my $file ="/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3";
            system(">/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3");
            $line1 = "DEVICE=ens3";
            $line2 = "ONBOOT=yes";
            $line3 = "HOTPLUG=no";
            $line4 = "IPADDR=$wan_primary_ip";
            $line5 = "NETMASK=255.255.255.0";
            $line6 = "GATEWAY=$wan_ip_gateway.1";
            write_log("Adding IP $wan_primary_ip to file");

            if ( $response =
                   Append( $file, $line1 )
                && Append( $file, $line2 )
                && Append( $file, $line3 )
                && Append( $file, $line4 )
                && Append( $file, $line5 )
                && Append( $file, $line6 ) )
            {
                write_log(" IP Assignment $wan_primary_ip Successful ");
                my @ips = split( ',', $wan_sec_ip_list );
                my $ipsno = scalar(@ips);
                if ( $ipsno != 0 ) {
                    for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                        open( OUT,"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3:$i");
                        my $filei ="/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-ens3:$i";
                        $line7  = "DEVICE=ens3:$i";
                        $line8  = "ONBOOT=yes";
                        $line9  = "IPADDR=$ips[$i]";
                        $line10 = "NETMASK=255.255.255.0";
                        if ( $response =
                               Append( $filei, $line7 )
                            && Append( $filei, $line8 )
                            && Append( $filei, $line9 )
                            && Append( $filei, $line10 ) )
                        {
                            write_log(
                                "Additional IP- $ips[$i] assigned successfully"
                            );
                        }
                    }
                }
            }
            else {
                write_log(
                    "Something Went Wrong. Additional IP's assigmnet failed");
            }
            write_log("truncating old hostname file");
            system(">/mnt/$cust_id-$server_id/etc/sysconfig/network");
            system(">/mnt/$cust_id-$server_id/etc/udev/rules.d/70-persistent-net.rules");
            my $file = "/mnt/$cust_id-$server_id/etc/sysconfig/network";
            $line11 = "HOSTNAME=$hostname";
            Append( $file, $line11 );
            write_log(" Unmounting Disk");
        }
        elsif ( ( $os_name eq "debian" ) || ( $os_name eq "ubuntu" ) ) {
            my $file = "/mnt/$cust_id-$server_id/etc/network/interfaces";
            system(">/mnt/$cust_id-$server_id/etc/network/interfaces");
	    system("rm -rf /mnt/$cust_id-$server_id/etc/network/interfaces.d/eth0");
            $line6 = "auto eth0";
            $line1 = "iface eth0 inet static";
            $line2 = "address $wan_primary_ip";
            $line3 = "gateway $wan_ip_gateway.1";
            $line4 = "netmask 255.255.255.0";
            $line5 = "dns-nameservers 4.2.2.2";

            if ( $response =
                   Append( $file, $line6 )
                && Append( $file, $line1 )
                && Append( $file, $line2 )
                && Append( $file, $line3 )
                && Append( $file, $line4 )
                && Append( $file, $line5 ) )
            {
                write_log(" IP Assignment $wan_primary_ip Successful ");
################# Adding Additional IP's##############################################################################
                my @ips = split( ',', $wan_sec_ip_list );
                my $ipsno = scalar(@ips);
                if ( $ipsno != 0 ) {
                    for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                        $line7  = "auto eth0:$i";
                        $line8  = "iface eth0:$i inet static";
                        $line9  = "address $ips[$i]";
                        $line10 = "netmask 255.255.255.0";
                        if ( $response =
                               Append( $file, $line7 )
                            && Append( $file, $line8 )
                            && Append( $file, $line9 )
                            && Append( $file, $line10 ) )
                        {
                            write_log(
                                "Additional IP- $ips[$i] assigned successfully"
                            );
                        }
                    }
                }
            }
        }
        else {
            write_log("Something Went Wrong. Additional IP's assigmnet failed");
        }
=end comment
=cut
######################## Set Hostname ##################################################

        $line7 = "$hostname";
        write_log("SETTING HOSTNAME : $hostname ");
        my $file = "/mnt/$cust_id-$server_id/etc/hostname";
        system(">/mnt/$cust_id-$server_id/etc/hostname");
        Append( $file, $line7 );
        write_log(" Unmounting Disk");
#    }
#    else {
#        write_log("IP Assignment went wrong. Either disk was not mounted or file was not accessible");
#    }
######################### SET PASSWORDS ######################################################################
    if($os_type eq "linux") {
      $password_salt = qx{openssl passwd -1 $admin_password};    ##### Generate Password Salt
      $old_password_salt = qx{cat /mnt/$cust_id-$server_id/etc/shadow | grep root | cut -d: -f2};
      chomp $password_salt;
      chomp $old_password_salt;
      system("sed 's|$old_password_salt|$password_salt|g' /mnt/$cust_id-$server_id/etc/shadow > /mnt/$cust_id-$server_id/etc/shadow.new");
      system("cp -p /mnt/$cust_id-$server_id/etc/shadow /mnt/$cust_id-$server_id/etc/shadow.orig >/dev/null");
      system("cp -p /mnt/$cust_id-$server_id/etc/shadow.new /mnt/$cust_id-$server_id/etc/shadow >/dev/null");
      write_log("sed -i 's|$old_password_salt|$password_salt|' /mnt/$cust_id-$server_id/etc/shadow");
      write_log("SALTED password : $password_salt");
      write_log("OLD SALTED password : $old_password_salt");
      write_log("Password Changed to $admin_password");
    
    }
##system("cp /mnt/$cust_id-$server_id/etc/shadow /mnt/$cust_id-$server_id/etc/shadow-bak >/dev/null");   ###### Backup Shadow File
##qx{sed -i 's|$old_password_salt|$password_salt|' /mnt/$cust_id-$server_id/etc/shadow};
##write_log("Password Changed to $admin_password");
######################################################################################################################
##################### UnMount File system ############################################################################
    system("umount /mnt/$cust_id-$server_id");
    system("rm -rf /mnt/$cust_id-$server_id");
    if ( $os_type eq "windows" ) {
        system("virsh shutdown $cust_id-$server_id >/dev/null");
        write_log("NOT MAKING SCRIPT FOR WINDOWS IMAGE (BACKUP RESTORE) ");
=begin comment
        system("mkdir -p /tmp/$cust_id-$server_id");
        system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i /tmp/$cust_id-$server_id --rw > /tmp/mountlog 2>&1");
        system("cp -p /iso/set-config.bat /iso/set-config$cust_id-$server_id.bat");
        qx{sed -i 's|SVR-2K8-10|$host_name|g' /iso/set-config$cust_id-$server_id.bat};
        qx{sed -i 's|password|$admin_password|g' /iso/set-config$cust_id-$server_id.bat};
        qx{sed -i 's|192.168.1.10|$wan_primary_ip|g' /iso/set-config$cust_id-$server_id.bat};
        qx{sed -i 's|192.168.1.10|$wan_ip_gateway.1|g' /iso/set-config$cust_id-$server_id.bat};
        write_log("Copied set-config.bat to startup with IP $wan_primary_ip and password $admin_password.");
        system("cp /iso/set-config$cust_id-$server_id.bat /tmp/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");
       
=end comment
=cut
        system("umount /tmp/$cust_id-$server_id");
        system("rmdir /tmp/$cust_id-$server_id");
#        system("virsh start $cust_id-$server_id >/dev/null");
#        system("sleep 90");
    }


################## Modifying XML ##################################################################################################################
qx{perl -i.bak -pe "s#(\s*)(?=<source network='phybrid'/>)#\$1<filterref filter='clean-traffic'>\n\$1 <parameter name='IP' value='$wan_primary_ip'/>\n\$1</filterref>#\n"    /etc/libvirt/qemu/$cust_id-$server_id.xml};
    my @ips = split( ',', $wan_sec_ip_list );
    my $ipsno = scalar(@ips);
    if ( $ipsno != 0 ) {
        for ( $i = 0 ; $i < $ipsno ; $i++ ) {
            qx{perl -i.bak -pe "s#(\s*)(?=<parameter name='IP' value='$wan_primary_ip'/>)#\$1<parameter name='IP' value='$ips[$i]'/>\n#\n" /etc/libvirt/qemu/$cust_id-$server_id.xml};
        }
    }
    system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml-bak > /dev/null");
    system("virsh undefine $cust_id-$server_id >/dev/null");
    system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml-bak /etc/libvirt/qemu/$cust_id-$server_id.xml > /dev/null");
    system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml >/dev/null");
#####################################################################################################################
#############################################################################################
    system("virsh start $cust_id-$server_id >/dev/null");
    write_log("Server $cust_id-$server_id started successfully");
    system("sleep 5 >/dev/null; virsh destroy $cust_id-$server_id >/dev/null; virsh start $cust_id-$server_id >/dev/null");
    return success;
}

############################ Restore Virtual Machine
###########################################################################################################################

sub restoreVIRTUALMACHINE {
    my $cust_id           = shift;
    my $server_id         = shift;
    my $cust_name         = shift;
    my $os_image_location = shift;
    my $backup_id         = shift;
    my $image_type        = shift;
    my $os_type           = shift;
    my $os_name           = shift;
    my $os_version        = shift;
    my $os_arch           = shift;
    my $hostname          = shift;
    my $ram               = shift;
    my $vcpu              = shift;
    my $storage           = shift;
    my $disk_path         = "/var/lib/libvirt/images/$cust_id-$server_id.qcow2";
    my $iso_path          = "/var/lib/libvirt/images/$cust_id-$server_id.iso";
    my $admin_password    = shift;
    my $wan_mac_address   = shift;
    my $wan_primary_ip    = shift;
    my $wan_sec_ip_list   = shift;
    my $vm_host_vnc_port  = shift;
    my $vnc_password      = shift;
    my $ram               = $ram * 1024;
    my $dm                = "G";
    my $host_ip_address   = "104.152.176.194";

    write_log(
        "RESTORE :: restoreVIRTUALMACHINE ::VIRTUAL MACHINE SCRIPT CALLED :: \n"
    );

    write_log(
"CUSTOMER ID:$cust_id SERVER ID:$server_id CUSTOMER NAME:$cust_name OS_IMAGE_LOCATION:$os_image_location BACKUP ID:$backup_id IMAGE_TYPE:$image_type OS_TYPE:$os_type OS_NAME:$os_name OS_VERSION:$os_version OS_ARCH:$os_arch HOSTNAME:$hostname     "
    );

    write_log("CUSTOMER ID : $cust_id  HOSTNAME : $hostname ");

##########################################################################################
################ Destroy Existing Virtual Machine ########################################

    system("virsh shutdown $cust_id-$server_id  >/dev/null 2>/dev/null");
    write_log("virsh destroy $cust_id-$server_id\n");

    system(
"rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2  >/dev/null 2>/dev/null"
    );
    write_log("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2\n");

    system("virsh undefine $cust_id-$server_id  >/dev/null 2>/dev/null");
    write_log("virsh undefine $cust_id-$server_id\n");

###################  Create Virtual Machine #######################################################

    system(
"qemu-img create -f qcow2  -o preallocation=metadata /var/lib/libvirt/images/$cust_id-$server_id.qcow2 20$dm >/dev/null 2>/dev/null "
    );
    write_log(
"QCOW2 IMAGE HAS BEEN CREATED UNDER VAR-LIB-LIBVIRT-IMAGES-$cust_id-$server_id.qcow2"
    );
    write_log(
"qemu-img create -f qcow2  -o preallocation=metadata /var/lib/libvirt/images/$cust_id-$server_id.qcow2 20$dm"
    );
    system("touch $iso_path");    # create a dummy
    system(
"virt-install --connect qemu:///system --name $cust_id-$server_id --ram $ram --vcpus $vcpu --disk /var/lib/libvirt/images/$cust_id-$server_id.qcow2,format=qcow2 --graphics vnc,password=$vnc_password,port=$vm_host_vnc_port,listen=$host_ip_address --cdrom $iso_path --network network:phybrid,mac=$wan_mac_address >/dev/null  2>/dev/null"
    );
    write_log(
"virt-install --connect qemu:///system --name $cust_id-$server_id --ram $ram --vcpus $vcpu --disk /var/lib/libvirt/images/$cust_id-$server_id.qcow2,format=qcow2 --graphics vnc,password=$vnc_password,port=$vm_host_vnc_port,listen=$host_ip_address --cdrom $iso_path --network network:phybrid,mac=$wan_mac_address"
    );
    write_log(
"VIRT-INSTALL COMMAND CALLED FOR CUSTOMER ID $cust_id AND SERVER ID $server_id"
    );

    system("virsh shutdown $cust_id-$server_id >/dev/null 2>/dev/null");
    write_log("VIRSH DESTROY $cust_id-$server_id   :: $?");

    if ( $? != 0 ) {
        write_log("Virtual Machine Not Created");
        system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null");
        write_log("REMOVE QCOW2 IMAGE FROM PATH : VAR-LIB-LIBVIRT-IMAGES-$cust_id-$server_id.qcow2");
        return fail;
    }

    if ( $image_type == 2 ) {
        if (
            -e "/$os_image_location/os_backup_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$backup_id.qcow2"
          )
        {
            system(
"rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null"
            );
            write_log(
"cp /$os_image_location/os_backup_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$backup_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2"
            );
            system(
"cp /$os_image_location/os_backup_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$backup_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null"
            );
        }
        else {
            write_log(
"BACKUP ID NOT EXIST : /$os_image_location/os_backup_images/$cust_id/$cust_id-$server_id/$backup_id.qcow2"
            );
            return fail;
        }
    }
    else {
        if (
            -e "/$os_image_location/os_custom_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$backup_id.qcow2"
          )
        {
            system(
"rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null"
            );
            write_log(
"cp /$os_image_location/os_custom_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$backup_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2"
            );
            system(
"cp /$os_image_location/os_custom_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$backup_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null 2>/dev/null"
            );
        }
        else {
            write_log(
"BACKUP ID NOT EXIST : /$os_image_location/os_custom_images/$cust_id/$cust_id-$server_id/$backup_id.qcow2"
            );
            return fail;
        }
    }

################# Setting Hostname and Public IP #######################
    system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");
    system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null");
################ Calculate Gateway #############################################
    my @array1 = split( /\./, $wan_primary_ip )
      ;    # Perl Code to split strings of an ip address by delimiter "."
    splice @array1, 3,
      4;    # perl Code to get the first three strings out of the splitted array
    my $wan_ip_gateway = join( ".", @array1 )
      ;     # Perl Code to join the first three spliced strings of array
####################################################################################################
####################### IP Assignment ###########################################################
    if ( $os_type eq "linux" ) {
        if ( ( $os_name eq "centos" ) || ( $os_name eq "redhat" ) ) {

            my $file ="/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0";
            system(">/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0");
            $line1 = "DEVICE=eth0";
            $line2 = "ONBOOT=yes";
            $line3 = "HOTPLUG=no";
            $line4 = "IPADDR=$wan_primary_ip";
            $line5 = "NETMASK=255.255.255.0";
            $line6 = "GATEWAY=$wan_ip_gateway.1";
            write_log("Adding IP $wan_primary_ip to file");

            if ( $response =
                   Append( $file, $line1 )
                && Append( $file, $line2 )
                && Append( $file, $line3 )
                && Append( $file, $line4 )
                && Append( $file, $line5 )
                && Append( $file, $line6 ) )
            {
                write_log(" IP Assignment $wan_primary_ip Successful ");
                my @ips = split( ',', $wan_sec_ip_list );
                my $ipsno = scalar(@ips);
                if ( $ipsno != 0 ) {
                    for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                        open( OUT,
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i"
                        );
                        my $filei ="/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i";
                        $line7  = "DEVICE=eth0:$i";
                        $line8  = "ONBOOT=yes";
                        $line9  = "IPADDR=$ips[$i]";
                        $line10 = "NETMASK=255.255.255.0";
                        if ( $response =
                               Append( $filei, $line7 )
                            && Append( $filei, $line8 )
                            && Append( $filei, $line9 )
                            && Append( $filei, $line10 ) )
                        {
                            write_log(
                                "Additional IP- $ips[$i] assigned successfully"
                            );
                        }
                    }
                }
            }
            else {
                write_log("Something Went Wrong. Additional IP's assigmnet failed");
            }
            my $file = "/mnt/$cust_id-$server_id/etc/sysconfig/network";
            $line11 = "HOSTNAME=$host_name";
            Append( $file, $line11 );
            write_log(" Unmounting Disk");
        }
        elsif ( ( $os_name eq "debian" ) || ( $os_name eq "ubuntu" ) ) {
            my $file = "/mnt/$cust_id-$server_id/etc/network/interfaces";
            system(">/mnt/$cust_id-$server_id/etc/network/interfaces");
            $line6 = "auto eth0";
            $line1 = "iface eth0 inet static";
            $line2 = "address $wan_primary_ip";
            $line3 = "gateway $wan_ip_gateway.1";
            $line4 = "netmask 255.255.255.0";
            $line5 = "dns-nameservers 4.2.2.2";

            if ( $response =
                   Append( $file, $line6 )
                && Append( $file, $line1 )
                && Append( $file, $line2 )
                && Append( $file, $line3 )
                && Append( $file, $line4 )
                && Append( $file, $line5 ) )
            {
                write_log(" IP Assignment $wan_primary_ip Successful ");
################# Adding Additional IP's##############################################################################
                my @ips = split( ',', $wan_sec_ip_list );
                my $ipsno = scalar(@ips);
                if ( $ipsno != 0 ) {
                    for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                        $line7  = "auto eth0:$i";
                        $line8  = "iface eth0:$i inet static";
                        $line9  = "address $ips[$i]";
                        $line10 = "netmask 255.255.255.0";
                        if ( $response =
                               Append( $file, $line7 )
                            && Append( $file, $line8 )
                            && Append( $file, $line9 )
                            && Append( $file, $line10 ) )
                        {
                            write_log(
                                "Additional IP- $ips[$i] assigned successfully"
                            );
                        }
                    }
                }
            }
            else {
                write_log(
                    "Something Went Wrong. Additional IP's assigmnet failed");
            }
######################## Set Hostname ##################################################
            $line7 = "$hostname";
            write_log("SETTING HOSTNAME : $hostname ");
            my $file = "/mnt/$cust_id-$server_id/etc/hostname";
            system(">/mnt/$cust_id-$server_id/etc/hostname");
            Append( $file, $line7 );
            write_log(" Unmounting Disk");
        }
        else {
            write_log("IP Assignment went wrong. Either disk was not mounted or file was not accessible");
        }
######################### SET PASSWORDS ######################################################################
        $password_salt =
          qx{openssl passwd -1 $admin_password};    ##### Generate Password Salt
        $old_password_salt =
          qx{cat /mnt/$cust_id-$server_id/etc/shadow | grep root | cut -d: -f2};
        chomp $password_salt;
        chomp $old_password_salt;
        system(
"cp /mnt/$cust_id-$server_id/etc/shadow /mnt/$cust_id-$server_id/etc/shadow-bak >/dev/null"
        );                                          ###### Backup Shadow File
qx{sed -i 's|$old_password_salt|$password_salt|' /mnt/$cust_id-$server_id/etc/shadow};
        write_log("Password Changed to $admin_password");


######################################################################################################################
#################### UnMount File system ############################################################################
        system("umount /mnt/$cust_id-$server_id");
        system("rm -rf /mnt/$cust_id-$server_id");
    }

    elsif ( $os_type eq "windows" ) {

        system("virsh shutdown $cust_id-$server_id >/dev/null");
        system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");
        write_log("NOT MAKING SCRIPT FOR WINDOWS IMAGE :: BACKUP RESTORE");
=begin comment
        system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null");
        system("cp -p /iso/set-config.bat /iso/set-config$cust_id-$server_id.bat");
        system("cp -p /iso/script.txt /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/script.txt");
        qx{sed -i 's|SVR-2K8-10|$host_name|g' /iso/set-config$cust_id-$server_id.bat};
        qx{sed -i 's|password|$admin_password|g' /iso/set-config$cust_id-$server_id.bat};
        qx{sed -i 's|192.168.1.10|$wan_primary_ip|g' /iso/set-config$cust_id-$server_id.bat};

        system("cp /iso/set-config$cust_id-$server_id.bat /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");

        system("umount /mnt/$cust_id-$server_id");
        system("rm -rf /mnt/$cust_id-$server_id");
=end comment
=cut
        system("virsh start $cust_id-$server_id >/dev/null");
    #    system("sleep 90");

##system("virsh destroy $cust_id-$server_id >/dev/null");
##system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null");
##system("rm -rf /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat");
##system("sleep 10");
##system("rm -rf /mnt/$cust_id-$server_id");
##system("virsh start $cust_id-$server_id >/dev/null");
        #


       }

## end of windows machine script
################## Modifying XML ##################################################################################################################

qx{perl -i.bak -pe "s#(\s*)(?=<source network='phybrid'/>)#\$1<filterref filter='clean-traffic'>\n\$1 <parameter name='IP' value='$wan_primary_ip'/>\n\$1</filterref>#\n"    /etc/libvirt/qemu/$cust_id-$server_id.xml};
    my @ips = split( ',', $wan_sec_ip_list );
    my $ipsno = scalar(@ips);
    if ( $ipsno != 0 ) {
        for ( $i = 0 ; $i < $ipsno ; $i++ ) {
           qx{perl -i.bak -pe "s#(\s*)(?=<parameter name='IP' value='$wan_primary_ip'/>)#\$1<parameter name='IP' value='$ips[$i]'/>\n#\n" /etc/libvirt/qemu/$cust_id-$server_id.xml};
        }
    }
    system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml-bak > /dev/null");
    system("virsh undefine $cust_id-$server_id >/dev/null");
    system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml-bak /etc/libvirt/qemu/$cust_id-$server_id.xml > /dev/null");
    system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml >/dev/null");
#####################################################################################################################
############################################################################################



    system("virsh start $cust_id-$server_id >/dev/null");
    write_log("Server $cust_id-$server_id started successfully");
    system("virsh reboot $cust_id-$server_id >/dev/null");
    return success;
}

####################################################################################
### REBOOT VIRTUAL MACHINE
###
#####################################################################################

sub rebootVM {
    my $cust_id   = shift;
    my $server_id = shift;

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system(
"virsh list --all | grep -i $cust_id-$server_id | grep running >/dev/null"
        );
        if ( $? == 0 ) {
            system("virsh reboot  $cust_id-$server_id >/dev/null");
            write_log("Virtual Machine $cust_id-$server_id rebooted");
            system("sleep 3");
            return sucess;
        }
        else {
            write_log(
"MACHINE : $cust_id-$server_id IS POWERED OFF FOR CUSTOMER : $cust_id\n"
            );
            return fail;
        }
    }
    else {
        write_log(
            "MACHINE NOT EXIST : $cust_id-$server_id FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }
}

#####################################################################################
## CREATE PRIVATE NETWORK XML FILE
## #######################################################################
##
sub createnetworkXML {
    #
    my $cust_name = shift;
    my $cust_id   = shift;
    my $vlan_id   = shift;

    $line1  = "<network>";
    $line2  = "<name>$cust_id</name>";
    $line3  = "<forward mode='bridge'/>";
    $line4  = "<bridge name='br1'/>";
    $line5  = "<virtualport type='openvswitch'>";
    $line6  = "</virtualport>";
    $line7  = "<portgroup name='$cust_id'>";
    $line8  = "<vlan>";
    $line9  = "<tag id='$vlan_id'/>";
    $line10 = "</vlan>";
    $line11 = "</portgroup>";
    $line12 = "</network>";
    #
## Create File
    open( OUT, "/usr/share/libvirt/networks/$cust_id.xml" );
    my $file = "/usr/share/libvirt/networks/$cust_id.xml";
    if ( $response =
           Append( $file, $line1 )
        && Append( $file, $line2 )
        && Append( $file, $line3 )
        && Append( $file, $line4 )
        && Append( $file, $line5 )
        && Append( $file, $line6 )
        && Append( $file, $line7 )
        && Append( $file, $line8 )
        && Append( $file, $line9 )
        && Append( $file, $line10 )
        && Append( $file, $line11 )
        && Append( $file, $line12 ) )
    {
        write_log(
"Network FIle for customer $cust_name with $cust_id Created Successfully"
        );
        write_log("Defining Network and Starting it");
        system("virsh net-define /usr/share/libvirt/networks/$cust_id.xml");
        system("virsh net-start $cust_id");
        system("virsh net-autostart $cust_id");
    }
    else { write_log("Cannot Write File"); }
}

##########################################################################################
# ENABLE PRIVATE NETWORK
###########################################################################################

sub enableprivateNET {
    my $cust_name       = shift;
    my $cust_id         = shift;
    my $server_id       = shift;
    my $vlan_id         = shift;
    my $lan_mac_address = shift;
    my $kvm_host_ips    = shift;
    my $lan_host_ip     = shift;
    my $os_name         = shift;
    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        write_log("Virtual Machine for Customer $cust_id exists");

        if ( -e "/usr/share/libvirt/networks/$cust_id.xml" ) {
            write_log("Network Exists for $cust_id");
        }
        else {
            write_log("Creating Network for $cust_id");
            createnetworkXML( $cust_name, $cust_id, $vlan_id );
        }

        ###### Editing Virtual Machine File
        write_log("Attaching New NIC to Virtual Machine");
        system(
"virsh attach-interface $cust_id-$server_id --type network --source $cust_id --persistent --mac '$lan_mac_address'  > /dev/null"
        );
        write_log("NIC attached. Powering off Virtual Machine");
        system("virsh shutdown $cust_id-$server_id > /dev/null");
        write_log("Virtual Machine Shut down");
        my $file  = "/etc/libvirt/qemu/$cust_id-$server_id.xml";
        my $line  = "<source network='$cust_id'/>";
        my $line1 = "<source network='$cust_id' portgroup='$cust_id'/>";

        if ( $response = Change( $file, $line, $line1 ) ) {
            write_log("PortGroup added successfully");
            system(
"mv /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml-bak > /dev/null"
            );
            system("virsh undefine $cust_id-$server_id >/dev/null");
            system(
"mv /etc/libvirt/qemu/$cust_id-$server_id.xml-bak /etc/libvirt/qemu/$cust_id-$server_id.xml > /dev/null"
            );
            system(
"virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml >/dev/null"
            );

            ############## LAN IP ASSIGNMENT ###########
            system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");
            system(
"guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null"
            );

            if ( ( $os_name eq "debian" ) || ( $os_name eq "ubuntu" ) ) {

qx{echo "auto eth1" > /mnt/$cust_id-$server_id/etc/network/interfaces};
qx{echo "iface eth1 inet static" >> /mnt/$cust_id-$server_id/etc/network/interfaces};
qx{echo "address $lan_host_ip" >> /mnt/$cust_id-$server_id/etc/network/interfaces};
qx{echo "netmask 255.255.255.0" >> /mnt/$cust_id-$server_id/etc/network/interfaces};

                write_log(
                    "LAN IP : $lan_host_ip IS ASSIGNED TO $cust_id-$server_id\n"
                );
            }
            elsif ( ( $os_name eq "centos" ) || ( $os_name eq "redhat" ) ) {

                system(
"touch /mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth1 > /dev/null"
                );
qx{echo "DEVICE=eth1" >> /mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth1};
qx{echo "ONBOOT=yes" >> /mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth1};
qx{echo "IPADDR=$lan_host_ip" >> /mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth1};
qx{echo "NETMASK=255.255.255.0" >> /mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth1};
            }

            system("umount /mnt/$cust_id-$server_id >/dev/null");
            system("rm -rf /mnt/$cust_id-$server_id >/dev/null");

            ##################################################

            system("virsh start $cust_id-$server_id > /dev/null");
            write_log("Private Network Added successfully");
        }
        else {
            write_log("Portgroup Not Added. private Network Assignment failed");
            return fail;
        }

        if ( $kvm_host_ips ne "" ) {
            ####### Check Connectivity Between Physical Hosts ######
            write_log("Checking Physical Connectivity Between KVM Hosts");
            my @ips = split( ',', $kvm_host_ips );
            my $ipsno = scalar(@ips);
            for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                $gretunno =
                  qx{cat /usr/local/sbin/gretunnelrecords/tunnelnumber}
                  ;    # Get Tunnel Number
                $gretunno = $gretunno + 1;    ### Increase Gre Tunnel By 1
                system(
"echo $gretunno > /usr/local/sbin/gretunnelrecords/tunnelnumber"
                );
qx{ovs-vsctl add-port br1 gre$gretunno -- set interface gre$gretunno type=gre options:remote_ip=$ips[$i]}
                  ;                           #Enable OVS Interface
            }
            write_log("Connectivity Established Between KVM Hosts");
        }
        return success;
    }
    else {
        write_log(
"Server not exist for Customer: $Cust_id and Host :: $Cust_id-$server_id \n"
        );
        return fail;
    }
}

#######################################################################
# Disable Private Network
# ####################################################################
sub disprivNETWORK {

    my $cust_name       = shift;
    my $cust_id         = shift;
    my $server_id       = shift;
    my $lan_mac_address = shift;

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        write_log("Virtual Machine for Customer $cust_id exists");
        write_log("Detaching Network for $cust_name");
        system(
"virsh detach-interface --domain $cust_id-$server_id --type network --mac $lan_mac_address --persistent > /dev/null"
        );
        write_log("Private Network Disabled for $cust_id-$server_id");
        return success;
    }
    else {
        write_log("Virtual Machine does not Exists");
        return fail;
    }
    system("virsh reboot $cust_id-$server_id > /dev/null");

}

############################################################################################
# CLone Virtual Machine
# ############################################################################################
sub vmCLONE {

    my $client_name  = shift;
    my $server_id    = shift;
    my $clone_vmname = shift;

    system("virsh shutdown $client_name-$server_id");
    system(
"virt-clone --original $client_name-$server_id --name $client_name-$clone_vmname -f /var/lib/libvirt/images/$client_name-$clone_vmname.qcow2"
    );
    system("virsh start $client_name-$server_id");

}

###########################################################################
## Create Backup Of Virtual Machine
################################################################
sub createBACKUP {
    my $cust_id          = shift;
    my $server_id        = shift;
    my $retention_period = shift;
    my $backup_id        = shift;
    my $image_location   = shift;
    write_log("CREATEBACKUP SCRIPT CALLED\n");

####################################################################
## Checking if server is running
    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        ## Taking snapshot

        if (-e "/var/lib/libvirt/images/$cust_id-$server_id-snap$backup_id.qcow2"){
            write_log("Snapshot file is already exist :/var/lib/libvirt/images/$cust_id-$server_id-snap$backup_id.qcow2");
            return fail;
        }
		
		system("virsh snapshot-create-as $cust_id-$server_id $cust_id-$server_id-snap$backup_id  --diskspec hda,file=/$image_location/os_backup_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$backup_id.qcow2 --disk-only --atomic > /dev/null");
		
        if (!-d "/$image_location/os_backup_images/$cust_id/$cust_id-$server_id/") {
            system("mkdir -p /$image_location/os_backup_images/$cust_id/$cust_id-$server_id/");
        }	
        

        ## Copying Server Image at backup location
        system("cp -rp /var/lib/libvirt/images/$cust_id-$server_id.qcow2 /$image_location/os_backup_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$backup_id.qcow2 > /dev/null");
        ## Using Blockcommit Method to Merge Snapshot into base image
        ######system("virsh blockcommit $cust_id-$server_id hda --active --pivot --verbose > /dev/null");
        system("virsh blockcommit $cust_id-$server_id hda --active --pivot --verbose > /dev/null  2>/dev/null");

		write_log("virsh snapshot-delete $cust_id-$server_id --snapshotname $cust_id-$server_id-snap$backup_id --metadata");

		system("virsh snapshot-delete $cust_id-$server_id --snapshotname $cust_id-$server_id-snap$backup_id --metadata > /dev/null");
        return success;
    }
    else {
        write_log(
            "MACHINE NOT EXIST : $cust_id-$server_id FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }
}


##################################################################
# Create Custom Image of VM
# #################################################################
sub createcustomIMAGE {

    my $cust_id             = shift;
    my $server_id           = shift;
    my $custom_img_id       = shift;
    my $custom_img_location = shift;
    write_log("CREATE CUSTOM BACKUP SCRIPT CALLED\n");
    write_log(
"taking backup of $cust_id-$server_id server image $custom_img_id at $custom_img_location\n"
    );

####################################################################
## Checking if server is running
    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        ## Taking snapshot

        if (
            -e "/var/lib/libvirt/images/$cust_id-$server_id-snap$custom_img_id.qcow2"
          )
        {
            write_log(
"Snapshot file is already exist :/var/lib/libvirt/images/$cust_id-$server_id-snap$custom_img_id.qcow2"
            );
            return fail;
        }
        write_log(
"virsh snapshot-create-as $cust_id-$server_id $cust_id-$server_id-snap$custom_img_id  --diskspec hda,file=/var/lib/libvirt/images/$cust_id-$server_id-snap$custom_img_id.qcow2 --disk-only --atomic"
        );
        system(
"virsh snapshot-create-as $cust_id-$server_id $cust_id-$server_id-snap$custom_img_id  --diskspec hda,file=/var/lib/libvirt/images/$cust_id-$server_id-snap$custom_img_id.qcow2 --disk-only --atomic > /dev/null"
        );

        if (
            !-d "/$custom_img_location/os_custom_images/$cust_id/$cust_id-$server_id/"
          )
        {
            system(
"mkdir -p /$custom_img_location/os_custom_images/$cust_id/$cust_id-$server_id/"
            );
        }

        ## Copying Server Image at backup location
        system(
"cp -rp /var/lib/libvirt/images/$cust_id-$server_id.qcow2 /$custom_img_location/os_custom_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$custom_img_id.qcow2 > /dev/null"
        );
        write_log(
"coping cp -rp /var/lib/libvirt/images/$cust_id-$server_id.qcow2 /$custom_img_location/os_custom_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$custom_img_id.qcow2"
        );
        write_log(
"virsh blockcommit $cust_id-$server_id hda --active --pivot --verbose"
        );
        system(
"virsh blockcommit $cust_id-$server_id hda --active --pivot --verbose > /dev/null  2>/dev/null"
        );

        system(
"virsh snapshot-delete $cust_id-$server_id --snapshotname $cust_id-$server_id-snap$custom_img_id --metadata > /dev/null"
        );
        write_log(
"virsh snapshot-delete $cust_id-$server_id --snapshotname $cust_id-$server_id-snap$custom_img_id --metadata"
        );
        system(
"rm -rf /var/lib/libvirt/images/$cust_id-$server_id-snap$custom_img_id.qcow2"
        );
        return success;
    }
    else {
        write_log(
            "MACHINE NOT EXIST : $cust_id-$server_id FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }

}

######################################################################################
## Restore With Custom Image
#######################################################################################
sub restorecustomIMAGE {
    my $cust_id             = shift;
    my $server_id           = shift;
    my $custom_img_id       = shift;
    my $custom_img_location = shift;
    my $os_type             = shift;
    my $os_name             = shift;
    my $wan_primary_ip      = shift;
    my $wan_sec_ip_list     = shift;
    my $date                = `date +%Y%m%d`;
    chomp($date);

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system(
"virsh list --all | grep -i $cust_id-$server_id | grep running > /dev/null"
        );
        if ( $? == 0 ) {
            system("virsh shutdown $cust_id-$server_id > /dev/null");
        }
        ## CHeck for Custome Image File Exists or Not
        if (
            -e "$custom_img_location/$cust_id-$server_id/$cust_id-$server_id-$custom_img_id.qcow2"
          )
        {
            write_log(" Custom Image FIle Exists. Restoring it");
            system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2");
            system(
"cp -rp $custom_img_location/$cust_id-$server_id/$cust_id-$server_id-$custom_img_id.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2"
            );
            write_log(" Image Restored. Moving Ahead to Restore State of VM");
            system(
"cp -rp /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml.bak"
            );
            system("virsh undefine $cust_id-$server_id");
            system(
"cp -rp /etc/libvirt/qemu/$cust_id-$server_id.xml.bak /etc/libvirt/qemu/$cust_id-$server_id.xml"
            );
            system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml");
            write_log("VM State Restored");
            #### Assigning the current State of IP's #######################
            my @array1 = split( /\./, $wan_primary_ip )
              ;   # Perl Code to split strings of an ip address by delimiter "."
            splice @array1, 3, 4
              ; # perl Code to get the first three strings out of the splitted array
            my $wan_ip_gateway = join( ".", @array1 )
              ;    # Perl Code to join the first three spliced strings of array
            system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");
            system(
"guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null"
            );
####################################################################################################
######################## IP Assignment ###########################################################
            if ( $os_type eq "linux" ) {
                if ( ( $os_name eq "centos" ) || ( $os_name eq "redhat" ) ) {
                    my $file =
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0";
                    system(
">/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0"
                    );
                    $line1 = "DEVICE=eth0";
                    $line2 = "ONBOOT=yes";
                    $line3 = "HOTPLUG=no";
                    $line4 = "IPADDR=$wan_primary_ip";
                    $line5 = "NETMASK=255.255.255.0";
                    $line6 = "GATEWAY=$wan_ip_gateway.1";
                    write_log("Adding IP $wan_primary_ip to file");

                    if ( $response =
                           Append( $file, $line1 )
                        && Append( $file, $line2 )
                        && Append( $file, $line3 )
                        && Append( $file, $line4 )
                        && Append( $file, $line5 )
                        && Append( $file, $line6 ) )
                    {
                        write_log(" IP Assignment $wan_primary_ip Successful ");
                        my @ips = split( ',', $wan_sec_ip_list );
                        my $ipsno = scalar(@ips);
                        if ( $ipsno != 0 ) {
                            for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                                open( OUT,
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i"
                                );
                                my $filei =
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i";
                                $line7  = "DEVICE=eth0:$i";
                                $line8  = "ONBOOT=yes";
                                $line9  = "IPADDR=$ips[$i]";
                                $line10 = "NETMASK=255.255.255.0";
                                if ( $response =
                                       Append( $filei, $line7 )
                                    && Append( $filei, $line8 )
                                    && Append( $filei, $line9 )
                                    && Append( $filei, $line10 ) )
                                {
                                    write_log(
"Additional IP- $ips[$i] assigned successfully"
                                    );
                                }
                            }
                        }
                    }
                    else {
                        write_log(
"Something Went Wrong. Additional IP's assigmnet failed"
                        );
                    }
                    write_log(" Unmounting Disk");
                }
                elsif ( ( $os_name eq "debian" ) || ( $os_name eq "ubuntu" ) ) {
                    my $file =
                      "/mnt/$cust_id-$server_id/etc/network/interfaces";
                    system(">/mnt/$cust_id-$server_id/etc/network/interfaces");
                    $line6 = "auto eth0";
                    $line1 = "iface eth0 inet static";
                    $line2 = "address $wan_primary_ip";
                    $line3 = "gateway $wan_ip_gateway.1";
                    $line4 = "netmask 255.255.255.0";
                    $line5 = "dns-nameservers 4.2.2.2";

                    if ( $response =
                           Append( $file, $line6 )
                        && Append( $file, $line1 )
                        && Append( $file, $line2 )
                        && Append( $file, $line3 )
                        && Append( $file, $line4 )
                        && Append( $file, $line5 ) )
                    {
                        write_log(" IP Assignment $wan_primary_ip Successful ");
                        ################# Adding Additional IP's##############################################################################
                        my @ips = split( ',', $wan_sec_ip_list );
                        my $ipsno = scalar(@ips);
                        if ( $ipsno != 0 ) {
                            for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                                $line7  = "auto eth0:$i";
                                $line8  = "iface eth0:$i inet static";
                                $line9  = "address $ips[$i]";
                                $line10 = "netmask 255.255.255.0";
                                if ( $response =
                                       Append( $file, $line7 )
                                    && Append( $file, $line8 )
                                    && Append( $file, $line9 )
                                    && Append( $file, $line10 ) )
                                {
                                    write_log(
"Additional IP- $ips[$i] assigned successfully"
                                    );
                                }
                            }
                        }
                    }
                    else {
                        write_log(
"Something Went Wrong. Additional IP's assigmnet failed"
                        );
                    }
                }
            }
            write_log("Image Restored Sucessfully");
            system("virsh start $cust_id-$server_id >/dev/null");
            system("umount /mnt/$cust_id-$server_id >/dev/null");
            system("rm -rf /mnt/$cust_id-$server_id >/dev/null");
            return success;
        }
    }
    else {
        write_log("Image or VM doesn't exists");
        return fail;
    }
}

#################################################
## Delete Backup Custom imageof VM
###########################################
sub delBACKUP {

    my $cust_id          = shift;
    my $server_id        = shift;
    my $retention_days   = shift;
    my $bkp_img_id       = shift;
    my $bkp_img_location = shift;

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        if (
            -e "/$bkp_img_location/os_backup_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$bkp_img_id.qcow2"
          )
        {
            system(
"rm  -rf /$bkp_img_location/os_backup_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$bkp_img_id.qcow2"
            );
            write_log(
" BACKUP DELETED FROM PATH : /$bkp_img_location/os_backup_images/$cust_id/$cust_id-$server_id/$bkp_img_id.qcow2"
            );
            return success;
        }
        else {
            write_log(
"IMAGE NOT FOUND ::  $cust_id-$server_id-$bkp_img_id.qcow2 : FOR CUSTOMER $cust_id HOST :$server_id"
            );
            return fail;
        }
    }
    else {
        write_log(
            "MACHINE NOT EXIST : $cust_id-$server_id FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }
}

#################################################
## Delete Backup Image of VM
###########################################
sub deleteBACKUP {

    my $cust_id          = shift;
    my $server_id        = shift;
    my $retention_period = shift;
    my $backup_id        = shift;

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system(
            "rm -rf /mnt/os_backup_images/$cust_id-$server_id/$backup_id.qcow2"
        );
        return success;
    }
    else {
        write_log(
            "MACHINE NOT EXIST : $cust_id-$server_id FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }
}

################################################
# Delete Custom VM Image
# ####################################################
sub delcustomIMAGE {

    my $cust_id             = shift;
    my $server_id           = shift;
    my $custom_img_id       = shift;
    my $custom_img_location = shift;

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        if (
            -e "/$custom_img_location/os_custom_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$custom_img_id.qcow2"
          )
        {
            system(
"rm  -rf /$custom_img_location/os_custom_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$custom_img_id.qcow2"
            );
            write_log(
" BACKUP DELETED FROM PATH : /$custom_img_location/os_custom_images/$cust_id/$cust_id-$server_id/$cust_id-$server_id-$custom_img_id.qcow2"
            );
            return success;
        }
        else {
            write_log(
"BACKUP IMAGE : $cust_id-$server_id-$custom_img_id.qcow2  FOR CUSTOMER $cust_id FOR HOST $server_id "
            );
            return fail;
        }

    }
    else {
        write_log(
            "MACHINE NOT EXIST : $cust_id-$server_id FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }

}

###################################################################
# Delete Virtual Machine
# ####################################################################
sub delVIRTUALMACHINE {
    my $cust_id   = shift;
    my $server_id = shift;
    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system(
"virsh list --all | grep -i $cust_id-$server_id | grep running >/dev/null"
        );
        if ( $? == 0 ) {
            system("virsh destroy $cust_id-$server_id >/dev/null");
            write_log(
                "MACHINE : $cust_id-$server_id SHUTDOWN FOR CLIENT : $cust_id\n"
            );
        }
        system("virsh undefine $cust_id-$server_id >/dev/null");
        write_log(
            "MACHINE : $cust_id-$server_id UNDEFINE FOR CLIENT : $cust_id\n");
        system(
"rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2 >/dev/null"
        );
 system(
"rm -rf /var/lib/libvirt/images/$cust_id-$server_id.iso >/dev/null"
        );

        system(
            "rm -rf /etc/libvirt/qemu/$cust_id-$server_id.xml.bak >/dev/null");
        write_log("IMAGE $cust_id-$server_id.qcow2 HAS BEEN DELETED\n");
        return success;
    }
    else {
        write_log(
"$cust_id-$server_id : MACHINE DOES NOT EXIST FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }

}
####################################################################
##  SSH Key Base Authentication Enable for Server
###################################################################

sub sshkeygenerate {
    my $cust_id      = shift;
    my $server_id    = shift;
    my $sshkey_value = shift;
    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system("virsh destroy $cust_id-$server_id >/dev/null 2>/dev/null");
        write_log("virsh destroy $cust_id-$server_id\n");
        system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");

        system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /tmp/mountlog 2>&1");
        my @arr_sshkey = split( ',', $sshkey_value );
        my $sshkeyno = scalar(@arr_sshkey);
        for ( $i = 0 ; $i < $sshkeyno ; $i++ ) {

            if ( -e "/mnt/$cust_id-$server_id/root/.ssh/authorized_keys" ) {
                system(
"echo $arr_sshkey[$i] >> /mnt/$cust_id-$server_id/root/.ssh/authorized_keys"
                );
                write_log("AUTHORIZED KEYS FILE IS ALREADY EXIST\n");
                write_log("\n$arr_sshkey[$i]\n");
            }
            else {
                system(
"touch /mnt/$cust_id-$server_id/root/.ssh/authorized_keys >/dev/null 2>/dev/null"
                );
                my $file = "/mnt/$cust_id-$server_id/root/.ssh/authorized_keys";
                write_log("AUTHORIZED KEYS FILE HAS BEEN CREATED \n");
                Append( $file, $arr_sshkey[$i] );
                write_log("\n$arr_sshkey[$i]\n");
            }
        }
        system("umount /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
        system("rm -rf /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
        system("virsh start $cust_id-$server_id >/dev/null 2>/dev/null");
        return success;
    }
    else {
        write_log(
"$cust_id-$server_id : MACHINE DOES NOT EXIST FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }

}

####################################################################
##  SSH Key Base Authentication disable for Server
###################################################################

sub sshkeydelete {
    my $cust_id      = shift;
    my $server_id    = shift;
    my $sshkey_value = shift;
    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system("virsh destroy $cust_id-$server_id >/dev/null 2>/dev/null");
        write_log("SSH KEY DELETION SCRIPT CALLED \n");
        write_log("virsh destroy $cust_id-$server_id\n");
        system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");
        system(
"guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null"
        );
        my @arr_sshkey = split( ',', $sshkey_value );
        my $sshkeyno = scalar(@arr_sshkey);
        if ( -e "/mnt/$cust_id-$server_id/root/.ssh/authorized_keys" ) {

            system("umount /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
            system("rm -rf /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
            write_log("AUTHORIZED_KEYS FILE NOT EXIST\n");
            system("virsh start $cust_id-$server_id >/dev/null 2>/dev/null");
            return fail;

        }

        for ( $i = 0 ; $i < $sshkeyno ; $i++ ) {

            system(
"sed -i 's|$arr_sshkey[$i]||' /mnt/$cust_id-$server_id/root/.ssh/authorized_keys"
            );
            write_log("AUTHORIZED KEYS FILE IS ALREADY EXIST\n");
            write_log("\n$arr_sshkey[$i] :: Deleted\n \n");

        }
        system("umount /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
        system("rm -rf /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
        system("virsh start $cust_id-$server_id >/dev/null 2>/dev/null");
        return success;
    }
    else {
        write_log(
"$cust_id-$server_id : MACHINE DOES NOT EXIST FOR CUSTOMER : $cust_id\n"
        );
        return fail;
    }

}

## Revert Virtual Machine Snapshot
##################################################################
sub vmREVERTSS {
    my $cust_id    = shift;
    my $server_id  = shift;
    my $snapshotid = shift;

    system("virsh destroy $cust_id-$server_id");
    system("virsh snapshot-revert $cust_id-$server_id $snapshotid");
    system("virsh destroy $cust_id-$server_id");
    system("virsh start $cust_id-$server_id");
    return success;
}

###########################################################
# Take Virtual Machine Snapshot
# ######################################################
sub vmSNAPSHOT {

    my $cust_id   = shift;
    my $server_id = shift;

    system("virsh snapshot-create $cust_id-$server_id");
    write_log("Snapshot successfully created");
    return success;

}

################################################################################################
### Create and Attach Volume
#################################################################################
sub attachVolume {
    my $cust_id     = shift;
    my $server_id   = shift;
    my $volume_name = shift;
    my $storage     = shift;
    my $dm          = 'G';

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system(
"virsh list --all | grep -i $cust_id-$server_id | grep running >/dev/null"
        );
        if ( $? == 0 ) {
            write_log("Creating New Disk for $cust_id-$server_id");
            system("qemu-img create -f qcow2  -o preallocation=metadata /var/lib/libvirt/images/$cust_id-$server_id-$volume_name.qcow2 $storage$dm >/tmp/log 2>/tmp/log");
#            system("virsh attach-disk `virsh list|grep $cust_id-$server_id|cut -f2 -d' '` /var/lib/libvirt/images/$cust_id-$server_id-$volume_name.qcow2 $volume_name --driver qemu --subdriver qcow2 --persistent >/tmp/log 2>/tmp/log");
            system("virsh attach-disk `virsh list|grep $cust_id-$server_id|cut -f2 -d' '` /var/lib/libvirt/images/$cust_id-$server_id-$volume_name.qcow2 vdb$volume_name --driver qemu --subdriver qcow2 --persistent >/tmp/log 2>/tmp/log");
	   write_log("virsh attach-disk `virsh list|grep $cust_id-$server_id|cut -f2 -d' '` /var/lib/libvirt/images/$cust_id-$server_id-$volume_name.qcow2 vdb$volume_name --driver qemu --subdriver qcow2 --persistent ");
            write_log("New Volume $volume_name attached to $cust_id-$server_id");
            #system("virsh destroy $cust_id-$server_id >/dev/null");
            write_log("Rebooting Machine: $cust_id-$server_id");
            #system("virsh start $cust_id-$server_id >/dev/null");
            write_log("Machine Started");
            return success;
        }
        else {
            write_log(
"$cust_id-$server_id : MACHINE DOES NOT EXIST FOR CUSTOMER : $cust_id\n"
            );
            return fail;
        }

    }
}

################################################################################################
#### Detach and Delete Volume
##################################################################################
sub detachVolume {
    my $cust_id     = shift;
    my $server_id   = shift;
    my $volume_name = shift;

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system(
"virsh list --all | grep -i $cust_id-$server_id | grep running >/dev/null"
        );
        if ( $? == 0 ) {
            write_log("Deleting Disk for $cust_id-$server_id");
            system(
"virsh detach-disk $cust_id-$server_id /var/lib/libvirt/images/$cust_id-$server_id-$volume_name.qcow2 --persistent >/dev/null 2>/dev/null"
            );
	    write_log("virsh detach-disk $cust_id-$server_id /var/lib/libvirt/images/$cust_id-$server_id-$volume_name.qcow2 --persistent");
            system(
"rm -rf /var/lib/libvirt/images/$cust_id-$server_id-$volume_name.qcow2 >/dev/null 2>/dev/null"
            );
            write_log(" Volume $volume_name detached from $cust_id-$server_id");
            #system("virsh destroy $cust_id-$server_id >/dev/null");
            #write_log("Rebooting Machine: $cust_id-$server_id");
            #system("virsh start $cust_id-$server_id >/dev/null");
            #write_log("Machine Started");
            return success;
        }
}
        else {
            write_log(
"$cust_id-$server_id : MACHINE DOES NOT EXIST FOR CUSTOMER : $cust_id\n"
            );
            return fail;
        }
    
}

#################################################################################################
#### DeAllocate Additional Public IP's to guest machines
#### #################################################################################################
sub deallocatePIP {
###
    my $cust_id             = shift;
    my $server_id           = shift;
    my $cust_name           = shift;
    my $os_type             = shift;
    my $os_name             = shift;
    my $wan_primary_ip      = shift;
    my $wan_sec_iprem_list  = shift;
    my $wan_sec_ipleft_list = shift;
########################################################################################################
### Check for Machine's Existance
    write_log("IP deallocation script called");
    write_log(
"PRIMARY IP : $wan_primary_ip SECONDRY IP LIST wan_sec_iprem_list : $wan_sec_iprem_list and wan_sec_ipleft_list : $wan_sec_ipleft_list \n"
    );
    my @ips    = split( ',', $wan_sec_ipleft_list );
    my @ipsrem = split( ',', $wan_sec_iprem_list );
    my $ipsno  = scalar(@ips);
    my $ipsremno = scalar(@ipsrem);
    my @array1 = split( /\./, $wan_primary_ip )
      ;    # Perl Code to split strings of an ip address by delimiter "."
    splice @array1, 3,
      4;    # perl Code to get the first three strings out of the splitted array
    my $wan_ip_gateway = join( ".", @array1 )
      ;     # Perl Code to join the first three spliced strings of array

    if ( !-f "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        write_log("Machine $cust_id-$server_id doesn't exists");
        return fail;
    }
    else {
        write_log("Machine name $cust_id-$server_id  exist ");
        system(
            "virsh list | grep -i $cust_id-$server_id >/dev/null 2>/dev/null")
          ;    ###### Check for guest machine state
        if ( $? == 0 ) {
            write_log(" Machine is Running.Powering it off ");
            system("virsh shutdown $cust_id-$server_id >/dev/null 2>/dev/null");
            while($? == 0) {
                write_log(" Machine still shutting down.");
                system("virsh list|grep -i $cust_id-$server_id >/dev/null");
                sleep(5);
            }
            if ( -d "/mnt/$cust_id-$server_id" ) {
                write_log(
                    " Machine is already Monuted. Deallocating IP's from it");
            }
            else {
                write_log("Mouting Disk");
                system(
                    "mkdir -p /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
                system(
"guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id >/dev/null 2>/dev/null"
                );
            }
        }
    }
####### Remove Ip Address
    if ( $os_type eq "linux" ) {
        if ( ( $os_name eq "centos" ) || ( $os_name eq "redhat" ) ) {
            system(
"rm -rf /mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:*"
            );
            for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                open( OUT,
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i"
                );
                my $filei =
"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i";
                $line7  = "DEVICE=eth0:$i";
                $line8  = "ONBOOT=yes";
                $line9  = "IPADDR=$ips[$i]";
                $line10 = "NETMASK=255.255.255.0";
                if ( $response =
                       Append( $filei, $line7 )
                    && Append( $filei, $line8 )
                    && Append( $filei, $line9 )
                    && Append( $filei, $line10 ) )
                {
                    write_log("IP's deallocated successfully");
                }
            }
        }
        elsif ( ( $os_name eq "debian" ) || ( $os_name eq "ubuntu" ) ) {
            system("rm -rf /mnt/$cust_id-$server_id/etc/network/interfaces");
            open( OUT, "/mnt/$cust_id-$server_id/etc/network/interfaces" );
            my $file = "/mnt/$cust_id-$server_id/etc/network/interfaces";
            $line1  = "auto eth0";
            $line2  = "iface eth0 inet static";
            $line3  = "address $wan_primary_ip";
            $line4  = "netmask 255.255.255.0";
            $line5  = "gateway $wan_ip_gateway.1";
            $line6  = "dns-nameservers 4.2.2.2";
            $line7  = "auto lo";
            $line8  = "iface lo inet static";
            $line9  = "address 127.0.0.1";
            $line10 = "netmask 255.0.0.0";

            if ( $response =
                   Append( $file, $line1 )
                && Append( $file, $line2 )
                && Append( $file, $line3 )
                && Append( $file, $line4 )
                && Append( $file, $line5 )
                && Append( $file, $line6 )
                && Append( $file, $line7 )
                && Append( $file, $line8 )
                && Append( $file, $line9 )
                && Append( $file, $line10 ) )
            {
                write_log("primary IP defined successfully");
            }
            for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                $line7  = "auto eth0:$i";
                $line8  = "iface eth0:$i inet static";
                $line9  = "address $ips[$i]";
                $line10 = "netmask 255.255.255.0";
                if ( $response =
                       Append( $file, $line7 )
                    && Append( $file, $line8 )
                    && Append( $file, $line9 )
                    && Append( $file, $line10 ) )
                {
                    write_log("IP's deallocated successfully");
                }
            }
        }
        system("umount /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
        system("rm -rf /mnt/$cust_id-$server_id >/dev/null 2>/dev/null");
        system(
"cp /etc/libvirt/qemu/$cust_id-$server_id.xml /home/xmlbackups/$cust_id-$server_id.xml-bak >/dev/null 2>/dev/null"
        );
        for ( $i = 0 ; $i < $ipsremno ; $i++ ) {
            system(
"cat /etc/libvirt/qemu/$cust_id-$server_id.xml | grep -v $ipsrem[$i] > /etc/libvirt/qemu/$cust_id-$server_id.xml-new"
            );
            system(
"mv /etc/libvirt/qemu/$cust_id-$server_id.xml-new /etc/libvirt/qemu/$cust_id-$server_id.xml"
            );
        }
        system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml-new");
        system("virsh undefine $cust_id-$server_id >/dev/null 2>/dev/null");
        system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml-new /etc/libvirt/qemu/$cust_id-$server_id.xml >/dev/null 2>/dev/null");
        system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml >/dev/null 2>/dev/null");
        system("virsh start $cust_id-$server_id >/dev/null 2>/dev/null");
        return success;
    }
    else {
        write_log("Windows ip  removal script called");
        system("echo > /iso/addipwindows.bat > /dev/null");
        for ( $i = 0 ; $i < $ipsremno ; $i++ ) {
            qx{echo "\n" >> /iso/addipwindows.bat > /dev/null};
            write_log("next line");
            system(
          `echo 'netsh interface ipv4 delete address "Local Area Connection" $ipsrem[$i] 255.255.255.0\n' >> /iso/addipwindows.bat`
            );
            qx{echo "\n" >> /iso/addipwindows.bat > /dev/null};
        }
        qx{echo 'DEL "%~f0"' >> /iso/addipwindows.bat};
        system("cp -p /iso/addipwindows.bat /iso/addipwindows.bat1 > /dev/null");
        system("cp /iso/addipwindows.bat /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat > /dev/null");
        system("umount /mnt/$cust_id-$server_id > /dev/null");
        system("rm -rf /mnt/$cust_id-$server_id > /dev/null");
        system("virsh start $cust_id-$server_id > /dev/null");
        system("sleep 15");
        return success;
    }
}

#########################################################################################
## Restore with Standard Image
#############################################################################
sub restoreSTIMAGE {

    my $cust_id          = shift;
    my $server_id        = shift;
    my $std_img_location = shift;
    my $os_type          = shift;
    my $os_name          = shift;
    my $os_version       = shift;
    my $os_arch          = shift;
    my $wan_primary_ip   = shift;
    my $wan_sec_ip_list  = shift;
    my $date             = `date +%Y%m%d`;
    chomp($date);

    if ( -e "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
        system(
"virsh list --all | grep -i $cust_id-$server_id | grep running > /dev/null"
        );
        if ( $? == 0 ) {
            system("virsh shutdown $cust_id-$server_id > /dev/null");
        }

        ## CHeck for Custome Image File Exists or Not
        if ( -e "/mnt/$std_img_location/$os_name-$os_version-$os_arch.qcow2" ) {
            write_log(" STD IMG FIle Exists. Restoring it");
            system("rm -rf /var/lib/libvirt/images/$cust_id-$server_id.qcow2");
            system("cp -rp cp /mnt/$stf_img_location/$os_name-$os_version-$os_arch.qcow2 /var/lib/libvirt/images/$cust_id-$server_id.qcow2");
            write_log(" Image Restored. Moving Ahead to Restore State of VM");
            system("cp -rp /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml.bak");
            system("virsh undefine $cust_id-$server_id");
            system("cp -rp /etc/libvirt/qemu/$cust_id-$server_id.xml.bak /etc/libvirt/qemu/$cust_id-$server_id.xml");
            system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml");
            write_log("VM State Restored");
            #### Assigning the current State of IP's #######################
            my @array1 = split( /\./, $wan_primary_ip );   # Perl Code to split strings of an ip address by delimiter "."
            splice @array1, 3, 4; # perl Code to get the first three strings out of the splitted array
            my $wan_ip_gateway = join( ".", @array1 );    # Perl Code to join the first three spliced strings of array
            system("mkdir -p /mnt/$cust_id-$server_id > /dev/null");
            system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id > /dev/null");
            ##############################################################################################
            ######################## IP Assignment ###########################################################
            if ( $os_type eq "linux" ) {
                if ( ( $os_name eq "centos" ) || ( $os_name eq "redhat" ) ) {
                    my $file = "/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0";
                    system(">/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0");
                    $line1 = "DEVICE=eth0";
                    $line2 = "ONBOOT=yes";
                    $line3 = "HOTPLUG=no";
                    $line4 = "IPADDR=$wan_primary_ip";
                    $line5 = "NETMASK=255.255.255.0";
                    $line6 = "GATEWAY=$wan_ip_gateway.1";
                    write_log("Adding IP $wan_primary_ip to file");
                    if ( $response =
                           Append( $file, $line1 )
                        && Append( $file, $line2 )
                        && Append( $file, $line3 )
                        && Append( $file, $line4 )
                        && Append( $file, $line5 )
                        && Append( $file, $line6 ) )
                    {
                        write_log(" IP Assignment $wan_primary_ip Successful ");
                        my @ips = split( ',', $wan_sec_ip_list );
                        my $ipsno = scalar(@ips);
                        if ( $ipsno != 0 ) {
                            for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                                open( OUT,"/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i");
                                my $filei ="/mnt/$cust_id-$server_id/etc/sysconfig/network-scripts/ifcfg-eth0:$i";
                                $line7  = "DEVICE=eth0:$i";
                                $line8  = "ONBOOT=yes";
                                $line9  = "IPADDR=$ips[$i]";
                                $line10 = "NETMASK=255.255.255.0";
                                if ( $response =
                                       Append( $filei, $line7 )
                                    && Append( $filei, $line8 )
                                    && Append( $filei, $line9 )
                                    && Append( $filei, $line10 ) )
                                {
                                    write_log("Additional IP- $ips[$i] assigned successfully");
                                }
                            }
                        }
                    }
                    else {
                        write_log("Something Went Wrong. Additional IP's assigmnet failed");
                    }
                    write_log(" Unmounting Disk");
                }
                elsif ( ( $os_name eq "debian" ) || ( $os_name eq "ubuntu" ) ) {
                    my $file = "/mnt/$cust_id-$server_id/etc/network/interfaces";
                    system(">/mnt/$cust_id-$server_id/etc/network/interfaces");
                    $line6 = "auto eth0";
                    $line1 = "iface eth0 inet static";
                    $line2 = "address $wan_primary_ip";
                    $line3 = "gateway $wan_ip_gateway.1";
                    $line4 = "netmask 255.255.255.0";
                    $line5 = "dns-nameservers 4.2.2.2";
                    if ( $response =
                           Append( $file, $line6 )
                        && Append( $file, $line1 )
                        && Append( $file, $line2 )
                        && Append( $file, $line3 )
                        && Append( $file, $line4 )
                        && Append( $file, $line5 ) )
                    {
                        write_log(" IP Assignment $wan_primary_ip Successful ");
                        ################# Adding Additional IP's##############################################################################
                        my @ips = split( ',', $wan_sec_ip_list );
                        my $ipsno = scalar(@ips);
                        if ( $ipsno != 0 ) {
                            for ( $i = 0 ; $i < $ipsno ; $i++ ) {
                                $line7  = "auto eth0:$i";
                                $line8  = "iface eth0:$i inet static";
                                $line9  = "address $ips[$i]";
                                $line10 = "netmask 255.255.255.0";
                                if ( $response =
                                       Append( $file, $line7 )
                                    && Append( $file, $line8 )
                                    && Append( $file, $line9 )
                                    && Append( $file, $line10 ) )
                                {
                                    write_log("Additional IP- $ips[$i] assigned successfully");
                                }
                            }
                        }
                    }
                    else {
                        write_log("Something Went Wrong. Additional IP's assigmnet failed");
                    }
                }
            }
            write_log("Image Restored Sucessfully");
            system("virsh start $cust_id-$server_id >/dev/null");
            system("umount /mnt/$cust_id-$server_id >/dev/null");
            system("rm -rf /mnt/$cust_id-$server_id >/dev/null");
            return success;
        }
    }
    else {
        write_log("Image or VM doesn't exists");
        return fail;
    }
}
################################################ WINDOWS  SECONDARY IP PARAMETER #############################################################
    sub assignPIPwin {
        my $cust_id         = shift;
        my $server_id       = shift;
        my $cust_name       = shift;
        my $os_type         = shift;
        my $os_name         = shift;
        my $wan_primary_ip  = shift;
        my $wan_sec_ip_list = shift;
        my $noaddip         = shift;
        my $string2008 = 'netsh interface ipv4 add address \"Local Area Connection\"';
######################################################################################################
        # Check for Machine's Existance
        write_log("WAN Primary ip : $wan_primary_ip and WAN Secondry ip list :$wan_sec_ip_list and noaddip :$noaddip \n");
        my @ips = split( ',', $wan_sec_ip_list );
	print $ips;
        my $ipsno = scalar(@ips);
        if ( !-f "/etc/libvirt/qemu/$cust_id-$server_id.xml" ) {
            write_log("Machine $cust_id-$server_id doesn't exists");
            return fail;
        }
        else {
            write_log("Machine name $cust_id-$server_id  exist ");
            system("virsh list | grep -i $cust_id-$server_id >/dev/null");
              ###### Check for guest machine state
            if ( $? == 0 ) {
                write_log(" Machine is Running.Powering it off ");
                system("virsh shutdown $cust_id-$server_id >/dev/null");
                while($? == 0) {
                    write_log(" Machine still shutting down.");
                    system("virsh list|grep -i $cust_id-$server_id >/dev/null");
                    sleep(5);
                }

#		print "Machine Powered Off";
		my $flag=0;
		do
		{	
		   system("sleep 1");
		   system("virsh list | grep -i $cust_id-$server_id >/dev/null");
		   write_log("virsh list | grep -i $cust_id-$server_id\n");
		   if ( $? == 0 )
		   {
			$flag = 0;
		    }
		    else
		    {
			$flag = 1;
		     }
		} while($flag!=1);

		#system("sleep 20");
                if ( -d "/mnt/$cust_id-$server_id" ) {
                    write_log("Machine is already Mounted. Assigning IP's to it");
		     return fail;
                }
                else {
                    write_log("Mounting Disk");
                    system("mkdir -p /mnt/$cust_id-$server_id");
                    system("guestmount -a /var/lib/libvirt/images/$cust_id-$server_id.qcow2 -i --rw /mnt/$cust_id-$server_id");
		    write_log("Machine Mounted\n");
                }
            }
		}
#		print "Going to Sleep Now";
		system("sleep 5");
            if ( $os_type eq "windows" ) {
                my $nooldip = $ipsno + $noaddip;
                write_log("Windows additional ip script called $os_name");
                system("echo > /iso/addipwindows$cust_id$server_id.bat > /dev/null");
#		print "Helo3\n";
                for ( $i = 0 ; $i < $ipsno ; $i++ ) {
            #        system("echo \n >> /iso/addipwindows$cust_id$server_id.bat > /dev/null");
                   # qx{echo "\n" >> /iso/addipwindows$cust_id$server_id.bat > /dev/null};
                    write_log("next line $ips[$i]");
                    system("echo -n $string2008 $ips[$i] 255.255.255.0 '||' >> /iso/addipwindows$cust_id$server_id.bat");
                    system("echo netsh interface ipv4 add address Ethernet $ips[$i] 255.255.255.0 >> /iso/addipwindows$cust_id$server_id.bat");
                   # qx{echo "\n" >> /iso/addipwindows$cust_id$server_id.bat > /dev/null};
	#	    system("echo '\n' >> /iso/addipwindows$cust_id$server_id.bat > /dev/null");
		qx{perl -i.bak -pe "s#(\s*)(?=<parameter name='IP' value='$wan_primary_ip'/>)#\$1<parameter name='IP' value='$ips[$i]'/>\n#\n" /etc/libvirt/qemu/$cust_id-$server_id.xml};
                }
#		print "Hello2\n";
###########################################################################
                system("cp -p /iso/addipwindows$cust_id$server_id.bat /iso/addipwindows$cust_id$server_id.bat1 > /dev/null");
#		print "Hello1 \n";
                system("touch /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat > /dev/null");
                system("cp -rp /iso/addipwindows$cust_id$server_id.bat /mnt/$cust_id-$server_id/Windows/System32/GroupPolicy/Machine/Scripts/Startup/set-config.bat > /dev/null");
                system("umount /mnt/$cust_id-$server_id > /dev/null");
                system("rm -rf /mnt/$cust_id-$server_id > /dev/null");
		system("cp /etc/libvirt/qemu/$cust_id-$server_id.xml /etc/libvirt/qemu/$cust_id-$server_id.xml-bak");
                system("virsh undefine $cust_id-$server_id >/dev/null");
                system("mv /etc/libvirt/qemu/$cust_id-$server_id.xml-bak /etc/libvirt/qemu/$cust_id-$server_id.xml");
                system("virsh define /etc/libvirt/qemu/$cust_id-$server_id.xml  >/dev/null");
                system("virsh start $cust_id-$server_id > /dev/null 2>/dev/null");
#		print "Hello \n";
                return success;
   }
            else {
                    write_log("Something Went Wrong. Additional IP's assigmnet failed");
                    return fail;
                 }
#		print "Hello\n";
    }
#############################################################################################
1;
