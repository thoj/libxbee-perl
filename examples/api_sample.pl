#!/usr/bin/perl

# Copyright (c) 2009, Thomas Jager <mail@jager.no>

# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.

# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# This script takes incoming sample packets from Xbee devices programmed to
# make periodic samples and puts the data into a mysql database.

use strict;
use warnings;

use Xbee::API;

use Data::Dumper;

my $xbee =
  Xbee::API->new( { port => '/dev/ttyUSB0', debug => 0, speed => 115200 } );

my $state = {};

while (1) {
    my $frame = $xbee->read_api;

        my $source = $frame->{source_serial};
	if (defined $frame->{type} and $frame->{type} == 149 and defined $state->{$source} ) {
		print "$source Joined network, resetting state\n";
		delete $state->{$source};
	}
    if ( defined $frame->{analog_samples} ) {
        print $source, ": ";
        print join( "mV, ", @{ $frame->{analog_samples} } );
        print "mV\n";
        if ( $frame->{analog_samples}[0] > 250
            and ( not defined $state->{$source} or $state->{$source} == 0 ) )
        {
            print "Fan on\n";
            $state->{$source} = 1;
            my $id = $xbee->at_command_remote(
                pack( "H*", $source ),
                pack( "H*", "FFFE" ),
                "D2", "\x05"
            );
        }
        elsif ( $frame->{analog_samples}[0] < 240
            and ( not defined $state->{$source} or $state->{$source} == 1 ) )
        {
            print "Fan off\n";
            $state->{$source} = 0;
            my $id = $xbee->at_command_remote(
                pack( "H*", $source ),
                pack( "H*", "FFFE" ),
                "D2", "\x04"
            );
        }
    }
    else {
#        print Dumper($frame);
    }
}
