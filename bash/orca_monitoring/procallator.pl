#!/usr/bin/perl

# 
# Retrieved from the following site by Brandon Gant on 2014-03-25:
# https://github.com/blair/orca/blob/master/data_gatherers/procallator/procallator.pl.in
#
# Needed new version that can handle version 3.2 and higher kernels (Ubuntu 12.04)
# 
# In addition to this header, I made the following changes:
#   #!/usr/bin/perl statement at top
#   my $PROC     = "/proc";
#   my $COMPRESS = "/bin/bzip2";
#   my $DEST_DIR = "/usr/local/procallator";
#   my $DEBUG   = 1;  <--- To test script from the command-line


# Performance statistics collector for /proc statistics for use with
# Linux 2.2, 2.4 & 2.6 kernels.
#
# Copyright (C) 2001 Guilherme Carvalho Chehab.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.

use strict;

use Sys::Hostname;

# Config variables.

my $PROC     = "/proc";    # Proc directory, usually /proc
my $INTERVAL = 300;             # Interval between each measure, in seconds

my $COMPRESS = "/bin/bzip2";  # Compressor...
#$COMPRESS = "@GZIP@" unless length $COMPRESS;    # Get a default

my $HOSTNAME = hostname;
my $DEST_DIR
    = "/usr/local/procallator";    # Destination dir for output files

# Output Options
# Include per NFS per protocol versions stats on output
my $NFS_PROTO_DETAILS = 0;

# Initializations
my $DEBUG   = 0;
my $r       = 0;    # Rotating index for measuring counter differences
my $rate_ok = 0;    # Check if is ok to calculate rates
my $num     = 0;    # Serial number of output file
my @n_cols;

#
# Initializations.
#

# This section only contains scalars. Also all scalars are undefined.
my ($i,      $j);
my ($os,     $line, $version, $isdst, $dumb);
my ($n_nets, $n_dsk, $line2, $cat, $net_parms, $n_fs, $cpu);

# This section contains time based scalars.
my ($sec, $min, $hour, $mday, $mon, $year, $yday);
my ($locltime, $uptime);

# This section deals with runq/proc.
my ($runq_1, $runq_5, $runq_15, $proc_run);
my ($n_cpus, $last_pid, $proc_block);

# This section deals with memory.
my ($mem_total, $mem_used, $mem_free, $mem_shrd, $mem_buff);
my ($mem_cchd, $swp_total, $swp_used, $swp_free);

# This section contains arrays.
my (@df,        @fs,   @out_filename, @out);
my (@timestamp, @yday, @procs,        @cpu, @usr, @nice, @sys);
my (@idle,      @wait, @hi,           @si, @total, @dumb, @dumb2);
my (@name, @rdops, @rdops_seq, @rdsct, @rdtm, @wrops);
my (@wrops_seq, @wrsct, @wrtm, @ioqueue, @iotm);

# This section is disk related.
my (@dsk, @dsk_rio_t, @dsk_wio_t, @page_in, @page_out);
my (@dsk_stat_t, @dsk_rblk_t, @dsk_wblk_t);
my (@dsk_maj, @dsk_min, @dsk_stat, @dsk_rio, @dsk_rblk);
my (@dsk_wio, @dsk_wblk);

# This section is memory/cpu related.
my (@swap_in, @swap_out, @ctxt, @intr);
my (@usr_100, @nice_100, @sys_100, @idle_100, @wait_100);
my (@weightiotm, @ops_seq);

# This section looks to be ifconfig/nic.
my (@if_name, @if_in_b,  @if_in_p);
my (@if_in_e, @if_in_d,  @if_in_ff, @if_in_fr, @if_in_c);
my (@if_in_m, @if_out_b, @if_out_p, @if_out_e, @if_out_d);
my (@if_out_ff, @if_out_cl, @if_out_ca, @if_out_cp);
my (@net_parm, @nfs_c_rpc_calls, @nfs_c_rpc_retrs);
my (@nfs_c_rpc_auth,       @nfs_c_p2_getattr);
my (@nfs_c_p2_setattr,     @nfs_c_p2_root, @nfs_c_p2_lookup);
my (@nfs_c_p2_readlink,    @nfs_c_p2_read);
my (@nfs_c_p2_wrcache,     @nfs_c_p2_write, @nfs_c_p2_create);
my (@nfs_c_p2_remove,      @nfs_c_p2_rename, @nfs_c_p2_link);
my (@nfs_c_p2_symlink,     @nfs_c_p2_mkdir, @nfs_c_p2_rmdir);
my (@nfs_c_p2_readdir,     @nfs_c_p2_fsstat);
my (@nfs_c_p3_getattr,     @nfs_c_p3_setattr);
my (@nfs_c_p3_lookup,      @nfs_c_p3_access);
my (@nfs_c_p3_readlink,    @nfs_c_p3_read, @nfs_c_p3_write);
my (@nfs_c_p3_create,      @nfs_c_p3_mkdir, @nfs_c_p3_symlink);
my (@nfs_c_p3_mknod,       @nfs_c_p3_remove, @nfs_c_p3_rmdir);
my (@nfs_c_p3_rename,      @nfs_c_p3_link, @nfs_c_p3_readdir);
my (@nfs_c_p3_readdirplus, @nfs_c_p3_fsstat);
my (@nfs_c_p3_fsinfo,      @nfs_c_p3_pathconf);
my (@nfs_c_p3_commit,      @nfs_c_p4_getattr);
my (@nfs_c_p4_setattr,     @nfs_c_p4_lookup);
my (@nfs_c_p4_access,      @nfs_c_p4_readlink, @nfs_c_p4_read);
my (@nfs_c_p4_write,       @nfs_c_p4_create, @nfs_c_p4_mkdir);
my (@nfs_c_p4_symlink,     @nfs_c_p4_mknod, @nfs_c_p4_remove);
my (@nfs_c_p4_rmdir,       @nfs_c_p4_rename, @nfs_c_p4_link);
my (@nfs_c_p4_readdir,     @nfs_c_p4_readdirplus);
my (@nfs_c_p4_fsstat,      @nfs_c_p4_fsinfo);
my (@nfs_c_p4_pathconf,    @nfs_c_p4_commit);
my (@nfs_s_rpc_calls,      @nfs_s_rpc_badcalls);
my (@nfs_s_rpc_badauth,    @nfs_s_rpc_badclnt);
my (@nfs_s_rpc_xdrcall,    @nfs_s_p2_getattr);
my (@nfs_s_p2_setattr,     @nfs_s_p2_root, @nfs_s_p2_lookup);
my (@nfs_s_p2_readlink,    @nfs_s_p2_read);
my (@nfs_s_p2_wrcache,     @nfs_s_p2_write, @nfs_s_p2_create);
my (@nfs_s_p2_remove,      @nfs_s_p2_rename, @nfs_s_p2_link);
my (@nfs_s_p2_symlink,     @nfs_s_p2_mkdir, @nfs_s_p2_rmdir);
my (@nfs_s_p2_readdir,     @nfs_s_p2_fsstat);
my (@nfs_s_p3_getattr,     @nfs_s_p3_setattr);
my (@nfs_s_p3_lookup,      @nfs_s_p3_access);
my (@nfs_s_p3_readlink,    @nfs_s_p3_read, @nfs_s_p3_write);
my (@nfs_s_p3_create,      @nfs_s_p3_mkdir, @nfs_s_p3_symlink);
my (@nfs_s_p3_mknod,       @nfs_s_p3_remove, @nfs_s_p3_rmdir);
my (@nfs_s_p3_rename,      @nfs_s_p3_link, @nfs_s_p3_readdir);
my (@nfs_s_p3_readdirplus, @nfs_s_p3_fsstat);
my (@nfs_s_p3_fsinfo,      @nfs_s_p3_pathconf);
my (@nfs_s_p3_commit,      @nfs_s_p4_compound);

