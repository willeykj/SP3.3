#
# Copyright (C) 2008, 2009 Wayne Meissner
# Copyright (c) 2007, 2008 Evan Phoenix
#
# This file is part of ruby-ffi.
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the Ruby FFI project nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

dir = File.dirname(__FILE__)
require File.join(dir, 'platform')

module FFI
  class Pointer
    
    # Pointer size
    SIZE = Platform::ADDRESS_SIZE / 8

    # Return the size of a pointer on the current platform, in bytes
    # @return [Numeric]
    def self.size
      SIZE
    end

    # @param [nil,Numeric] len length of string to return
    # @return [String]
    # Read pointer's contents as a string, or the first +len+ bytes of the 
    # equivalent string if +len+ is not +nil+.
    def read_string(len=nil)
      if len
        get_bytes(0, len)
      else
        get_string(0)
      end
    end

    # @param [Numeric] len length of string to return
    # @return [String]
    # Read the first +len+ bytes of pointer's contents as a string.
    #
    # Same as:
    #  ptr.read_string(len)  # with len not nil
    def read_string_length(len)
      get_bytes(0, len)
    end

    # @return [String]
    # Read pointer's contents as a string.
    #
    # Same as:
    #  ptr.read_string  # with no len
    def read_string_to_null
      get_string(0)
    end

    # @param [String] str string to write
    # @param [Numeric] len length of string to return
    # @return [self]
    # Write +len+ first bytes of +str+ in pointer's contents.
    #
    # Same as:
    #  ptr.write_string(str, len)   # with len not nil
    def write_string_length(str, len)
      put_bytes(0, str, 0, len)
    end

    # @param [String] str string to write
    # @param [Numeric] len length of string to return
    # @return [self]
    # Write +str+ in pointer's contents, or first +len+ bytes if 
    # +len+ is not +nil+.
    def write_string(str, len=nil)
      len = str.bytesize unless len
      # Write the string data without NUL termination
      put_bytes(0, str, 0, len)
    end

    # @param [Type] type type of data to read from pointer's contents
    # @param [Symbol] reader method to send to +self+ to read +type+
    # @param [Numeric] length
    # @return [Array]
    # Read an array of +type+ of length +length+.
    # @example
    #  ptr.read_array_of_type(TYPE_UINT8, :get_uint8, 4) # -> [1, 2, 3, 4]
    def read_array_of_type(type, reader, length)
      ary = []
      size = FFI.type_size(type)
      tmp = self
      length.times { |j|
        ary << tmp.send(reader)
        tmp += size unless j == length-1 # avoid OOB
      }
      ary
    end

    # @param [Type] type type of data to write to pointer's contents
    # @param [Symbol] writer method to send to +self+ to write +type+
    # @param [Array] ary
    # @return [self]
    # Write +ary+ in pointer's contents as +type+.
    # @example
    #  ptr.write_array_of_type(TYPE_UINT8, :put_uint8, [1, 2, 3 ,4])
    def write_array_of_type(type, writer, ary)
      size = FFI.type_size(type)
      tmp = self
      ary.each_with_index {|i, j|
        tmp.send(writer, i)
        tmp += size unless j == ary.length-1 # avoid OOB
      }
      self
    end
  end
end
