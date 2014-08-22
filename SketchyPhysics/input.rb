require 'sketchup.rb'

dir = File.dirname(__FILE__)
if RUBY_VERSION =~ /1.8/
  require File.join(dir, 'lib/dl/import.rb')
  require File.join(dir, 'lib/dl/struct.rb')
  require File.join(dir, 'lib/Win32API')
else
  require File.join(dir, 'lib/ffi')
  require 'Win32API' # Use one from the tools folder.
end

# Make this version global for now. Needed to allow legacy scripted joints to work.
def getKeyState(key)
    MSketchyPhysics3.getKeyState(key)
end

#GetKeys.getKeyState(VK_LCONTROL) whenever you want to check for control key and
#GetKeys.getKeyState(VK_LSHIFT) whenever you want to check for shift

module MSketchyPhysics3

if RUBY_PLATFORM =~ /mswin|mingw/i
    if RUBY_VERSION =~ /1.8/
        extend DL::Importable
        dlload 'user32.dll'
        extern "BOOL SetCursorPos(int, int)"
        extern "BOOL GetCursorPos(void*)"
        extern "int ShowCursor(BOOL)"
    else
        extend FFI::Library
        ffi_lib 'user32.dll'
        attach_function :setCursorPos, :SetCursorPos, [:int, :int], :bool
        attach_function :getCursorPos, :GetCursorPos, [:pointer], :bool
        attach_function :showCursor, :ShowCursor, [:bool], :int
    end
    GetKeyState = Win32API.new('User32.dll', 'GetKeyState', ['N'], 'N')

    class << self

        def getCursor
            if RUBY_VERSION =~ /1.8/
                buf = (0.chr*8).to_ptr
                getCursorPos(buf)
                buf.to_a('L2')
            else
                buf = FFI::MemoryPointer.new(:int, 2)
                getCursorPos(buf)
                buf.read_array_of_int(2)
            end
        end

        def setCursor(x,y)
            setCursorPos(x,y)
        end

        def hideCursor(bool)
            if bool
                while(showCursor(!bool)>-1); end
            else
                while(showCursor(!bool)<=0); end
            end
        end

        def getKeyState(vk)
            (GetKeyState.call(vk)%256 >> 7) != 0
        end

    end # proxy class

else # Must be using Mac OS X.

    dir = File.dirname(__FILE__)

    if RUBY_VERSION =~ /1.8/
        extend DL::Importable
        dllaod File.join(dir, 'lib/darwin/GetKeys.dylib')
        extern "BOOL TestForKeyDown(short)"
    else
        extend FFI::Library
        ffi_lib File.join(dir, 'lib/darwin/GetKeys.dylib')
        attach_function :testForKeyDown, :TestForKeyDown, [:short], :bool
    end

    class << self

        def getCursor
            # not working yet
            [0,0]
        end

        def setCursor(x,y)
            # not working yet
        end

        def hideCursor(bool)
            # not working yet
        end

        def getKeyState(vk)
            testForKeyDown(vk)
        end

    end # proxy class
end

end # module MSketchyPhysics3


module MSketchyPhysics3::JoyInput

    dir = File.dirname(__FILE__)
    if RUBY_VERSION =~ /1.8/
        extend DL::Importable
        if RUBY_PLATFORM =~ /mswin|mingw/i
            dlload File.join(dir, 'lib/WinInput.dll')
        else
            dlload File.join(dir, 'lib/MacInput.dylib')
        end
        extern "int initInput()"
        extern "int readJoystick(void*)"
        extern "void freeInput()"
        JOY_STATE = struct [
            "int lX",
            "int lY",
            "int lZ",
            "int lRx",
            "int lRy",
            "int lRz",
            "int rglSlider[2]",
            "int rgdwPOV[4]",
            "char rgbButtons[128]",
            "int lVX",
            "int lVY",
            "int lVZ",
            "int lVRx",
            "int lVRy",
            "int lVRz",
            "int rglVSlider[2]",
            "int lAX",
            "int lAY",
            "int lAZ",
            "int lARx",
            "int lARy",
            "int lARz",
            "int rglASlider[2]",
            "int lFX",
            "int lFY",
            "int lFZ",
            "int lFRx",
            "int lFRy",
            "int lFRz",
            "int rglFSlider[2]"
        ]
        @cur_joy_state = JOY_STATE.malloc
    else
        extend FFI::Library
        if RUBY_PLATFORM =~ /mswin|mingw/i
            ffi_lib File.join(dir, 'lib/WinInput.dll')
        else
            ffi_lib File.join(dir, 'lib/MacInput.dylib')
        end
        attach_function :initInput, [], :int
        attach_function :readJoystick, [:pointer], :int
        attach_function :freeInput, [], :void
        class JoyStateStruct < FFI::Struct
          layout :lX, :int,
            :lY, :int,
            :lZ, :int,
            :lRx, :int,
            :lRy, :int,
            :lRz, :int,
            :rglSlider, [:int, 2],
            :rgdwPOV, [:int, 4],
            :rgbButtons, [:char, 128],
            :lVX, :int,
            :lVY, :int,
            :lVZ, :int,
            :lVRx, :int,
            :lVRy, :int,
            :lVRz, :int,
            :rglVSlider, [:int, 2],
            :lAX, :int,
            :lAY, :int,
            :lAZ, :int,
            :lARx, :int,
            :lARy, :int,
            :lARz, :int,
            :rglASlider, [:int, 2],
            :lFX, :int,
            :lFY, :int,
            :lFZ, :int,
            :lFRx, :int,
            :lFRy, :int,
            :lFRz, :int,
            :rglFSlider, [:int, 2]
        end
        @cur_joy_state = JoyStateStruct.new
    end

    class << self

        def state
            @cur_joy_state
        end

        def updateInput
            readJoystick(@cur_joy_state.to_ptr)
            @cur_joy_state
        end

    end # proxy class

end # module MSketchyPhysics3::JoyInput