sub die_when_called
{
    die $_[0];
}

# If procallator should daemonize itself, then do so now.
if (!$DEBUG) {
    my $expr = 'use POSIX qw(setsid)';
    local $SIG{__DIE__}  = 'DEFAULT';
    local $SIG{__WARN__} = \&die_when_called;
    eval $expr;
    if ($@) {
        die "$0: cannot get POSIX::setsid since eval '$expr' failed: $@\n";
    }
    chdir('/') or die "$0: cannot chdir '/': $!\n";
    open(STDIN, '/dev/null') or die "$0: cannot open '/dev/null': $!\n";
    defined(my $pid = fork) or die "$0: cannot fork: $!\n";
    exit(0) if $pid;
    POSIX::setsid() or die "$0: cannot start a new session: $!\n";
}

# Create output dir if needed
if (!-d $DEST_DIR && !$DEBUG) {
    mkdir($DEST_DIR)
        or die "$0: cannot mkdir '$DEST_DIR': $!\n";
}

# Read kernel version
open(F_VERSION, "$PROC/version")
    or die "$0: cannot open '$PROC/version' for reading: $!\n";
($os, $line, $version) = split / +/, <F_VERSION>, 4;
close(F_VERSION);

print "$os, $line, $version \n" if ($DEBUG);
my ($major, $minor, $release) = split /[\.| |-]/, $version;

# Treat 3.x kernels like 2.6.
if ($major == 3) {
    $major = 2;
    $minor = 6;
    $version = "2.6.but.really.$version";
}

$INTERVAL = 5 if ($DEBUG);

