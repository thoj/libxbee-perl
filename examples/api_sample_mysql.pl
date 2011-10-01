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

use DBI;
use Xbee::API;

use Data::Dumper;

my $record = { '0013a20040552245' => { analog => [ 0, 1 ] } };

my $xbee =
  Xbee::API->new( { port => '/dev/ttyUSB0', debug => 0, speed => 115200 } );

my $dbh = DBI->connect( "DBI:mysql:database=samples;host=localhost",
    "samples", "WMHfd6rSqDFJDZ9X", { 'RaiseError' => 1 } );
my $analog_sth =
  $dbh->prepare("INSERT INTO `analog` (time,pin,value) VALUES(NOW(),?,?);")
  or print $!;

while (1) {
    my $frame = $xbee->read_api;
    if ( defined $frame->{analog_samples} ) {
        if ( defined $record->{ $frame->{source_serial} } ) {
            print $frame->{source_serial}, ": ";
            foreach my $v ( @{ $record->{ $frame->{source_serial} }{analog} } )
            {
                $analog_sth->execute( $v, $frame->{analog_samples}[$v] );
                print $frame->{analog_samples}[$v], ", ";
            }
            print "\n";
        }
        else {
            print $frame->{source_serial}, ": Missing record key\n";
        }
    }
}

#$VAR1 = {
#          'source_serial' => '0013a20040552245',
#          'receive_options' => 1,
#          'raw_data' => '��@U"E�`�',
#          'analog_samples' => [
#                                229,
#                                0,
#                                533,
#                                537
#                              ],
#          'digital_mask' => '',
#          'checksum' => 'OK',
#          'source_address' => 'a060',
#          'samples' => 1,
#          'length' => 24,
#          'analog_mask' => '',
#          'type' => 146
#        };
