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
my $xbee =
  Xbee::AT->new( { port => '/dev/ttyUSB0', debug => 0, speed => 115200 } );

while ( sleep 1 ) {
    my $data = freeze [gettimeofday];
    $xbee->write($data);
    my $buf = "";
    $buf = $xbee->read( length $data );
    my $now = strftime "%Y-%m-%dT%H:%M:%S", localtime;
    my $t0;
    eval { $t0 = thaw $buf; };
    if ( defined $t0 ) {
        print "$now ", tv_interval( $t0, [gettimeofday] ), " ";
        sleep 2;
        print $xbee->rssi, "\n";
        $xbee->stop_at;
    }
    else {
        $buf = $xbee->read( length $data );
    }
}