# Main loop
do {

    # Wait for the next INTERVAL
    sleep($INTERVAL - time() % $INTERVAL) if (!$DEBUG);
    sleep($INTERVAL) if ($DEBUG && $rate_ok);

    # Loop initializations
    $n_cols[$r] = 0;

    # Get Local time
    $timestamp[$r] = time();
    ($sec, $min, $hour, $mday, $mon, $year, $yday[$r], $isdst)
        = localtime($timestamp[$r]);
    $mon  += 1;
    $year += 1900;
    $locltime = sprintf "%02d:%02d:%02d", $hour, $min, $sec;

    # Get uptime
    open(F_UPTIME, "$PROC/uptime")
        or warn "$0: cannot open '$PROC/uptime' for reading: $!\n";
    ($uptime) = split / +/, <F_UPTIME>;
    close(F_UPTIME);

    # insert in output table
    put_output("timestamp", $timestamp[$r], "locltime", $locltime, "uptime",
        $uptime);

    # Read load average
    open(F_LOADAVG, "$PROC/loadavg")
        or warn "$0: cannot open '$PROC/loadavg' for reading: $!\n";

    ($runq_1, $runq_5, $runq_15, $proc_run, $procs[$r], $last_pid)
        = split / +|\//, <F_LOADAVG>;
    chomp $last_pid;
    close(F_LOADAVG);
    put_output(
        "1runq",  $runq_1,    "5runq",       $runq_5,
        "15runq", $runq_15,   "#proc_oncpu", $proc_run,
        "#proc",  $procs[$r], "#proc/s",     rate(@procs)
    );

    # Read system stats
    open(F_STAT, "$PROC/stat")
        or warn "$0: cannot open '$PROC/stat' for reading: $!\n";
    $n_cpus = 0;
    while ($line = <F_STAT>) {
        chomp($line);
        if ($line =~ /cpu[0-9]*/) {
            (   $cpu[$r][$n_cpus], $usr[$r][$n_cpus],  $nice[$r][$n_cpus],
                $sys[$r][$n_cpus], $idle[$r][$n_cpus], $wait[$r][$n_cpus],
                $hi[$r][$n_cpus],  $si[$r][$n_cpus],   $dumb
            ) = split / +/, $line;
            ($wait[$r][$n_cpus], $hi[$r][$n_cpus], $si[$r][$n_cpus])
                = (0, 0, 0)
                if (!defined $wait[$r][$n_cpus]);
            $total[$r][$n_cpus]
                = $usr[$r][$n_cpus]
                + $nice[$r][$n_cpus]
                + $sys[$r][$n_cpus]
                + $idle[$r][$n_cpus]
                + $wait[$r][$n_cpus]
                + $hi[$r][$n_cpus]
                + $si[$r][$n_cpus];
            $sys[$r][$n_cpus] += $hi[$r][$n_cpus] + $si[$r][$n_cpus];
            $n_cpus++;
        }
        if ($line =~ /page/) {
            ($dumb, $dsk_rio_t[$r], $dsk_wio_t[$r]) = split / +/, $line
                ; # This is the real mean... Will only use on 2.2 kernels since it is calculated on 2.4 and above
            $page_in[$r] = $page_out[$r]
                = 0;    # Ops ! This metric does not appear until kernel 2.6
        }
        if ($line =~ /swap/) {
            ($dumb, $swap_in[$r], $swap_out[$r]) = split / +/, $line;
        }
        if ($line =~ /ctxt/) {
            ($dumb, $ctxt[$r]) = split / +/, $line;
        }
        if ($line =~ /procs_blocked/) {
            ($dumb, $proc_block) = split / +/, $line;
            put_output("#proc_blckd", $proc_block);
        }
        if ($line =~ /intr/) {
            @dumb = split / /, $line;
            $intr[$r] = 0;
            $i = 1;
            while ($i < @dumb) {
                $intr[$r] += $dumb[$i];
                $i++;
            }
        }

        # Linux 2.4 style I/O report
        if ($line =~ /disk_io/) {
            @dsk = 0;
            $i   = 0;
            (   $dsk_stat_t[$r], $dsk_rio_t[$r], $dsk_rblk_t[$r],
                $dsk_wio_t[$r],  $dsk_wblk_t[$r]
            ) = (0, 0, 0, 0);

            ($dumb, $line) = split /: /, $line;
            $n_dsk = @dsk = split / /, $line;

            while ($i < $n_dsk) {
                (   $dumb,             $dsk_maj[$r][$i], $dsk_min[$r][$i],
                    $dsk_stat[$r][$i], $dsk_rio[$r][$i], $dsk_rblk[$r][$i],
                    $dsk_wio[$r][$i],  $dsk_wblk[$r][$i]
                ) = split /[^0-9]+/, $dsk[$i];
                $dsk_stat_t[$r] += $dsk_stat[$r][$i];
                $dsk_rio_t[$r]  += $dsk_rio[$r][$i];
                $dsk_rblk_t[$r] += $dsk_rblk[$r][$i];
                $dsk_wio_t[$r]  += $dsk_wio[$r][$i];
                $dsk_wblk_t[$r] += $dsk_wblk[$r][$i];
                $dumb = "c$dsk_maj[$r][$i]_d$dsk_min[$r][$i]";
                put_output(
                    "disk_op_$dumb/s",
                    rate($dsk_stat[$r][$i], $dsk_stat[1 - $r][$i]),
                    "disk_rd_$dumb/s",
                    rate($dsk_rio[$r][$i], $dsk_rio[1 - $r][$i]),
                    "disk_wr_$dumb/s",
                    rate($dsk_wio[$r][$i], $dsk_wio[1 - $r][$i]),
                    "disk_rB_$dumb/s",
                    rate($dsk_rblk[$r][$i], $dsk_rblk[1 - $r][$i]),
                    "disk_wB_$dumb/s",
                    rate($dsk_wblk[$r][$i], $dsk_wblk[1 - $r][$i])
                );
                $i++;
            }
        }

     # Linux 2.2 style I/O report, they are strangely limited to first 4 disks
        if ($line =~ /disk /) {
            @dumb = split / /, $line;
            $dsk_stat_t[$r] = 0;
            $i = 1;
            while ($i < @dumb) {
                $dsk_stat_t[$r] += $dumb[$i];
                $i++;
            }
        }
        if ($line =~ /disk_rio /) {
            @dumb = split / /, $line;
            $dsk_rio_t[$r] = 0;
            $i = 1;
            while ($i < @dumb) {
                $dsk_rio_t[$r] += $dumb[$i];
                $i++;
            }
        }
        if ($line =~ /disk_wio /) {
            @dumb = split / /, $line;
            $dsk_wio_t[$r] = 0;
            $i = 1;
            while ($i < @dumb) {
                $dsk_wio_t[$r] += $dumb[$i];
                $i++;
            }
        }
        if ($line =~ /disk_rblk /) {
            @dumb = split / /, $line;
            $dsk_rblk_t[$r] = 0;
            $i = 1;
            while ($i < @dumb) {
                $dsk_rblk_t[$r] += $dumb[$i];
                $i++;
            }
        }
        if ($line =~ /disk_wblk /) {
            @dumb = split / /, $line;
            $dsk_wblk_t[$r] = 0;
            $i = 1;
            while ($i < @dumb) {
                $dsk_wblk_t[$r] += $dumb[$i];
                $i++;
            }
        }
    }

    # Operate percentuals and rates for system Stats
    for ($i = 0; $i < $n_cpus; $i++) {
        $usr_100[$i] = rate_prcnt(
            $usr[$r][$i],   $usr[1 - $r][$i],
            $total[$r][$i], $total[1 - $r][$i]
        );
        $nice_100[$i] = rate_prcnt(
            $nice[$r][$i],  $nice[1 - $r][$i],
            $total[$r][$i], $total[1 - $r][$i]
        );
        $sys_100[$i] = rate_prcnt(
            $sys[$r][$i],   $sys[1 - $r][$i],
            $total[$r][$i], $total[1 - $r][$i]
        );
        $idle_100[$i] = rate_prcnt(
            $idle[$r][$i],  $idle[1 - $r][$i],
            $total[$r][$i], $total[1 - $r][$i]
        );
        $wait_100[$i] = rate_prcnt(
            $wait[$r][$i],  $wait[1 - $r][$i],
            $total[$r][$i], $total[1 - $r][$i]
        );
        if ($i == 0) {
            put_output(
                "ncpus", $n_cpus - 1,   "usr%",  $usr_100[$i],
                "nice%", $nice_100[$i], "sys%",  $sys_100[$i],
                "wait%", $wait_100[$i], "idle%", $idle_100[$i]
            );
        }
        else {
            if ($n_cpus > 2) {
                put_output(
                    "usr_%_$i", $usr_100[$i], "nice_%_$i", $nice_100[$i],
                    "sys_%_$i", $sys_100[$i], "wait_%_$i", $idle_100[$i]
                );
            }
        }
    }

    # In kernel 2.6 paging and swapping information must be computed
    # on other file.
    if ($version =~ /^2\.6/) {
        open(F_VMSTAT, "$PROC/vmstat")
            or warn "$0: cannot open '$PROC/vmstat' for reading: $!\n";
        while ($line = <F_VMSTAT>) {

            # Not sure about the meaning of these
            #if ( $line=~/pgactivate/) {
            #    ($dumb, $page_in[$r])= split / +/,$line;
            #}
            #if ( $line=~/pgdectivate/) {
            #    ($dumb, $page_out[$r])= split / +/,$line;
            #}
            if ($line =~ /pswpin/) {
                ($dumb, $swap_in[$r]) = split / +/, $line;
            }
            if ($line =~ /pswpout/) {
                ($dumb, $swap_out[$r]) = split / +/, $line;
            }
        }
        close(F_VMSTAT);
    }

    # Now lets get 2.4 /proc/partitions and 2.5 /proc/diskstats for
    # accurate disk measurements
    if ($minor >= 4) {
        (   $dsk_stat_t[$r], $dsk_rio_t[$r], $dsk_rblk_t[$r],
            $dsk_wio_t[$r],  $dsk_wblk_t[$r]
        ) = (0, 0, 0, 0);
        my $filename = 4 == $minor ? 'partitions' : 'diskstats';
        open(F_DSKSTAT, "$PROC/$filename")
            or warn "$0: cannot open '$PROC/$filename' for reading: $!\n";

        $i = 0;
        while ($line = <F_DSKSTAT>) {
            if ($line =~ /dm-|fio|hd|sd/) {
                chomp $line;
                $line = " 0 " . $line
                    if ($minor == 6);  # make 2.6 version look alike a 2.4 one
                (   $dumb,              $dumb,
                    $dumb,              $dumb,
                    $name[$r][$i],      $rdops[$r][$i],
                    $rdops_seq[$r][$i], $rdsct[$r][$i],
                    $rdtm[$r][$i],      $wrops[$r][$i],
                    $wrops_seq[$r][$i], $wrsct[$r][$i],
                    $wrtm[$r][$i],      $ioqueue[$r][$i],
                    $iotm[$r][$i],      $weightiotm[$r][$i]
                ) = split / +/, $line;
                if ($name[$r][$i] !~ /[0-9]/) {
                    $dsk_rio_t[$r]  += $rdops[$r][$i];
                    $dsk_wio_t[$r]  += $wrops[$r][$i];
                    $dsk_rblk_t[$r] += $rdsct[$r][$i];
                    $dsk_wblk_t[$r] += $wrsct[$r][$i];
                    put_output(
                        "disk_rd_$name[$r][$i]/s",
                        rate($rdops[$r][$i], $rdops[1 - $r][$i]),
                        "disk_wr_$name[$r][$i]/s",
                        rate($wrops[$r][$i], $wrops[1 - $r][$i]),
                        "disk_rB_$name[$r][$i]/s",
                        rate($rdsct[$r][$i], $rdsct[1 - $r][$i]),
                        "disk_wB_$name[$r][$i]/s",
                        rate($wrsct[$r][$i], $wrsct[1 - $r][$i]),
                        "disk_rdseq_$name[$r][$i]/s",
                        rate($rdops_seq[$r][$i], $rdops_seq[1 - $r][$i]),
                        "disk_wrseq_$name[$r][$i]/s",
                        rate($wrops_seq[$r][$i], $ops_seq[1 - $r][$i]),
                        "disk_rtm_$name[$r][$i]/s",
                        rate($rdtm[$r][$i], $rdtm[1 - $r][$i]),
                        "disk_wtm_$name[$r][$i]/s",
                        rate($wrtm[$r][$i], $wrtm[1 - $r][$i]),
                        "disk_iotm_$name[$r][$i]/s",
                        rate($iotm[$r][$i], $iotm[1 - $r][$i]),
                        "disk_ioqueue_$name[$r][$i]/s",
                        rate($ioqueue[$r][$i], $ioqueue[1 - $r][$i]),
                        "disk_weightiotm_$name[$r][$i]/s",
                        rate($weightiotm[$r][$i], $weightiotm[1 - $r][$i]),
                    );
                }
                else {
                    put_output( # 2.6 has fewer metrics, which messes vars names
                        "part_rd_$name[$r][$i]/s",
                        rate($rdops[$r][$i], $rdops[1 - $r][$i]),
                        "part_wr_$name[$r][$i]/s",
                        rate($rdsct[$r][$i], $rdsct[1 - $r][$i]),
                        "part_rB_$name[$r][$i]/s",
                        rate($rdops_seq[$r][$i], $rdops_seq[1 - $r][$i]),
                        "part_wB_$name[$r][$i]/s",
                        rate($rdtm[$r][$i], $rdtm[1 - $r][$i])
                    ) if ($minor == 6);
                    put_output(
                        "part_rd_$name[$r][$i]/s",
                        rate($rdops[$r][$i], $rdops[1 - $r][$i]),
                        "part_wr_$name[$r][$i]/s",
                        rate($wrops[$r][$i], $wrops[1 - $r][$i]),
                        "part_rB_$name[$r][$i]/s",
                        rate($rdsct[$r][$i], $rdsct[1 - $r][$i]),
                        "part_wB_$name[$r][$i]/s",
                        rate($wrsct[$r][$i], $wrsct[1 - $r][$i]),
                        "part_rdseq_$name[$r][$i]/s",
                        rate($rdops_seq[$r][$i], $rdops_seq[1 - $r][$i]),
                        "part_wrseq_$name[$r][$i]/s",
                        rate($wrops_seq[$r][$i], $ops_seq[1 - $r][$i]),
                        "part_rtm_$name[$r][$i]/s",
                        rate($rdtm[$r][$i], $rdtm[1 - $r][$i]),
                        "part_wtm_$name[$r][$i]/s",
                        rate($wrtm[$r][$i], $wrtm[1 - $r][$i]),
                        "disk_iotm_$name[$r][$i]/s",
                        rate($iotm[$r][$i], $iotm[1 - $r][$i]),
                        "part_ioqueue_$name[$r][$i]/s",
                        rate($ioqueue[$r][$i], $ioqueue[1 - $r][$i]),
                        "part_weightiotm_$name[$r][$i]/s",
                        rate($weightiotm[$r][$i], $weightiotm[1 - $r][$i]),
                    ) if ($minor == 4);
                }
                $i++;
            }
        }

        #$n_parts=$i;
        $dsk_stat_t[$r] = $dsk_rio_t[$r] + $dsk_wio_t[$r];
        close(F_DSKSTAT);
    }

    put_output(
        "mempages_in", rate(@page_in), "mempages_out", rate(@page_out),
        "swap_in",     rate(@swap_in), "swap_out",     rate(@swap_out),
        "ctxt/s",      rate(@ctxt),    "intr/s",       rate(@intr)
    );

    put_output(
        "disk_op/s", rate(@dsk_stat_t), "disk_rd/s", rate(@dsk_rio_t),
        "disk_wr/s", rate(@dsk_wio_t),  "disk_rB/s", rate(@dsk_rblk_t),
        "disk_wB/s", rate(@dsk_wblk_t)
    );

    close(F_STAT);

    # Get memory occupation
    open(F_MEMINFO, "$PROC/meminfo")
        or warn "$0: cannot open '$PROC/meminfo' for reading: $!\n";
    if ($version !~ /^2\.6/) {
        <F_MEMINFO>;
        (   $dumb,     $mem_total, $mem_used, $mem_free,
            $mem_shrd, $mem_buff,  $mem_cchd
        ) = split /[^0-9]+/, <F_MEMINFO>;
        ($dumb, $swp_total, $swp_used, $swp_free) = split /[^0-9]+/,
            <F_MEMINFO>;
    }
    else {
        while ($line = <F_MEMINFO>) {
            my $value;
            ($dumb, $value) = split / +/, $line;
            if ($dumb eq 'MemTotal:') {
                $mem_total = $value;
            }
            elsif ($dumb eq 'MemFree:') {
                $mem_free = $value;
            }
            elsif ($dumb eq 'Buffers:') {
                $mem_buff = $value;
            }
            elsif ($dumb eq 'Cached:') {
                $mem_cchd = $value;
            }
            elsif ($dumb eq 'Shared:') {

                # It does not exist anymore -- maybe get will have to
                # get from /proc/sysvipc/shm?
                $mem_shrd = $value;
            }
            elsif ($dumb eq 'SwapTotal:') {
                $swp_total = $value;
            }
            elsif ($dumb eq 'SwapFree:') {
                $swp_free = $value;
            }

            # elsif ( $dump eq 'SwapCached:' ) {
            #     $mem_swpcchd = $value;
            # }
        }
        $mem_used = $mem_total - $mem_free;
        $swp_used = $swp_total - $swp_free;
    }

    close(F_MEMINFO);

    put_output(
        "mem_used%", prcnt($mem_used, $mem_total),
        "mem_free%", prcnt($mem_free, $mem_total),
        "mem_shrd%", prcnt($mem_shrd, $mem_total),
        "mem_buff%", prcnt($mem_buff, $mem_total),
        "mem_cchd%", prcnt($mem_cchd, $mem_total),
        "swp_free%", prcnt($swp_free, $swp_total),
        "swp_used%", prcnt($swp_used, $swp_total)
    );

    # Get network interface statistics
    open(F_NET_DEV, "$PROC/net/dev")
        or warn "$0: cannot open '$PROC/net/dev' for reading: $!\n";
    $i = 0;
    while ($line = <F_NET_DEV>) {
        if ($line =~ /:/) {
            ($if_name[$i][$r], $line) = split /: */, $line;
            ($dumb, $if_name[$i][$r]) = split /^ +/, $if_name[$i][$r]
                if ($if_name[$i][$r] =~ / /);

            (   $if_in_b[$i][$r],   $if_in_p[$i][$r],   $if_in_e[$i][$r],
                $if_in_d[$i][$r],   $if_in_ff[$i][$r],  $if_in_fr[$i][$r],
                $if_in_c[$i][$r],   $if_in_m[$i][$r],   $if_out_b[$i][$r],
                $if_out_p[$i][$r],  $if_out_e[$i][$r],  $if_out_d[$i][$r],
                $if_out_ff[$i][$r], $if_out_cl[$i][$r], $if_out_ca[$i][$r],
                $if_out_cp[$i][$r]
            ) = split / +/, $line;
            put_output(
                "if_in_b_$if_name[$i][$r]",
                rate($if_in_b[$i][$r], $if_in_b[$i][1 - $r]),
                "if_in_p_$if_name[$i][$r]",
                rate($if_in_p[$i][$r], $if_in_p[$i][1 - $r]),
                "if_in_e_$if_name[$i][$r]",
                rate($if_in_e[$i][$r], $if_in_e[$i][1 - $r]),
                "if_in_d_$if_name[$i][$r]",
                rate($if_in_d[$i][$r], $if_in_d[$i][1 - $r]),
                "if_in_ff_$if_name[$i][$r]",
                rate($if_in_ff[$i][$r], $if_in_ff[$i][1 - $r]),
                "if_in_fr_$if_name[$i][$r]",
                rate($if_in_fr[$i][$r], $if_in_fr[$i][1 - $r]),
                "if_in_c_$if_name[$i][$r]",
                rate($if_in_c[$i][$r], $if_in_c[$i][1 - $r]),
                "if_in_m_$if_name[$i][$r]",
                rate($if_in_m[$i][$r], $if_in_m[$i][1 - $r]),
                "if_out_b_$if_name[$i][$r]",
                rate($if_out_b[$i][$r], $if_out_b[$i][1 - $r]),
                "if_out_p_$if_name[$i][$r]",
                rate($if_out_p[$i][$r], $if_out_p[$i][1 - $r]),
                "if_out_e_$if_name[$i][$r]",
                rate($if_out_e[$i][$r], $if_out_e[$i][1 - $r]),
                "if_out_d_$if_name[$i][$r]",
                rate($if_out_d[$i][$r], $if_out_d[$i][1 - $r]),
                "if_out_ff_$if_name[$i][$r]",
                rate($if_out_ff[$i][$r], $if_out_ff[$i][1 - $r]),
                "if_out_cl_$if_name[$i][$r]",
                rate($if_out_cl[$i][$r], $if_out_cl[$i][1 - $r]),
                "if_out_ca_$if_name[$i][$r]",
                rate($if_out_ca[$i][$r], $if_out_ca[$i][1 - $r]),
                "if_out_cp_$if_name[$i][$r]",
                rate($if_out_cp[$i][$r], $if_out_cp[$i][1 - $r])
            );

            $i++;
        }
    }
    $n_nets = $i;
    close(F_NET_DEV);

    # Get TCP/IP statistics
    #
    for (my $k = 0; $k < 2; $k++) {

        if ($k == 1) {
            if ($minor >= 4) {
                open(F_SNMP, "$PROC/net/netstat")
                    or warn "$0: cannot open '$PROC/net/netstat' for ",
                    "reading: $!\n";
            }
            else {
                next;
            }

        }
        else {
            open(F_SNMP, "$PROC/net/snmp")
                or warn "$0: cannot open '$PROC/net/snmp' for reading: $!\n";
        }

        $j = 0;
        while ($line = <F_SNMP>) {
            $line2 = <F_SNMP>;
            chomp $line;
            chomp $line2;
            ($cat,  $line)  = split /: +/, $line;
            ($dumb, $line2) = split /: +/, $line2;
            (@dumb)  = split / +/, $line;
            (@dumb2) = split / +/, $line2;
            for ($i = 0; $dumb[$i]; $i++, $j++) {
                $net_parm[0][$j] = sprintf "%s_%s", $cat, $dumb[$i];
                $net_parm[2 + $r][$j] = $dumb2[$i];

           #  Will save as counter and not as gauge
           # $net_parm[1][$j]= rate ($net_parm[2+$r][$j],$net_parm[3-$r][$j]);
            SWITCH: {
                    if ($cat =~ /Ip/) {
                        if ($net_parm[0][$j] =~ /In|Out|Forw|Reasm|Frag/) {
                            put_output("$net_parm[0][$j]",
                                $net_parm[2 + $r][$j]);
                        }
                        last SWITCH;
                    }
                    if ($cat =~ /Icmp/) {
                        put_output("$net_parm[0][$j]", $net_parm[2 + $r][$j]);
                        last SWITCH;
                    }
                    if ($cat =~ /Udp/) {
                        put_output("$net_parm[0][$j]", $net_parm[2 + $r][$j]);
                        last SWITCH;
                    }
                    if ($cat =~ /Tcp/) {
                        if ($net_parm[0][$j] =~ /Rto|Max/) { last SWITCH; }

                      #if ($net_parm[0][$j]=~/CurrEstab/) {
                      #    put_output("$net_parm[0][$j]",$net_parm[2+$r][$j]);
                      #	   last SWITCH;
                      #}
                        put_output("$net_parm[0][$j]", $net_parm[2 + $r][$j]);
                        last SWITCH;
                    }
                }
            }
        }
        close(F_SNMP);
        $net_parms = $j;
    }

    # Get NFS Client statistics
    if (-f "$PROC/net/rpc/nfs") {
        open(F_NFS, "$PROC/net/rpc/nfs")
            or warn "$0: cannot open '$PROC/net/rpc/nfs' for reading: $!\n";
        while ($line = <F_NFS>) {

            if ($line =~ /rpc/) {
                (   $dumb, $nfs_c_rpc_calls[$r], $nfs_c_rpc_retrs[$r],
                    $nfs_c_rpc_auth[$r]
                ) = split / +/, $line;
                put_output(
                    "nfs_c_rpc_calls", rate(@nfs_c_rpc_calls),
                    "nfs_c_rpc_retrs", rate(@nfs_c_rpc_retrs),
                    "nfs_c_rpc_auth",  rate(@nfs_c_rpc_auth)
                );
            }

            if ($line =~ /proc2/) {
                (   $dumb,                 $dumb,
                    $dumb,                 $nfs_c_p2_getattr[$r],
                    $nfs_c_p2_setattr[$r], $nfs_c_p2_root[$r],
                    $nfs_c_p2_lookup[$r],  $nfs_c_p2_readlink[$r],
                    $nfs_c_p2_read[$r],    $nfs_c_p2_wrcache[$r],
                    $nfs_c_p2_write[$r],   $nfs_c_p2_create[$r],
                    $nfs_c_p2_remove[$r],  $nfs_c_p2_rename[$r],
                    $nfs_c_p2_link[$r],    $nfs_c_p2_symlink[$r],
                    $nfs_c_p2_mkdir[$r],   $nfs_c_p2_rmdir[$r],
                    $nfs_c_p2_readdir[$r], $nfs_c_p2_fsstat[$r]
                ) = split / +/, $line;

                put_output(
                    "nfs_c_p2_getattr",  rate(@nfs_c_p2_getattr),
                    "nfs_c_p2_setattr",  rate(@nfs_c_p2_setattr),
                    "nfs_c_p2_root",     rate(@nfs_c_p2_root),
                    "nfs_c_p2_lookup",   rate(@nfs_c_p2_lookup),
                    "nfs_c_p2_readlink", rate(@nfs_c_p2_readlink),
                    "nfs_c_p2_read",     rate(@nfs_c_p2_read),
                    "nfs_c_p2_wrcache",  rate(@nfs_c_p2_wrcache),
                    "nfs_c_p2_write",    rate(@nfs_c_p2_write),
                    "nfs_c_p2_create",   rate(@nfs_c_p2_create),
                    "nfs_c_p2_remove",   rate(@nfs_c_p2_remove),
                    "nfs_c_p2_rename",   rate(@nfs_c_p2_rename),
                    "nfs_c_p2_link",     rate(@nfs_c_p2_link),
                    "nfs_c_p2_symlink",  rate(@nfs_c_p2_symlink),
                    "nfs_c_p2_mkdir",    rate(@nfs_c_p2_mkdir),
                    "nfs_c_p2_rmdir",    rate(@nfs_c_p2_rmdir),
                    "nfs_c_p2_readdir",  rate(@nfs_c_p2_readdir),
                    "nfs_c_p2_fsstat",   rate(@nfs_c_p2_fsstat)
                ) if ($NFS_PROTO_DETAILS);
            }
            if ($line =~ /proc3/) {
                (   $dumb,                  $dumb,
                    $dumb,                  $nfs_c_p3_getattr[$r],
                    $nfs_c_p3_setattr[$r],  $nfs_c_p3_lookup[$r],
                    $nfs_c_p3_access[$r],   $nfs_c_p3_readlink[$r],
                    $nfs_c_p3_read[$r],     $nfs_c_p3_write[$r],
                    $nfs_c_p3_create[$r],   $nfs_c_p3_mkdir[$r],
                    $nfs_c_p3_symlink[$r],  $nfs_c_p3_mknod[$r],
                    $nfs_c_p3_remove[$r],   $nfs_c_p3_rmdir[$r],
                    $nfs_c_p3_rename[$r],   $nfs_c_p3_link[$r],
                    $nfs_c_p3_readdir[$r],  $nfs_c_p3_readdirplus[$r],
                    $nfs_c_p3_fsstat[$r],   $nfs_c_p3_fsinfo[$r],
                    $nfs_c_p3_pathconf[$r], $nfs_c_p3_commit[$r]
                ) = split / +/, $line;

                put_output(
                    "nfs_c_p3_getattr",     rate(@nfs_c_p3_getattr),
                    "nfs_c_p3_setattr",     rate(@nfs_c_p3_setattr),
                    "nfs_c_p3_lookup",      rate(@nfs_c_p3_lookup),
                    "nfs_c_p3_access",      rate(@nfs_c_p3_access),
                    "nfs_c_p3_readlink",    rate(@nfs_c_p3_readlink),
                    "nfs_c_p3_read",        rate(@nfs_c_p3_read),
                    "nfs_c_p3_write",       rate(@nfs_c_p3_write),
                    "nfs_c_p3_create",      rate(@nfs_c_p3_create),
                    "nfs_c_p3_mkdir",       rate(@nfs_c_p3_mkdir),
                    "nfs_c_p3_symlink",     rate(@nfs_c_p3_symlink),
                    "nfs_c_p3_mknod",       rate(@nfs_c_p3_mknod),
                    "nfs_c_p3_remove",      rate(@nfs_c_p3_remove),
                    "nfs_c_p3_rmdir",       rate(@nfs_c_p3_rmdir),
                    "nfs_c_p3_rename",      rate(@nfs_c_p3_rename),
                    "nfs_c_p3_link",        rate(@nfs_c_p3_link),
                    "nfs_c_p3_readdir",     rate(@nfs_c_p3_readdir),
                    "nfs_c_p3_readdirplus", rate(@nfs_c_p3_readdirplus),
                    "nfs_c_p3_fsstat",      rate(@nfs_c_p3_fsstat),
                    "nfs_c_p3_fsinfo",      rate(@nfs_c_p3_fsinfo),
                    "nfs_c_p3_pathconf",    rate(@nfs_c_p3_pathconf),
                    "nfs_c_p3_commit",      rate(@nfs_c_p3_commit)
                ) if ($NFS_PROTO_DETAILS);
            }
            if ($line =~ /proc4/) {
                (   $dumb,                  $dumb,
                    $dumb,                  $nfs_c_p4_getattr[$r],
                    $nfs_c_p4_setattr[$r],  $nfs_c_p4_lookup[$r],
                    $nfs_c_p4_access[$r],   $nfs_c_p4_readlink[$r],
                    $nfs_c_p4_read[$r],     $nfs_c_p4_write[$r],
                    $nfs_c_p4_create[$r],   $nfs_c_p4_mkdir[$r],
                    $nfs_c_p4_symlink[$r],  $nfs_c_p4_mknod[$r],
                    $nfs_c_p4_remove[$r],   $nfs_c_p4_rmdir[$r],
                    $nfs_c_p4_rename[$r],   $nfs_c_p4_link[$r],
                    $nfs_c_p4_readdir[$r],  $nfs_c_p4_readdirplus[$r],
                    $nfs_c_p4_fsstat[$r],   $nfs_c_p4_fsinfo[$r],
                    $nfs_c_p4_pathconf[$r], $nfs_c_p4_commit[$r]
                ) = split / +/, $line;

                put_output(
                    "nfs_c_p4_getattr",     rate(@nfs_c_p4_getattr),
                    "nfs_c_p4_setattr",     rate(@nfs_c_p4_setattr),
                    "nfs_c_p4_lookup",      rate(@nfs_c_p4_lookup),
                    "nfs_c_p4_access",      rate(@nfs_c_p4_access),
                    "nfs_c_p4_readlink",    rate(@nfs_c_p4_readlink),
                    "nfs_c_p4_read",        rate(@nfs_c_p4_read),
                    "nfs_c_p4_write",       rate(@nfs_c_p4_write),
                    "nfs_c_p4_create",      rate(@nfs_c_p4_create),
                    "nfs_c_p4_mkdir",       rate(@nfs_c_p4_mkdir),
                    "nfs_c_p4_symlink",     rate(@nfs_c_p4_symlink),
                    "nfs_c_p4_mknod",       rate(@nfs_c_p4_mknod),
                    "nfs_c_p4_remove",      rate(@nfs_c_p4_remove),
                    "nfs_c_p4_rmdir",       rate(@nfs_c_p4_rmdir),
                    "nfs_c_p4_rename",      rate(@nfs_c_p4_rename),
                    "nfs_c_p4_link",        rate(@nfs_c_p4_link),
                    "nfs_c_p4_readdir",     rate(@nfs_c_p4_readdir),
                    "nfs_c_p4_readdirplus", rate(@nfs_c_p4_readdirplus),
                    "nfs_c_p4_fsstat",      rate(@nfs_c_p4_fsstat),
                    "nfs_c_p4_fsinfo",      rate(@nfs_c_p4_fsinfo),
                    "nfs_c_p4_pathconf",    rate(@nfs_c_p4_pathconf),
                    "nfs_c_p4_commit",      rate(@nfs_c_p4_commit)
                ) if ($NFS_PROTO_DETAILS);
            }
        }
        close(F_NFS);

        put_output(
            "nfs_c_t_getattr",
            rate(@nfs_c_p2_getattr)
                + rate(@nfs_c_p3_getattr)
                + rate(@nfs_c_p4_getattr),
            "nfs_c_t_setattr",
            rate(@nfs_c_p2_setattr)
                + rate(@nfs_c_p3_setattr)
                + rate(@nfs_c_p4_setattr),
            "nfs_c_t_lookup",
            rate(@nfs_c_p2_lookup)
                + rate(@nfs_c_p3_lookup)
                + rate(@nfs_c_p4_lookup),
            "nfs_c_t_access",
            rate(@nfs_c_p3_access) + rate(@nfs_c_p4_access),
            "nfs_c_t_readlink",
            rate(@nfs_c_p2_readlink)
                + rate(@nfs_c_p3_readlink)
                + rate(@nfs_c_p4_readlink),
            "nfs_c_t_read",
            rate(@nfs_c_p2_read)
                + rate(@nfs_c_p3_read)
                + rate(@nfs_c_p4_read),
            "nfs_c_t_write",
            rate(@nfs_c_p2_write)
                + rate(@nfs_c_p3_write)
                + rate(@nfs_c_p4_write),
            "nfs_c_t_create",
            rate(@nfs_c_p2_create)
                + rate(@nfs_c_p3_create)
                + rate(@nfs_c_p4_create),
            "nfs_c_t_mkdir",
            rate(@nfs_c_p2_mkdir)
                + rate(@nfs_c_p3_mkdir)
                + rate(@nfs_c_p4_mkdir),
            "nfs_c_t_symlink",
            rate(@nfs_c_p2_symlink)
                + rate(@nfs_c_p3_symlink)
                + rate(@nfs_c_p4_symlink),
            "nfs_c_t_mknod",
            rate(@nfs_c_p3_mknod) + rate(@nfs_c_p4_mknod),
            "nfs_c_t_remove",
            rate(@nfs_c_p2_remove)
                + rate(@nfs_c_p3_remove)
                + rate(@nfs_c_p4_remove),
            "nfs_c_t_rmdir",
            rate(@nfs_c_p2_rmdir)
                + rate(@nfs_c_p3_rmdir)
                + rate(@nfs_c_p4_rmdir),
            "nfs_c_t_rename",
            rate(@nfs_c_p2_rename)
                + rate(@nfs_c_p3_rename)
                + rate(@nfs_c_p4_rename),
            "nfs_c_t_link",
            rate(@nfs_c_p2_link)
                + rate(@nfs_c_p3_link)
                + rate(@nfs_c_p4_link),
            "nfs_c_t_readdir",
            rate(@nfs_c_p2_readdir)
                + rate(@nfs_c_p3_readdir)
                + rate(@nfs_c_p4_readdir),
            "nfs_c_t_readdirplus",
            rate(@nfs_c_p3_readdirplus) + rate(@nfs_c_p4_readdirplus),
            "nfs_c_t_fsstat",
            rate(@nfs_c_p2_fsstat)
                + rate(@nfs_c_p3_fsstat)
                + rate(@nfs_c_p4_fsstat),
            "nfs_c_t_fsinfo",
            rate(@nfs_c_p3_fsinfo) + rate(@nfs_c_p4_fsinfo),
            "nfs_c_t_pathconf",
            rate(@nfs_c_p3_pathconf) + rate(@nfs_c_p4_pathconf),
            "nfs_c_t_commit",
            rate(@nfs_c_p3_commit) + rate(@nfs_c_p4_commit)
        );
    }

    # Get NFS Server statistics
    if (-f "$PROC/net/rpc/nfsd") {
        open(F_NFS, "$PROC/net/rpc/nfsd")
            or warn "$0: cannot open '$PROC/net/rpc/nfsd' for reading: $!\n";
        while ($line = <F_NFS>) {

            if ($line =~ /rpc/) {
                (   $dumb,                   $nfs_s_rpc_calls[$r],
                    $nfs_s_rpc_badcalls[$r], $nfs_s_rpc_badauth[$r],
                    $nfs_s_rpc_badclnt[$r],  $nfs_s_rpc_xdrcall[$r]
                ) = split / +/, $line;
                put_output(
                    "nfs_s_rpc_calls",    rate(@nfs_s_rpc_calls),
                    "nfs_s_rpc_badcalls", rate(@nfs_s_rpc_badcalls),
                    "nfs_s_rpc_badauth",  rate(@nfs_s_rpc_badauth),
                    "nfs_s_rpc_badclnt",  rate(@nfs_s_rpc_badclnt),
                    "nfs_s_rpc_xdrcall",  rate(@nfs_s_rpc_xdrcall)
                );
            }

            if ($line =~ /proc2/) {
                (   $dumb,                 $dumb,
                    $dumb,                 $nfs_s_p2_getattr[$r],
                    $nfs_s_p2_setattr[$r], $nfs_s_p2_root[$r],
                    $nfs_s_p2_lookup[$r],  $nfs_s_p2_readlink[$r],
                    $nfs_s_p2_read[$r],    $nfs_s_p2_wrcache[$r],
                    $nfs_s_p2_write[$r],   $nfs_s_p2_create[$r],
                    $nfs_s_p2_remove[$r],  $nfs_s_p2_rename[$r],
                    $nfs_s_p2_link[$r],    $nfs_s_p2_symlink[$r],
                    $nfs_s_p2_mkdir[$r],   $nfs_s_p2_rmdir[$r],
                    $nfs_s_p2_readdir[$r], $nfs_s_p2_fsstat[$r]
                ) = split / +/, $line;

                put_output(
                    "nfs_s_p2_getattr",  rate(@nfs_s_p2_getattr),
                    "nfs_s_p2_setattr",  rate(@nfs_s_p2_setattr),
                    "nfs_s_p2_root",     rate(@nfs_s_p2_root),
                    "nfs_s_p2_lookup",   rate(@nfs_s_p2_lookup),
                    "nfs_s_p2_readlink", rate(@nfs_s_p2_readlink),
                    "nfs_s_p2_read",     rate(@nfs_s_p2_read),
                    "nfs_s_p2_wrcache",  rate(@nfs_s_p2_wrcache),
                    "nfs_s_p2_write",    rate(@nfs_s_p2_write),
                    "nfs_s_p2_create",   rate(@nfs_s_p2_create),
                    "nfs_s_p2_remove",   rate(@nfs_s_p2_remove),
                    "nfs_s_p2_rename",   rate(@nfs_s_p2_rename),
                    "nfs_s_p2_link",     rate(@nfs_s_p2_link),
                    "nfs_s_p2_symlink",  rate(@nfs_s_p2_symlink),
                    "nfs_s_p2_mkdir",    rate(@nfs_s_p2_mkdir),
                    "nfs_s_p2_rmdir",    rate(@nfs_s_p2_rmdir),
                    "nfs_s_p2_readdir",  rate(@nfs_s_p2_readdir),
                    "nfs_s_p2_fsstat",   rate(@nfs_s_p2_fsstat)
                ) if ($NFS_PROTO_DETAILS);
            }
            if ($line =~ /proc3/) {
                (   $dumb,                  $dumb,
                    $dumb,                  $nfs_s_p3_getattr[$r],
                    $nfs_s_p3_setattr[$r],  $nfs_s_p3_lookup[$r],
                    $nfs_s_p3_access[$r],   $nfs_s_p3_readlink[$r],
                    $nfs_s_p3_read[$r],     $nfs_s_p3_write[$r],
                    $nfs_s_p3_create[$r],   $nfs_s_p3_mkdir[$r],
                    $nfs_s_p3_symlink[$r],  $nfs_s_p3_mknod[$r],
                    $nfs_s_p3_remove[$r],   $nfs_s_p3_rmdir[$r],
                    $nfs_s_p3_rename[$r],   $nfs_s_p3_link[$r],
                    $nfs_s_p3_readdir[$r],  $nfs_s_p3_readdirplus[$r],
                    $nfs_s_p3_fsstat[$r],   $nfs_s_p3_fsinfo[$r],
                    $nfs_s_p3_pathconf[$r], $nfs_s_p3_commit[$r]
                ) = split / +/, $line;

                put_output(
                    "nfs_s_p3_getattr",     rate(@nfs_s_p3_getattr),
                    "nfs_s_p3_setattr",     rate(@nfs_s_p3_setattr),
                    "nfs_s_p3_lookup",      rate(@nfs_s_p3_lookup),
                    "nfs_s_p3_access",      rate(@nfs_s_p3_access),
                    "nfs_s_p3_readlink",    rate(@nfs_s_p3_readlink),
                    "nfs_s_p3_read",        rate(@nfs_s_p3_read),
                    "nfs_s_p3_write",       rate(@nfs_s_p3_write),
                    "nfs_s_p3_create",      rate(@nfs_s_p3_create),
                    "nfs_s_p3_mkdir",       rate(@nfs_s_p3_mkdir),
                    "nfs_s_p3_symlink",     rate(@nfs_s_p3_symlink),
                    "nfs_s_p3_mknod",       rate(@nfs_s_p3_mknod),
                    "nfs_s_p3_remove",      rate(@nfs_s_p3_remove),
                    "nfs_s_p3_rmdir",       rate(@nfs_s_p3_rmdir),
                    "nfs_s_p3_rename",      rate(@nfs_s_p3_rename),
                    "nfs_s_p3_link",        rate(@nfs_s_p3_link),
                    "nfs_s_p3_readdir",     rate(@nfs_s_p3_readdir),
                    "nfs_s_p3_readdirplus", rate(@nfs_s_p3_readdirplus),
                    "nfs_s_p3_fsstat",      rate(@nfs_s_p3_fsstat),
                    "nfs_s_p3_fsinfo",      rate(@nfs_s_p3_fsinfo),
                    "nfs_s_p3_pathconf",    rate(@nfs_s_p3_pathconf),
                    "nfs_s_p3_commit",      rate(@nfs_s_p3_commit)
                ) if ($NFS_PROTO_DETAILS);
            }
            if ($line =~ /proc4/) {
                ($dumb, $dumb, $dumb, $nfs_s_p4_compound[$r]) = split / +/,
                    $line;

                put_output("nfs_s_p4_compound", rate(@nfs_s_p4_compound))
                    if ($NFS_PROTO_DETAILS);
            }
        }
        close(F_NFS);
        put_output(
            "nfs_s_t_getattr",
            rate(@nfs_s_p2_getattr) + rate(@nfs_s_p3_getattr),
            "nfs_s_t_setattr",
            rate(@nfs_s_p2_setattr) + rate(@nfs_s_p3_setattr),
            "nfs_s_t_lookup",
            rate(@nfs_s_p2_lookup) + rate(@nfs_s_p3_lookup),
            "nfs_s_t_access",
            rate(@nfs_s_p3_access),
            "nfs_s_t_readlink",
            rate(@nfs_s_p2_readlink) + rate(@nfs_s_p3_readlink),
            "nfs_s_t_read",
            rate(@nfs_s_p2_read) + rate(@nfs_s_p3_read),
            "nfs_s_t_write",
            rate(@nfs_s_p2_write) + rate(@nfs_s_p3_write),
            "nfs_s_t_create",
            rate(@nfs_s_p2_create) + rate(@nfs_s_p3_create),
            "nfs_s_t_mkdir",
            rate(@nfs_s_p2_mkdir) + rate(@nfs_s_p3_mkdir),
            "nfs_s_t_symlink",
            rate(@nfs_s_p2_symlink) + rate(@nfs_s_p3_symlink),
            "nfs_s_t_mknod",
            rate(@nfs_s_p3_mknod),
            "nfs_s_t_remove",
            rate(@nfs_s_p2_remove) + rate(@nfs_s_p3_remove),
            "nfs_s_t_rmdir",
            rate(@nfs_s_p2_rmdir) + rate(@nfs_s_p3_rmdir),
            "nfs_s_t_rename",
            rate(@nfs_s_p2_rename) + rate(@nfs_s_p3_rename),
            "nfs_s_t_link",
            rate(@nfs_s_p2_link) + rate(@nfs_s_p3_link),
            "nfs_s_t_readdir",
            rate(@nfs_s_p2_readdir) + rate(@nfs_s_p3_readdir),
            "nfs_s_t_readdirplus",
            rate(@nfs_s_p3_readdirplus),
            "nfs_s_t_fsstat",
            rate(@nfs_s_p2_fsstat) + rate(@nfs_s_p3_fsstat),
            "nfs_s_t_fsinfo",
            rate(@nfs_s_p3_fsinfo),
            "nfs_s_t_pathconf",
            rate(@nfs_s_p3_pathconf),
            "nfs_s_t_commit",
            rate(@nfs_s_p3_commit),
            "nfs_s_t_compound",
            rate(@nfs_s_p4_compound)
        );
    }

    # Get filesystem occupation
    @df = `/bin/df -klP`;
    for ($i = 1, $j = 0; $df[$i]; $i++) {
        if (!(($df[$i] =~ /cdrom/) || ($df[$i] =~ /cdrom/))) {
            chomp $df[$i];
            ($dumb, $fs[2][$j], $fs[3][$j], $dumb, $dumb, $fs[0][$j])
                = split / +/, $df[$i];
            $fs[1][$j] = prcnt($fs[3][$j], $fs[2][$j]);
            put_output("mnt_$fs[0][$j]", $fs[1][$j]);
            $j++;
        }
    }
    $n_fs = $j;

    # Check if number of columns have changed
    if ($n_cols[$r] != $n_cols[1 - $r]) {
        $num++;
    }

    # If year day has changed and is not first execution: zero output seq.
    if (($rate_ok) && ($yday[$r] != $yday[1 - $r])) {
        $num = 0;
    }

    # Evaluate filename
    $out_filename[$r] = sprintf "%s/proccol-%04d-%02d-%02d-%03d", $DEST_DIR,
        $year, $mon, $mday, $num;

    # on first execution check file existence
    if (!$rate_ok) {
        while (-f $out_filename[$r]) {
            $num++;
            $out_filename[$r] = sprintf "%s/proccol-%04d-%02d-%02d-%03d",
                $DEST_DIR, $year, $mon, $mday, $num;
        }
    }

    # flush output if not in Debug mode
    flush_output() if (!$DEBUG);

    $r       = 1 - $r;
    $rate_ok = 1;

} while (!$DEBUG || $r);    # If in debug mode does only 2 iterations

