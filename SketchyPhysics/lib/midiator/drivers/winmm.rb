#!/usr/bin/env ruby
#
# The MIDIator driver to interact with Windows Multimedia.  Taken more or less
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

class MIDIator::Driver::WinMM < MIDIator::Driver # :nodoc:
  module C # :nodoc:
    if RUBY_VERSION =~ /1.8/
      extend DL::Importable
      dlload 'winmm'
      extern "int midiOutOpen(HMIDIOUT*, int, int, int, int)"
      extern "int midiOutClose(int)"
      extern "int midiOutShortMsg(int, int)"
    else
      extend FFI::Library
      ffi_lib 'winmm'
      attach_function :midiOutOpen, [:pointer, :int, :int, :int, :int], :int
      attach_function :midiOutClose, [:int], :int
      attach_function :midiOutShortMsg, [:int, :uint], :int
    end
  end

  def open
    if RUBY_VERSION =~ /1.8/
      @device = DL.malloc(DL.sizeof('I'))
    else
      @device = FFI::MemoryPointer.new(FFI.type_size(:int))
    end
    C.midiOutOpen(@device, -1, 0, 0, 0)
  end

  def close
    if RUBY_VERSION =~ /1.8/
      C.midiOutClose(@device.ptr.to_i)
    else
      C.midiOutClose(@device.read_int)
    end
  end

  def message(one, two = 0, three = 0)
    message = one + (two << 8) + (three << 16)
    if RUBY_VERSION =~ /1.8/
      C.midiOutShortMsg(@device.ptr.to_i, message)
    else
      C.midiOutShortMsg(@device.read_int, message)
    end
  end
end
