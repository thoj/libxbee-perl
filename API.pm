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

# Module for parsing and sending API frames from/to Digi Xbee devices

package Xbee::API;
use strict;
use warnings;
use FileHandle;
use List::Util qw/sum/;
use Carp;
use Time::HiRes qw/gettimeofday tv_interval/;

use Data::Dumper;
use Xbee::Device;

sub new {
    my ( $self, $opts ) = @_;
    my %xbee;
    $xbee{device} = Xbee::Device->new($opts);
    $xbee{debug}  = $opts->{debug};
    return bless \%xbee, $self;
}

sub _shift {
    my ( $arr, $nr ) = @_;
    return shift @$arr if not defined $nr or $nr < 2;
    my $str;
    while ( $nr-- ) {
        $str .= shift @$arr;
    }
    return $str;
}

sub read_api {
    my ($self) = @_;
    my %api_frame;
    my ( $count, $buf );
    ( $count, $buf ) = $self->{device}->read(1);
    return undef if $count < 1;
    if ( $buf eq "\x7e" ) {
        my $t00 = [gettimeofday];
        ( $count, $buf ) = $self->{device}->read(2);
        $api_frame{length} = unpack( "n", $buf );
        ( $count, $buf ) = $self->{device}->read( $api_frame{length} );
        my @chunks = split( //, $buf );
        $api_frame{raw_data} = $buf;
        $api_frame{type} = unpack( "C", shift @chunks );

        # AT command response
        if ( $api_frame{type} == 0x88 ) {
            $api_frame{id} = unpack( "C", shift @chunks );
            $api_frame{at_command} = _shift( \@chunks, 2 );

            # 00 OK; 01 Error; 02 Invalid command; 03 Invalid parameter
            $api_frame{status} = unpack( 'C', shift @chunks );
            $api_frame{at_data} = join( '', @chunks );
        }

        #Zigbee Transmit Status
        elsif ( $api_frame{type} == 0x8b ) {
            $api_frame{id}          = unpack( "C",  shift @chunks );
            $api_frame{dest_adress} = unpack( "H*", _shift( \@chunks, 2 ) );
            $api_frame{retry_count} = unpack( "C",  shift @chunks );

            # 00 Success; 02 CCA Fail; 15 Invalid Destination
            # 21 Network ACK Fail; 22 Not Joined; 23 Self Addressed
            # 24 Adress Not Found; 25 Route Not FOund; 74 Data too large
            $api_frame{delivery_status} = unpack( "C", shift @chunks );

            # 00 No Discovery; 01 Adress Discovery; 02 Route Discovery
            # 03 Adresss and Route
            $api_frame{discovery_status} = unpack( "C", shift @chunks );
        }

        #Zigbee Recive Packet
        elsif ( $api_frame{type} == 0x90 ) {
            $api_frame{id}      = unpack( "C",  shift @chunks );
            $api_frame{serial}  = unpack( "H*", _shift( \@chunks, 7 ) );
            $api_frame{address} = unpack( "H*", _shift( \@chunks, 2 ) );

            # 01 Acked; 02 Broadcast
            $api_frame{receive_options} = unpack( "C", shift @chunks );
            $api_frame{data} = join( '', @chunks );
        }

        # Zigbee IO Data Sample RX Indicator
        # $mV = ( $val ) * 1200 ) / 1024;
        elsif ( $api_frame{type} == 0x92 ) {
            $api_frame{source_serial}  = unpack( "H*", _shift( \@chunks, 8 ) );
            $api_frame{source_address} = unpack( "H*", _shift( \@chunks, 2 ) );
            $api_frame{receive_options} = unpack( "C", shift @chunks );
            $api_frame{samples}         = unpack( "C", shift @chunks );
            $api_frame{digital_mask} =
              pack( "s", unpack( "n", _shift( \@chunks, 2 ) ) );
            $api_frame{analog_mask} = shift @chunks;
            if ( unpack( "s", $api_frame{digital_mask} ) > 0 ) {
                $api_frame{digital_samples} =
                  pack( "s", unpack( "n", _shift( \@chunks, 2 ) ) );
            }
            if ( unpack( "C", $api_frame{analog_mask} ) > 0 ) {
                my @analog_samples;
                for ( my $i = 0 ; $i < 8 ; $i++ ) {
                    if ( vec( $api_frame{analog_mask}, $i, 1 ) == 1 ) {
                        push @analog_samples,
                          ( unpack( "n", _shift( \@chunks, 2 ) ) * 1200 ) /
                          1024;
                    }
                }
		@analog_samples = map { sprintf("%.2f", $_); } @analog_samples;
                $api_frame{analog_samples} = \@analog_samples;
            }

        }

        #Node Discovery
        elsif ( $api_frame{type} == 0x95 ) {
            $api_frame{request_serial} = unpack( "H*", _shift( \@chunks, 8 ) );
            $api_frame{net_address}    = unpack( "H*", _shift( \@chunks, 2 ) );

            # 01 Acked; 02 Broadcast
            $api_frame{receive_options} = unpack( "C",  _shift( \@chunks ) );
            $api_frame{source_address}  = unpack( "H*", _shift( \@chunks, 2 ) );
            $api_frame{serial}          = unpack( "H*", _shift( \@chunks, 8 ) );
            $api_frame{identifier} = "";
            while ( my $nic = shift @chunks ) {
                if ( $nic eq "\x00" ) { last; }
                $api_frame{identifier} .= $nic;
            }
            $api_frame{parent_address} = unpack( "H*", _shift( \@chunks, 2 ) );
            $api_frame{device_type}    = unpack( "C",  shift @chunks );
            $api_frame{source_event}   = unpack( "C",  shift @chunks );
            $api_frame{digi_profile}   = unpack( "n",  _shift( \@chunks, 2 ) );
            $api_frame{manufacturer_id}= unpack( "n",  _shift( \@chunks, 2 ) );
        }
        elsif ( $api_frame{type} == 0x97 ) {
            $api_frame{id}      = unpack( "C",  shift @chunks );
            $api_frame{serial}  = unpack( "H*", _shift( \@chunks, 8 ) );
            $api_frame{address} = unpack( "H*", _shift( \@chunks, 2 ) );
            $api_frame{at} = _shift( \@chunks, 2 );

            # 0 OK; 1 ERROR; 2 Invalid Command; 3 Invalid Parameter
            $api_frame{status} = unpack( "C", shift @chunks );
            $api_frame{at_data} = join "", @chunks;

        }
	elsif ($api_frame{type} == 0xA1) {
            $api_frame{serial}  = unpack( "H*", _shift( \@chunks, 8 ) );
            $api_frame{address} = unpack( "H*", _shift( \@chunks, 2 ) );
            $api_frame{options} = unpack( "C", shift @chunks );
            $api_frame{addresses_nr} = unpack( "C", shift @chunks );
		my @addresses;
	    for (my $i = 0; $i < $api_frame{addresses_nr}; $i++) {
			push @addresses, unpack( "H*", _shift( \@chunks, 2 ) );
		}
		$api_frame{addresses} = \@addresses;
	}
        else {
            printf( "Unknown frametype: %x\n", $api_frame{type} );
        }

        my $check    = unpack( "C", $self->{device}->read(1) );
        my $gencheck = unpack( "C", $self->checksum($buf) );
        if ( $check == $gencheck ) {
            $api_frame{checksum} = "OK";
        }
        else {
            print "Checksum: $check != $gencheck\n";
            $api_frame{checksum} = "FAIL";
        }
        print Dumper( \%api_frame ) if $self->{debug};
        print "API Read Time: ", tv_interval( $t00, [gettimeofday] ), "s\n"
          if $self->{debug};
        return \%api_frame;
    }
    else {
        print "Unexpected = ", unpack( "H*", $buf ), "\n";
	return undef;
    }

}

sub checksum {
    my ( $self, $data ) = @_;
    my @t = unpack( "C*", $data );
    my $checksum = sum(@t);
    $checksum = 255 - $checksum;
    return pack( "C", $checksum & 255 );
}

sub api_command {
    my ( $self, $api_struct ) = @_;
    my $frame = "\x7E";
    print "API struct length = " . length $api_struct, "\n" if $self->{debug};
    $frame .= pack( "n", length $api_struct );
    $frame .= $api_struct;
    $frame .= $self->checksum($api_struct);

    #	print unpack("H*", $frame), "\n" if $self->{debug};
    $self->{device}->write($frame);
}

sub modem_status {
    my ($self) = @_;
    $self->api_command("\x8A");
}

sub at_command {
    my ( $self, $command, $data, $id ) = @_;
    $id = int( rand() * 254 ) + 1 if not defined $id;
    $data = "" if not defined $data;
    $self->api_command( "\x08" . pack( "C", $id ) . $command . $data );
}

sub at_command_remote {
    my ( $self, $dest64, $dest16, $command, $data, $id ) = @_;
    $id = int( rand() * 254 ) + 1 if not defined $id;
    if ( defined $data and length $data > 0 ) {
        $self->api_command( "\x17"
              . pack( "C", $id )
              . $dest64
              . $dest16 . "\x02"
              . $command
              . $data );
    }
    else {
        $self->api_command(
            "\x17" . pack( "C", $id ) . $dest64 . $dest16 . "\x00" . $command );
    }
    return $id;
}

sub create_source_route {
	my ($self, $dest64, $dest16, $addresses, $addresses_ref) = @_;
	my $command = "\x21\x00" . $dest64 . $dest16 . "\x00" . chr($addresses);
	for (my $i = 0; $i < $addresses; $i++) {
		 $command .= $addresses_ref->[$i];
	}
        $self->api_command($command);
}

sub transmit_request {
    my ( $self, $dest64, $dest16, $data ) = @_;

    #adress too short - pad it.
    if ( length $dest64 < 8 ) {
        $dest64 = "\x00$dest64";
    }
    $self->api_command( "\x10\x01" . $dest64 . $dest16 . "\x00\x00" . $data );
}

1;
