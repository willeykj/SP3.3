require 'sketchup.rb'

dir = File.dirname(__FILE__)
if RUBY_VERSION =~ /1.8/
  require File.join(dir, 'lib/dl/import.rb')
  require File.join(dir, 'lib/dl/struct.rb')
else
  require File.join(dir, 'lib/ffi')
end

module MSketchyPhysics3

module SDL

  dir = File.dirname(__FILE__)

  if RUBY_VERSION =~ /1.8/
    extend DL::Importable

    if RUBY_PLATFORM =~ /mswin|mingw/i
      dlload File.join(dir, 'lib/sdl/SDL.dll')

      extern "int SDL_Init(int)"
      extern "void* SDL_RWFromFile(void*, void*)"
      extern "void* SDL_RWFromMem(void*, int)"
      extern "void* SDL_GetError()"

      dlload File.join(dir, 'lib/sdl/SDL_mixer.dll')
    else
      dlload File.join(dir, 'lib/sdl/SDL_Special.dylib')

      extern "int SDL_Init(int)"
      extern "void* SDL_RWFromFile(void*, void*)"
      extern "void* SDL_RWFromMem(void*, int)"
      extern "void* SDL_GetError()"
    end
    extern "int Mix_OpenAudio(int, int, int, int)"
    extern "void Mix_CloseAudio()"
    extern "void* Mix_LoadWAV_RW(void*, int)"
    extern "int Mix_PlayChannelTimed(int, void*, int, int)"
    extern "void* Mix_LoadMUS_RW(void*)"
    extern "int Mix_PlayMusic(void*, int)"
    extern "int Mix_Volume(int, int)"
    extern "void Mix_SetPosition(int, int, int)"
    extern "void Mix_SetPanning(int, int, int)"
    extern "void Mix_SetDistance(int, int)"
    extern "void Mix_Pause(int)"
    extern "void Mix_Resume(int)"
    extern "void Mix_HaltChannel(int)"
  else
    extend FFI::Library

    if RUBY_PLATFORM =~ /mswin|mingw/i
      ffi_lib File.join(dir, 'lib/sdl/SDL.dll')

      attach_function :sDL_Init, :SDL_Init, [:int], :int
      attach_function :sDL_RWFromFile, :SDL_RWFromFile, [:pointer, :pointer], :pointer
      attach_function :sDL_RWFromMem, :SDL_RWFromMem, [:pointer, :int], :pointer
      attach_function :sDL_GetError, :SDL_GetError, [], :pointer

      ffi_lib File.join(dir, 'lib/sdl/SDL_mixer.dll')
    else
      ffi_lib File.join(dir, 'lib/sdl/SDL_Special.dylib')

      attach_function :sDL_Init, :SDL_Init, [:int], :int
      attach_function :sDL_RWFromFile, :SDL_RWFromFile, [:pointer, :pointer], :pointer
      attach_function :sDL_RWFromMem, :SDL_RWFromMem, [:pointer, :int], :pointer
      attach_function :sDL_GetError, :SDL_GetError, [], :pointer
    end
    attach_function :mix_OpenAudio, :Mix_OpenAudio, [:int, :int, :int, :int], :int
    attach_function :mix_CloseAudio, :Mix_CloseAudio, [], :void
    attach_function :mix_LoadWAV_RW, :Mix_LoadWAV_RW, [:pointer, :int], :pointer
    attach_function :mix_PlayChannelTimed, :Mix_PlayChannelTimed, [:int, :pointer, :int, :int], :int
    attach_function :mix_LoadMUS_RW, :Mix_LoadMUS_RW, [:pointer], :pointer
    attach_function :mix_PlayMusic, :Mix_PlayMusic, [:pointer, :int], :int
    attach_function :mix_Volume, :Mix_Volume, [:int, :int], :int
    attach_function :mix_SetPosition, :Mix_SetPosition, [:int, :int, :int], :void
    attach_function :mix_SetPanning, :Mix_SetPanning, [:int, :int, :int], :void
    attach_function :mix_SetDistance, :Mix_SetDistance, [:int, :int], :void
    attach_function :mix_Pause, :Mix_Pause, [:int], :void
    attach_function :mix_Resume, :Mix_Resume, [:int], :void
    attach_function :mix_HaltChannel, :Mix_HaltChannel, [:int], :void
  end
