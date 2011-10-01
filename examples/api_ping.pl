#!/usr/bin/perl

# Copyright (c) 2008, Thomas Jager <mail@jager.no>

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

# This script sends time objects to a destination and waits for a reply and then calculates the transmission delay. It also prints out the signal level of the last rescvied packet.

use strict;
use warnings;
use Xbee::AT;
use Time::HiRes qw/tv_interval gettimeofday/;
use Storable qw/freeze thaw/;
use POSIX qw(strftime);
$| = 1;

use Time::HiRes;
use Xbee::API;
use Data::Dumper;

my $xbee =
  Xbee::API->new( { port => '/dev/ttyUSB0', debug => 0, speed => 115200 } );
while (1) {
	my $timestamp = [gettimeofday];
    my $data = freeze $timestamp;
    my $now = strftime "%Y-%m-%dT%H:%M:%S", localtime($timestamp->[0]);
#$xbee->create_source_route(pack( "H*", "0000000000000000" ),
 #       pack( "H*", "FFFE" ), 1, [pack("H*", "B7B1")]);
    $xbee->transmit_request( pack( "H*", "0000000000000000" ),
        pack( "H*", "FFFE" ), $data );
    my $tlast = [gettimeofday];
    while (1) {
        my $t0 = undef;
        if ( my $hash = $xbee->read_api ) {
            if ( $hash->{type} == 0x90 ) {
                eval { $t0 = thaw $hash->{data}; };
		my $interval = "$now ". tv_interval( $t0, [gettimeofday] ). " ";
                my $id = $xbee->at_command("DB");
                if ( my $hash = $xbee->read_api ) {
                    if ( defined $hash->{at_data} ) {
                        print $interval;
                        print "-".unpack( "c", $hash->{at_data} ), "\n";
                    }
                }
                last;
            }
	    if ($hash->{type} == 0xA1) {
#			print $hash->{nr_addresses}. join(",", @{$hash->{addresses}}). "\n";
		}
            else {
#		print $hash->{type}, "\n";
                if ( tv_interval( $tlast, [gettimeofday] ) > 3 ) {
                    print "Timeout\n";
                    last;
                }
            }
        }
    }

}
