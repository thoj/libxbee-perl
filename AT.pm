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

# Module for working with Digi Xbee in AT mode.
 
package Xbee::AT;
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
    $serial->handshake("none");
$serial->read_const_time(1000);
    my $xbee_opts = { serial => $serial };
    $xbee_opts->{last_command}    = [ gettimeofday- 1000 ];
    $xbee_opts->{command_timeout} = 4;
    $xbee_opts->{debug}           = $opts->{debug};
    $/                            = "\r\n";
    return bless $xbee_opts, $self;
}

# Debug Wrappers
sub read {
    my ( $self, $want ) = @_;
    my $t0 = [gettimeofday];
    my ( $count, $buf ) = $self->{serial}->read($want);
    my $str = $buf;
    $str =~ s/\r/\\r/xmsig;
    $str =~ s/\n/\\n/xmsig;
    print "--> $str ($count) (", tv_interval( $t0, [gettimeofday] ), ")\n"
      if $self->{debug};
    return ( $count, $buf );
}

sub write {
    my ( $self, $buf ) = @_;
    my $count = $self->{serial}->write($buf);
    my $str   = $buf;
    $str =~ s/\r/\\r/xmsig;
    $str =~ s/\n/\\n/xmsig;
    print "<-- $str ($count)\n" if $self->{debug};
    return $count;
}

sub read_ok {
    my ($self) = @_;
    my ( $count, $buf ) = $self->read(3);

    chop $buf;
    if ( $buf eq 'OK' ) {
        $self->{last_command} = [gettimeofday];
        return 1;
    }
    croak( "Expected 'OK' got '" . $buf . "'" );
}

sub start_at {
    my ($self) = @_;
    return
      if tv_interval( $self->{last_command}, [gettimeofday] ) + 0.5 <
          $self->{command_timeout};
    $self->write('+++');
    $self->{serial}->read_const_time(2000);
    $self->read_ok();
    $self->{serial}->read_const_time(1000);
    if ( $self->{command_timeout} == 0 ) {
        my $command_timeout = $self->at_command_ret( 'CT', 1 );
        $self->{command_timeout} =
          unpack( "C", pack( "H2", $command_timeout ) ) / 10;
    }
}

sub stop_at {
    my ($self) = @_;
    return
      if tv_interval( $self->{last_command}, [gettimeofday] ) + 0.5 >
          $self->{command_timeout};
    $self->write("ATCN\r");
	$self->read_ok();
    $self->{last_command}    = [ gettimeofday- 1000 ];
}

sub at_command {
    my ( $self, $command, $skip ) = @_;
    $self->start_at;
    $self->write( 'AT' . $command );
    $self->read_ok();
    $self->{last_command} = 0;
    return 1;
}

sub at_command_ret {
    my ( $self, $command, $expect ) = @_;
	$expect = 25 if not defined $expect;
    $self->start_at;
    $self->write( 'AT' . $command . "\r" );
    my ( $count, $buf ) = $self->{serial}->read($expect);
    chop $buf;
    $self->{last_command} = [gettimeofday];
    return $buf;
}

sub at_command_data {
    my ( $self, $command, $skip ) = @_;
    $self->start_at;
    my ( $count, $buf );
    $count = $self->write( 'AT' . $command . "\r" ) or croak "Write failed: $!";
    ( $count, $buf ) = $self->read(100);
    my @data = split( "\r", $buf );
    $self->{last_command} = [gettimeofday];
    return \@data;
}

sub node_identifier {
    my ( $self, $new ) = @_;
    if ( defined $new ) {
        return $self->at_command_ret( 'NI' . $new );
    }
    return $self->at_command_ret('NI');
}

sub destination_node {
    my ( $self, $new ) = @_;
    croak("destination_node needs a parameter") if not defined $new;
    return $self->at_command( 'DN' . $new );
}

sub address {
    my ( $self, $new ) = @_;
    return $self->at_command_ret("MY") if not defined $new;
    return $self->at_command("MY$new");
}

sub destination_address_high {
    my ( $self, $new ) = @_;
    return $self->at_command_ret("DH") if not defined $new;
    return $self->at_command("DH$new");
}

sub destination_address_low {
    my ( $self, $new ) = @_;
    return $self->at_command_ret("DL") if not defined $new;
    return $self->at_command("DL$new");
}

sub destination_address {
    my ( $self, $new ) = @_;
    return $self->destination_address_high . $self->destination_address_low;
}

#
# VR - Firmware Version
# HV - Hardware Version
# AI - Association Indication
# DB - RSSI of last packet

sub firmware_version {
    my ($self) = @_;
    return $self->at_command_ret('VR');
}

sub hardware_version {
    my ($self) = @_;
    return $self->at_command_ret('HV');
}

sub association_indication {
    my ($self) = @_;
    return $self->at_command_ret('AI');
}

sub rssi {
    my ($self) = @_;
    return -hex ($self->at_command_ret('DB',3) );
}

sub sample {
    my ( $self, $number ) = @_;
    if ( defined $number ) {
        return $self->at_command_data( "IS" . $number );
    }
    return $self->at_command_data("IS");
}

# AD(mV) = (A/D reading * 1200mV) / 1024
sub sample_analog {
    my ( $self, $pin, $raw ) = @_;
    croak "sample_analog expects pin number" if not defined $pin;
    my $data         = $self->sample;
    my $offset       = 3;
    my $digital_mask = hex $data->[1];
    my $adc_mask     = hex $data->[2];
    printf( "Digital mask = %d, Analog Mask = %d\n", $digital_mask, $adc_mask );

    #      if $self->{debug};
    if ( not $adc_mask & ( 1 << $pin ) ) {
        croak "$pin is not in analog mode";
    }
    $offset++ if $digital_mask > 0;
    my $i = 0;
    while ( $i < $pin ) {
        $offset += vec( $adc_mask, $i, 1 );
        $i++;
    }
    return $data->[$offset] if $raw;
    my $value = ( hex( $data->[$offset] ) * 1200 ) / 1024;
    return $value;
}
1;