end # module SDL

#~ ptr = DL.malloc(DL.sizeof('LL'))
#~ ptr.struct!('LL', :tv_sec, :tv_usec)
#~ ptr[:tv_sec] = 10
#~ ptr[:tv_usec] = 100
#~ sec = ptr[:tv_sec]
#~ usec = ptr[:tv_usec]

class SPSounds

    attr_reader :midi

    def initialize
        # Not working on Mac yet.
        #return unless RUBY_PLATFORM =~ /mswin|mingw/i
        @midi = MIDIator::Interface.midiInterface
        MSketchyPhysics3::SDL.sDL_Init(0x00000010)
        MSketchyPhysics3::SDL.mix_OpenAudio(22050, 0x8010, 2, 512)
        @allSounds = {}
        dict = Sketchup.active_model.attribute_dictionary('SPSounds')
        if dict
            dict.each { |name, data|
                next unless data
                buf = data.pack('C*')
                #puts [name, data.length]
                @allSounds[name] = MSketchyPhysics3::SDL.mix_LoadWAV_RW(MSketchyPhysics3::SDL.sDL_RWFromMem(buf, buf.size), 0)
            }
        end
        @allMusic = {}
        dict = Sketchup.active_model.attribute_dictionary('SPMusic')
        if dict
            dict.each { |name, data|
                next unless data
                buf = data.pack('C*')
                @allMusic[name] = MSketchyPhysics3::SDL.mix_LoadMUS_RW(MSketchyPhysics3::SDL.sDL_RWFromMem(buf, buf.size))
            }
        end
    end

    def play(name, loops = 0)
        # Not working on Mac yet.
        #return unless RUBY_PLATFORM =~ /mswin|mingw/i
        snd = @allSounds[name]
        return MSketchyPhysics3::SDL.mix_PlayChannelTimed(-1, snd, loops, -1) if snd
    end

    def playMusic(name)
        # Not working on Mac yet.
        #return unless RUBY_PLATFORM =~ /mswin|mingw/i
        mus = @allMusic[name]
        MSketchyPhysics3::SDL.mix_PlayMusic(mus,-1) if mus
    end

    def stopAll
        stop(-1)
        #MSketchyPhysics3::SDL.mix_CloseAudio()
        @midi.stopAll() if @midi
    end

    def setVolume(channel, volume)
        MSketchyPhysics3::SDL.mix_Volume(channel, volume)
    end

    def setPosition(channel, angle, dist)
        MSketchyPhysics3::SDL.mix_SetPosition(channel, angle, dist)
    end

    def setPanning(channel, left, right)
        MSketchyPhysics3::SDL.mix_SetPanning(channel, left, right)
    end

    def setDistance(channel, dist)
        MSketchyPhysics3::SDL.mix_SetDistance(channel, dist)
    end

    def pause(channel)
        MSketchyPhysics3::SDL.mix_Pause(channel)
    end

    def resume(channel)
        MSketchyPhysics3::SDL.mix_Resume(channel)
    end

    def stop(channel)
        MSketchyPhysics3::SDL.mix_HaltChannel(channel)
    end

