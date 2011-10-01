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

# This script echos back any data packets back to the origin.

use strict;
use warnings;

use Xbee::API;
use Time::HiRes;
use Storable qw/freeze thaw/;
use POSIX qw/strftime/;

use Data::Dumper;
$| = 1;
my $xbee =
  Xbee::API->new( { port => '/dev/ttyUSB0', debug => 1, speed => 115200 } );
my $timestamp;
while (1) {
    if ( my $hash = $xbee->read_api ) {
        if ( $hash->{type} == 0x90 ) {
            $xbee->transmit_request(
                pack( "H*", $hash->{serial} ),
                pack( "H*", $hash->{address} ),
                $hash->{data}
            );
		eval {
            $timestamp = strftime "%Y-%m-%dT%H:%M:%S",
              localtime( (thaw $hash->{data})->[0] );
		};
        }
        if ( $hash->{type} == 0xA1 ) {
            print "$timestamp: " if defined $timestamp;
            if ( $hash->{addresses_nr} > 0 ) {
                print $hash->{addresses_nr} . " "
                  . join( "->", @{ $hash->{addresses} } ) . "\n";
            }
            else {
                print "0\n";
            }
        }
	elsif ($hash->{type} == 149) {
		print Dumper($hash);
	}
    }

}