# to perl don't complain on unused vars
($os, $n_fs, $net_parms, $n_nets, $cpu, $yday, $isdst)
    = ($os, $n_fs, $net_parms, $n_nets, $cpu, $yday, $isdst);

sub rate
{
    my ($a, $b) = @_;
    my $c;
    my $d = $INTERVAL;      #1; # abs($timestamp[$r]-$timestamp[1-$r]);
    if (!defined $a || $a eq "") { $a = 0 }
    if (!defined $b || $b eq "") { $b = 0 }

    $c
        = ($rate_ok == 1)
        ? (
        ((abs($a - $b) % $d) == 0)
        ? abs($a - $b) / $d
        : sprintf("%.3f", abs($a - $b) / $d)
        )
        : 0;

    return $c;
}

sub prcnt
{
    my ($a, $b) = @_;
    if (!defined $a || $a eq "") { $a = 0 }
    if (!defined $b || $b eq "") { $b = 0 }
    return ($b == 0) ? 0 : sprintf("%.2f", 100 * $a / $b);
}

sub rate_prcnt
{
    my ($a1, $a2, $b1, $b2) = @_;
    if (!($a1 && $b1 && $a2 && $b2)) {
        return 0;
    }

    return (abs($b1 - $b2) == 0)
        ? 0
        : sprintf("%.2f", 100 * abs($a1 - $a2) / abs($b1 - $b2));
}