end # class SPSounds

    @c_sound = nil
    #@d_sound = nil

    def loadSound
        dir = File.dirname(__FILE__)
        fn = File.join(dir, 'sounds/wood.wav')
        @c_sound = MSketchyPhysics3::SDL.mix_LoadWAV_RW(MSketchyPhysics3::SDL.sDL_RWFromFile(fn, 'rb'), 0)
        #@d_sound = MSketchyPhysics3::SDL.mix_LoadWAV_RW(MSketchyPhysics3::SDL.sDL_RWFromFile("c:\\temp\\lame\\angstrom_d1.mp3", 'rb'), 0)
    end

    def testSound
        #f = MSketchyPhysics3::SDL.sDL_RWFromFile("c:\\temp\\lame\\angstrom_c1.wav", 'rb')
        #rw = MSketchyPhysics3::SDL.sDL_RWFromMem(data.to_ptr, data.length)
        #snd = MSketchyPhysics3::SDL.mix_LoadWAV_RW(rw, 1)
        #puts MSketchyPhysics3::SDL.sDL_GetError()
        MSketchyPhysics3::SDL.mix_PlayChannelTimed(-1, @c_sound, 0, -1) if @c_sound
        #MSketchyPhysics3::SDL.mix_PlayChannelTimed(-1, @d_sound, 0, -1) if @d_sound
    end

    def exportEmbeddedSounds
        dict = Sketchup.active_model.attribute_dictionary('SPSounds')
        dir = File.dirname(__FILE__)
        dict.each { |name, data|
            next unless data
            buf = data.pack('C*')
            outpath = File.join(dir, "sounds/cache/#{name}")
            f = File.new(outname, 'wb')
            f.write(buf)
            f.close
            #UI.play_sound(outname)
        }
    end

    def playEmbedSound(name)
        name = File.basename(name, '.wav')
        data = Sketchup.active_model.get_attribute('SPSounds', name, nil)
        return unless data
        buf = data.pack('C*')
        dir = File.dirname(__FILE__)
        outpath = File.join(dir, "sounds/cache/#{name}")
        f = File.new(outname, 'wb')
        f.write(buf)
        f.close
        UI.play_sound(outname)
    end

class << self

    def embedSound(fileName)
        name = File.basename(fileName, '.wav')
        f = File.new(fileName, 'rb')
        return false unless f
        data = f.read
        f.close
        buf = data.unpack('C*')
        Sketchup.active_model.set_attribute('SPSounds', name, buf)
        true
    end

    def embedMusic(fileName)
        name = File.basename(fileName, '.ogg')
        f = File.new(fileName, 'rb')
        return false unless f
        data = f.read
        f.close
        buf = data.unpack('C*')
        Sketchup.active_model.set_attribute('SPMusic', name, buf)
        true
    end

    def soundEmbedder
        dlg = UI::WebDialog.new('SoundUI 0.2', true, 'soundemb1', 430, 460, 50, 50, true)
        dir = File.dirname(__FILE__)
        html_path = File.join(dir, 'html/sound_ui.html')
        dlg.set_file(html_path)
        dlg.show
        dlg.add_action_callback('html_loaded'){ |dialog, params|
            # Look for embedded sounds
            dict = Sketchup.active_model.attribute_dictionary('SPSounds')
            if dict
                # Add all present sounds to the html list
                dict.each { |name, data|
                    next unless data
                    js_command = "addToSelection('"+name+"','"+name+"','sound_list')"
                    dlg.execute_script(js_command)
                }
            end
            # Look for embedded sounds
            dict = Sketchup.active_model.attribute_dictionary('SPMusic')
            if dict
                # Add all present music to the html list
                dict.each { |name,data|
                    next unless data
                    js_command = "addToSelection('"+name+"','"+name+"','music_list')"
                    dlg.execute_script(js_command)
                }
            end
        }
        dlg.add_action_callback('embed_sound'){ |dialog, params|
            dir = File.dirname(__FILE__)
            path = File.join(dir, 'sounds/')
            sound_file = UI.openpanel('Add Sound File', path, '*.wav')
            if sound_file != nil #and File.size?(sound_file) < 550000 # If there is a file and is smaller then ~500kB
                if sound_file[-4,4] == '.wav' # Check if wav file
                    if embedSound(sound_file) # If embedding was done add name to html selection
                        name = File.basename(sound_file, '.wav')
                        js_command = "addToSelection('"+name+"','"+name+"','sound_list')"
                        dlg.execute_script(js_command)
                        puts "#{name} sound embedded!"
                    end
                elsif sound_file[-4,4] == ".ogg" # Check if ogg file
                    if embedMusic(sound_file) # If embedding was done add name to html selection
                        name = File.basename(sound_file, '.ogg')
                        js_command = "addToSelection('"+name+"','"+name+"','music_list')"
                        dlg.execute_script(js_command)
                        puts "#{name} sound embedded!"
                    end
                else
                    UI.messagebox "Only supports WAVE(*.wav) and Ogg Vorbis(*.ogg) files!"
                end
            end
        }
        dlg.add_action_callback('play_sound'){ |dialog, params|
            input = params.split('|')
            $spSoundInst.refresh # Do a refresh of embedded sounds
            $spSoundInst.play(input[1]) if input[0] == 'sound_list'
            $spSoundInst.playMusic(input[1], 0) if input[0] == 'music_list' # Play music, single loop
        }
        dlg.add_action_callback('remove_sound'){ |dialog, params|
            input = params.split('|')
            if input[0] == 'music_list'
                dict = Sketchup.active_model.attribute_dictionary('SPMusic') # Look for embedded music
            elsif input[0] == 'sound_list'
                dict = Sketchup.active_model.attribute_dictionary('SPSounds') # Look for embedded sounds
            end
            next unless dict
            data = dict[input[1]] # Find sound to remove
            next unless data
            dict.delete_key(input[1]) # Remove sound/music attribute_dictionary
            js_command = "removeSelectionItem('"+input[1]+"','"+input[0]+"')"
            dlg.execute_script(js_command)
            puts "#{input[1]} removed!"
        }
        dlg.add_action_callback('play_sound_file'){ |dialog, params|
            cSound = MSketchyPhysics3::SDL.mix_LoadWAV_RW(MSketchyPhysics3::SDL.sDL_RWFromFile(params, 'rb'), 0)
            MSketchyPhysics3::SDL.mix_PlayChannelTimed(-1, cSound, 0, -1)
        }
        dlg.set_on_close{
        }
    end

