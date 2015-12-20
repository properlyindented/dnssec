#!/usr/bin/perl -w

use strict;
use warnings;
use IO::File;

# First argument must be a zone name we want to copy to
my $to = shift;
die if not defined $to;

# Copy all key files matching the pattern
foreach my $filename ( <Ktemplatezone.+*> )
{
	# Adjust the name of the new file
	my $toname = $filename;
	$toname =~ s/templatezone/$to/;
	# make sure we don't have same in and out file name
	next if $filename eq $toname;
	#
	print "$filename -> $toname\n";
	# Open origin
	my $in  = IO::File->new( $filename )
		or die "$filename: $!";
	# Open destination
	my $out = IO::File->new( $toname, O_WRONLY|O_CREAT|O_TRUNC )
		or die "$toname: $!";
	# Copy line by line, but substitube "templatezone" with the new zone name
	while (local $_ = $in->getline)
	{
		s/templatezone/$to/g;
		$out->print( $_ );
	}
	$in->close;
	$out->close;
	# Copy file permissions from the origin file to the destination file.
	my $mode = (stat($filename))[2] & 07777;
	chmod $mode, $toname;
}
