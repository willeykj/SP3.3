# A MIDI driver to play MIDI using OSX's built in DLS synthesizer.
#
# == Authors
#
# * Adam Murray <adam@compusition.com>
#
# == Copyright
#
# Copyright (c) 2008 Adam Murray
#
# This code released under the terms of the MIT license.
#

if RUBY_VERSION =~ /1.8/
  require File.expand_path('../../../dl/import', __FILE__)
  require File.expand_path('../../../dl/struct', __FILE__)
else
  require File.expand_path('../../../ffi', __FILE__)
end

class String
  def to_bytes
    bytes = 0
    self.each_byte do |byte|
      bytes <<= 8
      bytes += byte
    end
    return bytes
  end
end

class MIDIator::Driver::DLSSynth < MIDIator::Driver # :nodoc:

  attr_accessor :synth

  module AudioToolbox
    if RUBY_VERSION =~ /1.8/
      extend DL::Importable
      dlload '/System/Library/Frameworks/AudioToolbox.framework/Versions/Current/AudioToolbox'

      ComponentDescription = struct [
        "int componentType",
        "int componentSubType",
        "int componentManufacturer",
        "int componentFlags",
        "int componentFlagsMask"
      ]

      # to_bytes may not be strictly necessary but these are supposed to be 4 byte numbers
      AudioUnitManufacturer_Apple    = 'appl'.to_bytes
      AudioUnitType_MusicDevice      = 'aumu'.to_bytes
      AudioUnitSubType_DLSSynth      = 'dls '.to_bytes
      AudioUnitType_Output           = 'auou'.to_bytes
      AudioUnitSubType_DefaultOutput = 'def '.to_bytes

      extern 'int NewAUGraph(void *)'
      extern 'int AUGraphAddNode(void *, ComponentDescription *, void *)'
      extern 'int AUGraphOpen(void *)'
      extern 'int AUGraphConnectNodeInput(void *, void *, int, void *, int)'
      extern 'int AUGraphNodeInfo(void *, void *, ComponentDescription *, void *)'
      extern 'int AUGraphInitialize(void *)'
      extern 'int AUGraphStart(void *)'
      extern 'int AUGraphStop(void *)'
      extern 'int DisposeAUGraph(void *)'

      extern 'void * CAShow(void *)'

      extern 'void * MusicDeviceMIDIEvent(void *, int, int, int, int)'
    else
      extend FFI::Library
      ffi_lib '/System/Library/Frameworks/AudioToolbox.framework/Versions/Current/AudioToolbox'

      class ComponentDescription < FFI::Sctruct
        layout :componentType, :int,
          :componentSubType, :int,
          :componentManufacturer, :int,
          :componentFlags, :int,
          :componentFlagsMask, :int
      end

      AudioUnitManufacturer_Apple    = 'appl'
      AudioUnitType_MusicDevice      = 'aumu'
      AudioUnitSubType_DLSSynth      = 'dls '
      AudioUnitType_Output           = 'auou'
      AudioUnitSubType_DefaultOutput = 'def '

      attach_function :newAUGraph, :NewAUGraph, [:pointer], :int
      attach_function :aUGraphAddNode, :AUGraphAddNode, [:pointer, :pointer, :pointer], :int
      attach_function :aUGraphOpen, :AUGraphOpen, [:pointer], :int
      attach_function :aUGraphConnectNodeInput, :AUGraphConnectNodeInput, [:pointer, :pointer, :int, :pointer, :int], :int
      attach_function :aUGraphNodeInfo, :AUGraphNodeInfo, [:pointer, :pointer, :pointer, :pointer], :int
      attach_function :aUGraphInitialize, :AUGraphInitialize, [:pointer], :int
      attach_function :aUGraphStart, :AUGraphStart, [:pointer], :int
      attach_function :aUGraphStop, :AUGraphStop, [:pointer], :int
      attach_function :disposeAUGraph, :DisposeAUGraph, [:pointer], :int
      attach_function :cAShow, :CAShow, [:pointer], :pointer
      attach_function :musicDeviceMIDIEvent, :MusicDeviceMIDIEvent, [:pointer, :int, :int, :int, :int], :pointer
    end
  end

  protected

  def require_noerr(action_description, &block)
    if block.call != 0
      fail "Failed to #{action_description}"
    end
  end

  def open
    if RUBY_VERSION =~ /1.8/
      @synth = DL::PtrData.new(nil)
      @graph = DL::PtrData.new(nil)
      synthNode = DL::PtrData.new(nil)
      outNode = DL::PtrData.new(nil)

      cd = AudioToolbox::ComponentDescription.malloc()
      cd.componentManufacturer = AudioToolbox::AudioUnitManufacturer_Apple
      cd.componentFlags = 0
      cd.componentFlagsMask = 0

      require_noerr('create AUGraph') { AudioToolbox.newAUGraph(@graph.ref) }

      cd.componentType = AudioToolbox::AudioUnitType_MusicDevice
      cd.componentSubType = AudioToolbox::AudioUnitSubType_DLSSynth
      require_noerr('add synthNode') { AudioToolbox.aUGraphAddNode(@graph, cd, synthNode.ref) }

      cd.componentType = AudioToolbox::AudioUnitType_Output
      cd.componentSubType = AudioToolbox::AudioUnitSubType_DefaultOutput
      require_noerr('add outNode') { AudioToolbox.aUGraphAddNode(@graph, cd, outNode.ref) }

      require_noerr('open graph') { AudioToolbox.aUGraphOpen(@graph) }

      require_noerr('connect synth to out') { AudioToolbox.aUGraphConnectNodeInput(@graph, synthNode, 0, outNode, 0) }

      require_noerr('graph info') { AudioToolbox.aUGraphNodeInfo(@graph, synthNode, nil, @synth.ref) }
    else
      synth_ptr = FFI::MemoryPointer.new(:pointer)
      @synth = graph_ptr.read_ptr
      graph_ptr = FFI::MemoryPointer.new(:pointer)
      @graph = graph_ptr.read_ptr
      synthNode_ptr = FFI::MemoryPointer.new(:pointer)
      synthNode = synthNode_ptr.read_ptr
      outNode_ptr = FFI::MemoryPointer.new(:pointer)
      outNode = outNode_ptr.read_ptr

      cd = ComponentDescription.new()
      cd[:componentManufacturer] = AudioToolbox::AudioUnitManufacturer_Apple
      cd[:componentFlags] = 0
      cd[:componentFlagsMask] = 0

      require_noerr('create AUGraph') {
        AudioToolbox.newAUGraph(graph_ptr)
        @graph = graph_ptr.read_ptr
      }

      cd[:componentType] = AudioToolbox::AudioUnitType_MusicDevice
      cd[:componentSubType] = AudioToolbox::AudioUnitSubType_DLSSynth
      require_noerr('add synthNode') {
        AudioToolbox.aUGraphAddNode(@graph, cd, synthNode_ptr)
        synthNode = synthNode_ptr.read_ptr
      }

      cd[:componentType] = AudioToolbox::AudioUnitType_Output
      cd[:componentSubType] = AudioToolbox::AudioUnitSubType_DefaultOutput
      require_noerr('add outNode') {
        AudioToolbox.aUGraphAddNode(@graph, cd, outNode_ptr)
        outNode = outNode_ptr.read_ptr
      }

      require_noerr('open graph') { AudioToolbox.aUGraphOpen(@graph) }

      require_noerr('connect synth to out') { AudioToolbox.aUGraphConnectNodeInput(@graph, synthNode, 0, outNode, 0) }

      require_noerr('graph info') {
        AudioToolbox.aUGraphNodeInfo(@graph, synthNode, nil, synth_ptr)
        @synth = synth_ptr.read_ptr
      }
    end
    require_noerr('init graph') { AudioToolbox.aUGraphInitialize(@graph) }
    require_noerr('start graph') { AudioToolbox.aUGraphStart(@graph) }
    AudioToolbox.cAShow(@graph) if $DEBUG
  end

  def message(*args)
    arg0 = args[0] || 0
    arg1 = args[1] || 0
    arg2 = args[2] || 0
    AudioToolbox.musicDeviceMIDIEvent(@synth, arg0, arg1, arg2, 0)
  end

  def close
    if @graph
      AudioToolbox.aUGraphStop(@graph)
      AudioToolbox.disposeAUGraph(@graph)
    end
  end
end