end # proxy class


#~ $spSoundInst = SPSounds.new()

#~ def $spSoundInst.refresh() #adds a refresh method to $spSoundInst instance of SPSounds
    #~ #not working on Mac yet.
    #~ #return if(PLATFORM!="i386-mswin32")

    #~ @allSounds=Hash.new if(!defined?(@allSounds))
    #~ dict=Sketchup.active_model.attribute_dictionary("SPSounds")
    #~ #return if dict==nil
    #~ if dict!=nil
        #~ dict.each{|name,data|
            #~ if(data!=nil)
                #~ data=data.pack("C*")
                #~ #puts [name,data.length]
                #~ @allSounds[name]=MSketchyPhysics3::SDL.mix_LoadWAV_RW(MSketchyPhysics3::SDL.sDL_RWFromMem(data, data.length),0)
            #~ end
        #~ }
    #~ end
    #~ @allMusic=Hash.new if(!defined?(@allMusic))
    #~ dict=Sketchup.active_model.attribute_dictionary("SPMusic")
    #~ return if dict==nil
    #~ dict.each{|name,data|
        #~ if(data!=nil)
            #~ data=data.pack("C*")
            #~ puts [name,data.length]
            #~ @allMusic[name]=MSketchyPhysics3::SDL.mix_LoadMUS_RW(MSketchyPhysics3::SDL.sDL_RWFromMem(data, data.length))
            #~ puts @allMusic[name]
        #~ end
    #~ }
#~ end

#~ def $spSoundInst.playMusic(name,loopnumber=0) #added a loopnumber to set the number of loops
  #~ #not working on Mac yet.
  #~ return if(PLATFORM!="i386-mswin32")
  #~ mus=@allMusic[name]
  #~ if(mus!=nil)
      #~ puts MSketchyPhysics3::SDL.mix_PlayMusic(mus,loopnumber);
  #~ end
#~ end

end # module MSketchyPhysics3
