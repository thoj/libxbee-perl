#!/usr/bin/perl
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

my $xbee =
  Xbee::API->new( { port => '/dev/ttyUSB0', debug => 1, speed => 115200 } );

    $xbee->transmit_request( pack( "H*", "0000000000000000" ),
        pack( "H*", "FFFE" ), "FOOBAR" );
