#!/usr/bin/env ruby
#
# The MIDIator driver to interact with ALSA on Linux.  Taken more or less
# directly from Practical Ruby Projects.
#
# NOTE: as yet completely untested.
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

class MIDIator::Driver::ALSA < MIDIator::Driver # :nodoc:
  # tell the user they need to connect to their output
  def instruct_user!
    $stderr.puts "[MIDIator] Please connect the MIDIator output port to your input"
    $stderr.puts "[MIDIator] of choice.  You can use qjackctl or aconnect to do so."
    $stderr.puts "[MIDIator]"
    $stderr.puts "[MIDIator] Press enter when you're done."

    gets # wait for the enter
  end


  module C # :nodoc:
    if RUBY_VERSION =~ /1.8/
      extend DL::Importable
      dlload 'libasound.so'

      extern "int snd_rawmidi_open(void*, void*, char*, int)"
      extern "int snd_rawmidi_close(void*)"
      extern "int snd_rawmidi_write(void*, void*, int)"
      extern "int snd_rawmidi_drain(void*)"
    else
      extend FFI::Library
      ffi_lib 'libasound.so'
      attach_function :snd_rawmidi_open, [:pointer, :pointer, :pointer, :int], :int
      attach_function :snd_rawmidi_close, [:pointer], :int
      attach_function :snd_rawmidi_write, [:pointer, :pointer, :int], :int
      attach_function :snd_rawmidi_drain, [:pointer], :int
    end
  end

  def open
    if RUBY_VERSION =~ /1.8/
      @output = DL::PtrData.new(nil)
      C.snd_rawmidi_open(nil, @output.ref, "virtual", 0)
    else
      output_ptr = FFI::MemoryPointer.new(:pointer)
      C.snd_rawmidi_open(nil, output_ptr, "virtual", 0)
      @output = client_ptr.read_pointer
    end
  end

  def close
    C.snd_rawmidi_close(@output)
  end

  def message(*args)
    if RUBY_VERSION =~ /1.8/
      format = "C" * args.size
      bytes = args.pack(format).to_ptr
    else
      bytes = args.pack('C*')
    end
    C.snd_rawmidi_write(@output, bytes, args.size)
    C.snd_rawmidi_drain(@output)
  end
end
