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

# General Xbee device module. (Wrapper functions for serial communications mostly)

package Xbee::Device;

use strict;
use warnings;
use Carp;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;
use Device::SerialPort;

sub new {
    my ( $self, $opts ) = @_;
    my $serial = new Device::SerialPort( $opts->{port} )
      or croak "Can't open serial port $!";
    $serial->baudrate( $opts->{speed} || 9600 );
#    $serial->handshake("rts");
	$serial->read_const_time(10000);
 $opts->{serial} = $serial;
    return bless $opts, $self;
}

# Debug Wrappers
sub read {
    my ( $self, $want ) = @_;
	croak "Want undefined!" if not defined $want;
    my $t0 = [gettimeofday];
    my ( $count, $buf ) = $self->{serial}->read($want);
    my $str = unpack("H*", $buf);
    #$str =~ s/\r/\\r/xmsig;
    #$str =~ s/\n/\\n/xmsig;
    print "--> $str ($count) (", tv_interval( $t0, [gettimeofday] ), ")\n"
      if $self->{debug};
    return ( $count, $buf );
}

sub write {
    my ( $self, $buf ) = @_;
    my $count = $self->{serial}->write($buf);
    #my $str   = $buf;
    my $str = unpack("H*", $buf);
    $str =~ s/\r/\\r/xmsig;
    $str =~ s/\n/\\n/xmsig;
    print "<-- $str ($count)\n" if $self->{debug};
    return $count;
}

1;