sub flush_output
{
    my $t;

    # check if new file is not required
    open(F_OUT, ">>$out_filename[$r]")
        or die "$0: cannot open '$out_filename[$r]' for writing: $!\n";

    if (!$rate_ok) {
        for ($t = 0; $t < $n_cols[$r]; $t++) {
            print F_OUT $out[0][$t], " ";
        }
        print F_OUT "\n";
    }
    else {
        if (   ($n_cols[$r] != $n_cols[1 - $r])
            || ($out_filename[$r] ne $out_filename[1 - $r])
            || $rate_ok == 0)
        {
            for ($t = 0; $t < $n_cols[$r]; $t++) {
                print F_OUT $out[0][$t], " ";
            }
            print F_OUT "\n";
        }
        if ($out_filename[$r] ne $out_filename[1 - $r]) {
            `$COMPRESS $out_filename[1-$r]`;
        }
    }

    for ($t = 0; $t < $n_cols[$r]; $t++) {
        print F_OUT $out[1][$t], " ";
    }
    print F_OUT "\n";
    close F_OUT;

    @out = ();
}

sub put_output
{
    my (@a) = @_;
    my $t;

    for ($t = 0; $a[$t]; $t += 2, $n_cols[$r] += 1) {
        $out[0][$n_cols[$r]] = $a[$t];
        $out[1][$n_cols[$r]] = $a[$t + 1];
        if ($DEBUG) {
            print $out[0][$n_cols[$r]], ": ", $out[1][$n_cols[$r]], "\n";
        }
    }
}
