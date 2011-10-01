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

use strict;
use warnings;

use Xbee::API;
use Data::Dumper;

my $xbee = Xbee::API->new({ port => '/dev/ttyUSB0', debug => 0, speed => 115200 });
#$xbee->at_command("DB", "\x70");
#$xbee->at_command("ND");
#$xbee->transmit_request(pack("H*", "0000000000000000"), 
#	pack("H*", "FFFE"), pack("H*", "547832436f6f7264"));
#$xbee->read_api while 1;
#$xbee->at_command_remote(pack("H*","0000000000000000ffFE02443103"));
#$xbee->modem_status;
#my $id = $xbee->at_command_remote(pack("H*", "0013a20040318040"), pack("H*", "FFFE"), "SP","\x40");
#$xbee->read_api;
#$id = $xbee->at_command_remote(pack("H*", "0013a20040552245"), pack("H*", "FFFE"), "IR",pack("n", 100));
#y $id = $xbee->at_command("DB");
while ( 1 ) {
	 my $frame = $xbee->read_api;
	if ($frame->{type} == 0xA1) {
		print Dumper($frame);
	}
}
