#!/usr/bin/perl -w
# Robert Martin-Legene, 2014$
use strict;
use warnings;
use English;
use POSIX;
use Net::DNS;
use IO::Handle;
use IO::Socket::INET;
use IO::File;
use constant NOPRIVUSER => 'robert';

my $log_fh;


sub triggers($$)
{
    my ($fqdn, $serial, $hisip) = @_;
    # We will launch the application specified on the command line, followed
    # by the fqdn, the serial and the sender ip.
    # The script must implement it's own DoS controls.
    # E.g.:
    # dnscatch mydnssecsigner
    # if a NOTIFY is received for .py from 10.20.30.40 and a serial of 13
    # a process will be spawned like this:
    # mydnssecsigner py 13 10.20.30.40
    system( @ARGV, $fqdn, $serial, $hisip ) if @ARGV;
}

sub logit($)
{
	my ($txt) = @_;
	if ((not defined $log_fh) or (($log_fh->stat)[7] > 1024*1024))
	{
		if (defined $log_fh)
		{
			$log_fh->close;
			unlink 'logs/log.notifies.old';
			rename 'logs/log.notifies', 'logs/log.notifies.old';
		}
		mkdir 'logs', 0755;
		$log_fh = IO::File->new('logs/log.notifies', O_WRONLY|O_APPEND|O_CREAT);
	}
        my @t = gmtime();
	$t[5] += 1900;
	$t[4] ++;
	my $nowstring = sprintf "%02d%02d%02d-%02d%02d%02d ",
		(@t)[5,4,3,2,1,0];
	if (defined $log_fh)
	{
		$log_fh->print($nowstring.$txt);
		$log_fh->flush;
	}
	if (-t STDOUT)
	{
		print $nowstring.$txt;
	}
}

sub udp_packet {
	my ( $query, $hisip, $hisport ) = @_;
        return unless defined $query;
        return unless ref $query eq 'Net::DNS::Packet';
	return if $query->header->qr(); # Do not process queries.
	return if $query->header->qdcount != 1;
	my @q = $query->question;
        return if scalar(@q) != 1; # extra check
	return if $query->header->opcode ne 'NS_NOTIFY_OP'; #RFC1996 / NOTIFY
	my $fqdn = $q[0]->qname;
	my $serial;
	# next 4 lines untested
	if ($q[0]->type eq 'SOA')
	{
		$serial = $q[0]-serial;
	}
        # reply
	my $reply = Net::DNS::Packet->new();
	$reply->header->ad( $query->header->ad );
	$reply->header->cd( $query->header->cd );
	$reply->header->rd( $query->header->rd );
	$reply->header->id( $query->header->id );
	$reply->header->qr(1);
	$reply->header->ra(0);
	$reply->header->rcode( 'NOERROR' );
	$reply->header->opcode( $query->header->opcode );
	$reply->question( $q[0] );
       	return ($fqdn, $serial, $reply);
}

sub loop {
    my $sock = new IO::Socket::INET(
	    LocalPort => 53,
	    Proto     => "udp",
    );
    die $! unless defined $sock;
    my $buf = '';
    while (1) {
	my $peer = $sock->recv( $buf, &Net::DNS::PACKETSZ );
	exit if not defined $peer;
	my ( $query, $err ) = Net::DNS::Packet->new( \$buf );
        if (defined $query)
        {
	    my ($fqdn, $serial, $replypacket) =
                udp_packet($query, $sock->peerhost, $sock->peerport);
            if (defined $fqdn and defined $replypacket)
            {
       	        logit(sprintf "%s: Got NOTIFY from %s:%u for %s\n",
		        $hisip, $hisport, $fqdn);
	        $sock->send( $replypacket->data );
		trigger( $fqdn, $serial, $hisip );
            }
        }
    }
}


sub daemon_init {
	# From Zaxo @ http://www.perlmonks.org/?node_id=374409
	# First, we fork and exit the parent. That makes the launching
	# process think we're done and also makes sure we're not a
	# process group leader - a necessary condition for the next
	# step to succeed.
	my $pid = fork();
	exit 0 if $pid; # parent
	die $! if not defined $pid; # fork fail
	# Second, we call setsid() which does three things. We become
	# leader of a new session, group leader of a new process
	# group, and become detached from any terminal.
	setsid();
	# To satisfy SVR4, we do the fork dance again to shuck session
	# leadership, which guarantees we never get a controlling terminal.
	$pid = fork();
	exit 0 if $pid; # parent
	die !$ if not defined $pid; # fork fail
	# Third, we change directory to the root of all. That is a
	# courtesy to the system, which without it would be prevented
	# from unmounting the filesystem we started in.
	chdir '/' or die $!;
	# Fourth, we clear the permissions mask for file creation.
	# That frees our daemon to manage its files as it sees fit.
	umask 0;
	# End of Zaxo's magic
	#
	# And now our own woodoo
	# We don't want to have to get interrupted by children
	# finishing their task
	$SIG{CHLD} = 'IGNORE';
	# Also, make sure we are not root.
        if ($REAL_USER_ID == 0)
        {
	    my $uid = (getpwnam(NOPRIVUSER))[2];
	    POSIX::setuid($uid);
	    die "Real user id not changed, stopped" if $REAL_USER_ID != $uid;
	    die "Effective user id not changed, stopped" if $EFFECTIVE_USER_ID != $uid;
        }
}

daemon_init();
loop();
