#!/usr/bin/env ruby
#
# The MIDIator driver to interact with OSX's CoreMIDI.  Taken more or less
# directly from Practical Ruby Projects.
#
# == Authors
#
# * Topher Cyll
# * Ben Bleything <ben@bleything.net>
#
# == Copyright
#
# Copyright (c) 2008 Topher Cyll
#
# This code released under the terms of the MIT license.
#

if RUBY_VERSION =~ /1.8/
  require File.expand_path('../../../dl/import', __FILE__)
else
  require File.expand_path('../../../ffi', __FILE__)
end

require 'midiator'
require 'midiator/driver'
require 'midiator/driver_registry'

class MIDIator::Driver::CoreMIDI < MIDIator::Driver # :nodoc:
  ##########################################################################
  ### S Y S T E M   I N T E R F A C E
  ##########################################################################
  module C # :nodoc:
    if RUBY_VERSION =~ /1.8/
      extend DL::Importable
      dlload '/System/Library/Frameworks/CoreMIDI.framework/Versions/Current/CoreMIDI'

      extern "int MIDIClientCreate( void*, void*, void*, void* )"
      extern "int MIDIClientDispose( void* )"
      extern "int MIDIGetNumberOfDestinations()"
      extern "void* MIDIGetDestination( int )"
      extern "int MIDIOutputPortCreate( void*, void*, void* )"
      extern "void* MIDIPacketListInit( void* )"
      extern "void* MIDIPacketListAdd( void*, int, void*, int, int, int, void* )"
      extern "int MIDISend( void*, void*, void* )"
    else
      extend FFI::Library
      ffi_lib '/System/Library/Frameworks/CoreMIDI.framework/Versions/Current/CoreMIDI'

      attach_function :mIDIClientCreate, :MIDIClientCreate, [:pointer, :pointer, :pointer, :pointer], :int
      attach_function :mIDIClientDispose, :MIDIClientDispose, [:pointer], :int
      attach_function :mIDIGetNumberOfDestinations, :MIDIGetNumberOfDestinations, [], :int
      attach_function :mIDIGetDestination, :MIDIGetDestination, [:int], :pointer
      attach_function :mIDIOutputPortCreate, :MIDIOutputPortCreate, [:pointer, :pointer, :pointer], :int
      attach_function :mIDIPacketListInit, :MIDIPacketListInit, [:pointer], :pointer
      attach_function :mIDIPacketListAdd, :MIDIPacketListAdd, [:pointer, :int, :pointer, :int, :int, :int, :pointer], :pointer
      attach_function :mIDISend, :MIDISend, [:pointer, :pointer, :pointer], :int
    end
  end

  module CF # :nodoc:
    if RUBY_VERSION =~ /1.8/
      extend DL::Importable
      dlload '/System/Library/Frameworks/CoreFoundation.framework/Versions/Current/CoreFoundation'

      extern "void* CFStringCreateWithCString( void*, char*, int )"
    else
      extend FFI::Library
      ffi_lib '/System/Library/Frameworks/CoreFoundation.framework/Versions/Current/CoreFoundation'

      attach_function :cFStringCreateWithCString, :CFStringCreateWithCString, [:pointer, :pointer, :int], :pointer
    end
  end

  ##########################################################################
  ### D R I V E R   A P I
  ##########################################################################

  def open
    client_name = CF.cFStringCreateWithCString( nil, "MIDIator", 0 )
    if RUBY_VERSION =~ /1.8/
      @client = DL::PtrData.new( nil )
      C.mIDIClientCreate( client_name, nil, nil, @client.ref )
    else
      client_ptr = FFI::MemoryPointer.new(:pointer)
      C.mIDIClientCreate( client_name, nil, nil, client_ptr )
      @client = client_ptr.read_pointer
    end

    port_name = CF.cFStringCreateWithCString( nil, "Output", 0 )
    if RUBY_VERSION =~ /1.8/
      @outport = DL::PtrData.new( nil )
      C.mIDIOutputPortCreate( @client, port_name, @outport.ref )
    else
      outport_ptr = FFI::MemoryPointer.new(:pointer)
      C.mIDIOutputPortCreate( @client, port_name, outport_ptr )
      @outport = outport_ptr.read_pointer
    end

    number_of_destinations = C.mIDIGetNumberOfDestinations
    raise MIDIator::NoMIDIDestinations if number_of_destinations < 1
    @destination = C.mIDIGetDestination( 0 )
  end

  def close
    C.mIDIClientDispose( @client )
  end

  def message( *args )
    if RUBY_VERSION =~ /1.8/
      format = "C" * args.size
      bytes = args.pack( format ).to_ptr
      packet_list = DL.malloc( 256 )
    else
      bytes = args.pack('C*')
      packet_list = 0.chr*256
    end
    packet_ptr = C.mIDIPacketListInit( packet_list )

    # Pass in two 32-bit 0s for the 64 bit time
    packet_ptr = C.mIDIPacketListAdd( packet_list, 256, packet_ptr, 0, 0, args.size, bytes )

    C.mIDISend( @outport, @destination, packet_list )
  end
end
