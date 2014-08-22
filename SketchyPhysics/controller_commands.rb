require 'sketchup.rb'

module MSketchyPhysics3

  class << self

    def dounit
      sim = SP3xSimulationContext.new(Sketchup.active_model)
      sel = Sketchup.active_model.selection
      sel.each { |e|
        next unless e.is_a?(Sketchup::Group)
        b = sim.createBody(e)
        b._setEvent('ontouch', "puts @name+' touched'")
        b._setEvent('ontouching', "puts @name+' touching'")
        b._setEvent('onuntouch', "puts @name+' untouched'")
        b._setEvent('ontick', "puts @name+' ticked'")
        b ._setEvent('onstart', "puts @name+' start'")
        b._setEvent('onend', "puts @name+' end'")
      }
      sim
    end

  end # proxy class


  class SP3xCommonContext

    include Math
    extend Math

    @@simulation_vars = {}

    def initialize
      @@simulation_vars.clear
      @joy_button_mapping = {
        :a      => 0,
        :b      => 1,
        :x      => 2,
        :y      => 3,
        :lb     => 4,
        :rb     => 5,
        :back   => 6,
        :start  => 7,
        :leftb  => 8,
        :rightb => 9
      }
      @joybutton_replacement_keys = [
        VK_NUMPAD4,
        VK_NUMPAD7,
        VK_NUMPAD8,
        VK_NUMPAD9,
        VK_NUMPAD0,
        VK_NUMPAD6,
        VK_SUBTRACT,
        VK_ADD,
        VK_SEPARATOR,
        VK_MULTIPLY
      ]
    end

    def slider(sname, default_value = 0.5, min = 0.0, max = 1.0)
      unless MSketchyPhysics3.control_sliders[sname]
        MSketchyPhysics3.createController(sname, default_value, min, max)
      end
      MSketchyPhysics3.control_sliders[sname].value
    end

    def setVar(name, value)
      @@simulation_vars[name] = value
    end

    def getVar(name)
      return 0.0 unless @@simulation_vars[name]
      @@simulation_vars[name]
    end

    def getSetVar(name, value = 0)
      v = @@simulation_vars[name]
      @@simulation_vars[name] = value
      v ? v : 0.0
    end

    def evalCurveAbs(name, dist)
      return [0.0, 0.0, 0.0] unless $curPhysicsSimulation
      $curPhysicsSimulation.evalCurveAbs(name, dist)
    end

    # Get key state.
    # @param [Fixnum, String, Symbol] vk
    # @return [Fixnum] 0 : up, 1 : down
    def key(vk)
      unless vk.is_a?(Numeric)
        vk = vk.to_s.downcase.gsub(/_|\s/, '')
        vk = ' ' if vk.empty?
        vk = KEY_NAMES[vk.to_sym]
      end
      return 0 unless vk
      getKeyState(vk.to_i) ? 1 : 0
    end

    def oldplaysound(name)
      dir = File.dirname(__FILE__)
      path = File.join(dir, "sounds/cache/#{name}")
      path = File.join(dir, "sounds/#{name}") unless File.exists?(path)
      UI.play_sound(path) if File.exists?(path)
    end

    def playmusic(name)
      return unless $curPhysicsSimulation
      $curPhysicsSimulation.sounds.playMusic(name)
    end

    def playSound(name, loops = 0)
      return unless $curPhysicsSimulation
      $curPhysicsSimulation.sounds.play(name, loops)
    end

    def setSoundPosition(sound, position, volume = 5.0)
      # Get vector to camera
      vect = camera.eye-position
      # camera.axis is the line through the cameras "ears"
      ears = camera.xaxis
      # dot the ears with the normalized direction to the sound.
      mix = ears.dot(vect.normalize)
      # Result is 0=center, -1=full left ,1=full right
      # Convert to SDL
      angle = (-mix*90).to_i
      dist = (vect.length/volume).to_i
      dist = 255 if dist > 255
      simulation.sounds.setPosition(sound,angle,dist)
    end

    # Modify sound position.
    # @param [Fixnum] channel
    # @param [Geom::Point3d] pos
    # @param [Numeric] range Sound hearing range in inches.
    # @see https://www.libsdl.org/projects/SDL_mixer/docs/SDL_mixer_82.html
    def setSoundPosition2(channel, pos, range = 1000)
      cam = Sketchup.active_model.active_view.camera
      tra = Geom::Transformation.new(cam.xaxis, cam.zaxis, cam.yaxis, cam.eye)
      pos = Geom::Point3d.new(pos.to_a).transform(tra.inverse)
      range = 1 if range < 1
      dist = ORIGIN.distance(pos)
      return simulation.sounds.setPosition(channel, 0, 255) if dist > range
      h = Math.sqrt(pos.x**2 + pos.y**2)
      return simulation.sounds.setPosition(channel, 0, 1) if h.zero?
      vol = (dist * 255.0 / range).round
      angle = Math.asin(pos.x / h.to_f)
      angle = (Math::PI - angle.abs) * (angle <=> 0) if pos.y < 0
      simulation.sounds.setPosition(channel, angle.radians.round, vol)
    end

    def joy(name)
      return 0.5 unless @joystate
      deadzone = 100
      case name.to_s.downcase.to_sym
      when :leftx
        lx = RUBY_VERSION =~ /1.8/ ? @joystate.lX : @joystate[:lX]
        if lX.abs > deadzone
          return lX / 2000.0 + 0.5
        else
          return 0.5 + (getKeyState(VK_D) ? 0.5 : 0.0) + (getKeyState(VK_A) ? -0.5 : 0.0)
        end
      when :lefty
        lY = RUBY_VERSION =~ /1.8/ ? @joystate.lY : @joystate[:lY]
        if lY.abs > deadzone
          return lY / 2000.0 + 0.5
        else
          return 0.5 + (getKeyState(VK_S) ? 0.5 : 0.0) + (getKeyState(VK_W) ? -0.5 : 0.0)
        end
      when :rightx
        lRx = RUBY_VERSION =~ /1.8/ ? @joystate.lRx : @joystate[:lRx]
        if lRx.abs > deadzone
          return lRx / 2000.0 + 0.5
        else
          return 0.5 + (getKeyState(VK_RIGHT) ? 0.5 : 0.0) + (getKeyState(VK_LEFT) ? -0.5 : 0.0)
        end
      when :righty
        lRy = RUBY_VERSION =~ /1.8/ ? @joystate.lRy : @joystate[:lRy]
        if lRy.abs > deadzone
          return lRy / 2000.0 + 0.5
        else
          return 0.5 + (getKeyState(VK_DOWN) ? 0.5 : 0.0) + (getKeyState(VK_UP) ? -0.5 : 0.0)
        end
      end
      0.5
    end

    def joybutton(name)
      return 0 unless @joystate
      deadzone = 100
      v = @joy_button_mapping[name.to_s.downcase.to_sym]
      btnV = RUBY_VERSION =~ /1.8/ ? @joystate.rgbButtons[v] : @joystate[:rgbButtons][v]
      if btnV.abs > deadzone
        btnV / -128
      else
        getKeyState(@joybutton_replacement_keys[v]) ? 1 : 0
      end
    end

  end # class SP3xCommonContext


  class ControllerContext < SP3xCommonContext

    def initialize
      super
    end

    def sample(array, rate = 1)
      v = array[(frame/rate)]
      v.is_a?(Numeric) ? v : 0
    end

    def oscillator(rate)
      inc = Math::PI*2 / rate
      pos = Math.sin(inc * @frame)
      pos / 2.0 + 0.5
    end

    def setCamera
      return unless $curEvalGroup
      xform = $curEvalGroup.transformation
      up = (xform.zaxis == Z_AXIS) ? Y_AXIS : Z_AXIS
      Sketchup.active_model.active_view.camera.set(xform.origin, xform.zaxis, up)
    end

    def lookAt(target, stiff = 10.0, damp = 10.0)
      return unless $sketchyPhysicsToolInstance
      grp = $curEvalGroup
      xform = grp.transformation
      address = grp.get_attribute('SPOBJ', 'body', 0).to_i
      body = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
      # See if this already has a lookAtJoint
      jnt = grp.get_attribute('SPOBJ', '__lookAtJoint', nil)
      unless jnt
        # Create gyro and attach to the body.
        limits = [0, 0, stiff, damp]
        pinDir = xform.zaxis.to_a
        jnt = MSketchyPhysics3::NewtonServer.createJoint('gyro', xform.origin.to_a.pack('f*'), pinDir.pack('f*'), body, nil, limits.pack('f*'))
        # Make sure the body is unfrozen.
        MSketchyPhysics3::NewtonServer.setBodyMagnetic(body, 1)
        MSketchyPhysics3::NewtonServer.setBodyMagnetic(body, 0)
        grp.set_attribute('SPOBJ', '__lookAtJoint', jnt.to_i)
      end
      # Find target.
      if target.is_a?(Array)
        pinDir = xform.origin.vector_to(target).to_a
      else
        # Calc vector to target.
        targetgrp = $sketchyPhysicsToolInstance.findGroupNamed(target)
        return unless targetgrp
        pinDir = xform.origin.vector_to(targetgrp.transformation.origin).to_a
      end
      # Set pin dir to vector.
      address = grp.get_attribute('SPOBJ', '__lookAtJoint', 0).to_i
      ptr_data = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) :  FFI::Pointer.new(address)
      MSketchyPhysics3::NewtonServer.setGyroPinDir( ptr_data, pinDir.pack('f*') )
    end

    def every(count)
      @frame % count
    end

    def copy(pos = nil, kick = nil, lifetime = 0)
      return unless $sketchyPhysicsToolInstance
      pos = Geom::Transformation.new(pos) unless pos
      grp = $sketchyPhysicsToolInstance.copyBody($curEvalGroup, pos, lifetime)
      $sketchyPhysicsToolInstance.pushBody(grp, kick) if kick
      grp
    end

    def push(kick = nil)
      return unless $sketchyPhysicsToolInstance
      $sketchyPhysicsToolInstance.pushBody($curEvalGroup, kick) if kick
    end

    def showConfigDialog
      prompts = %w(leftx lefty rightx righty)
      values = %w(lX lY lRx lRy)
      res = inputbox(prompts, values, ['lX|lY|lRx|lRy'], 'Input configuration.')
      return unless res
      # enabled, density, linearViscosity, angularViscosity, current[0], current[1], current[2] = res
    end

    def getBinding(frame)
      @frame = frame
      @joystate = MSketchyPhysics3::JoyInput.state

      # Axis range from -1000 to 1000.
      # Scale from 0.0 to 1.0.
      if RUBY_VERSION =~ /1.8/
        leftx  = @joystate.lX / 2000.0 + 0.5
        lefty  = @joystate.lY / 2000.0 + 0.5
        rightx = @joystate.lRx / 2000.0 + 0.5
        righty = @joystate.lRy / 2000.0 + 0.5
        numx   = @joystate.lRz / 2000.0 + 0.5
        numy   = @joystate.lZ / 2000.0 + 0.5

        a = @joystate.rgbButtons[0]/-128 + key('numpad4')
        b = @joystate.rgbButtons[1]/-128 + key('numpad7')
        x = @joystate.rgbButtons[2]/-128 + key('numpad8')
        y = @joystate.rgbButtons[3]/-128 + key('numpad9')
      else
        leftx  = @joystate[:lX] / 2000.0 + 0.5
        lefty  = @joystate[:lY] / 2000.0 + 0.5
        rightx = @joystate[:lRx] / 2000.0 + 0.5
        righty = @joystate[:lRy] / 2000.0 + 0.5
        numx   = @joystate[:lRz] / 2000.0 + 0.5
        numy   = @joystate[:lZ] / 2000.0 + 0.5

        a = @joystate[:rgbButtons][0]/-128 + key('numpad4')
        b = @joystate[:rgbButtons][1]/-128 + key('numpad7')
        x = @joystate[:rgbButtons][2]/-128 + key('numpad8')
        y = @joystate[:rgbButtons][3]/-128 + key('numpad9')
      end
      # Keyboard emulation of joystick.
      # delta = 0.05
      leftx = 0.5 + (getKeyState(VK_D) ? 0.5 : 0.0) + (getKeyState(VK_A) ? -0.5 : 0.0) if leftx.between?(0.5-0.05, 0.5+0.05)
      lefty = 0.5 + (getKeyState(VK_S) ? 0.5 : 0.0) + (getKeyState(VK_W) ? -0.5 : 0.0) if lefty.between?(0.5-0.05, 0.5+0.05)
      rightx = 0.5 + (getKeyState(VK_RIGHT) ? 0.5 : 0.0) + (getKeyState(VK_LEFT) ? -0.5 : 0.0) if rightx.between?(0.5-0.05, 0.5+0.05)
      righty = 0.5 + (getKeyState(VK_DOWN) ? 0.5 : 0.0) + (getKeyState(VK_UP) ? -0.5 : 0.0) if righty.between?(0.5-0.05, 0.5+0.05)
      numx = 0.5 + (getKeyState(VK_NUMPAD3) ? 0.5 : 0.0) + (getKeyState(VK_NUMPAD1) ? -0.5 : 0.0) if numx.between?(0.5-0.05, 0.5+0.05)
      numy = 0.5 + (getKeyState(VK_NUMPAD2) ? 0.5 : 0.0) + (getKeyState(VK_NUMPAD5) ? -0.5 : 0.0) if numy.between?(0.5-0.05, 0.5+0.05)

      joyLX = leftx
      joyLY = lefty
      joyRX = numx
      joyRY = numy

      return binding

      state = MSketchyPhysics3::JoyInput.state

      if RUBY_VERSION =~ /1.8/
        # One of the triggers goes from 0 to 1000 the other 0 to -1000
        lt = state.lZ / 1000.0
        rt = state.lRz / -1000.0

        # Buttons are 0 when up and -128 when down (weird huh?)
        lb = state.rgbButtons[4]/-128
        rb = state.rgbButtons[5]/-128
        back = state.rgbButtons[6]/-128
        start = state.rgbButtons[7]/-128
        leftb = state.rgbButtons[8]/-128
        rightb = state.rgbButtons[9]/-128

        # dpad is weird
        dup = state.rgdwPOV[0]
        ddown = state.rgdwPOV[0]
        dleft = state.rgdwPOV[0]
        dright = state.rgdwPOV[0]
      else
        # One of the triggers goes from 0 to 1000 the other 0 to -1000
        lt = state[:lZ] / 1000.0
        rt = state[:lRz] / -1000.0

        # Buttons are 0 when up and -128 when down (weird huh?)
        lb = state[:rgbButtons][4]/-128
        rb = state[:rgbButtons][5]/-128
        back = state[:rgbButtons][6]/-128
        start = state[:rgbButtons][7]/-128
        leftb = state[:rgbButtons][8]/-128
        rightb = state[:rgbButtons][9]/-128

        # dpad is weird
        dup = state[:rgdwPOV][0]
        ddown = state[:rgdwPOV][0]
        dleft = state[:rgdwPOV][0]
        dright = state[:rgdwPOV][0]
      end
      return binding
    end

  end # class ControllerContext


  class SP3xSimulationContext

    def initialize(model)
      @uniqueID = getUniqueID

      @bodies = []
      @joints = []

      @listeners = {
        :start      => [],
        :end        => [],
        :tick       => [],
        :draw       => [],
        :pre_frame  => [],
        :post_frame => [],
        :touching   => [],
        :key        => [],
        :joy        => [],
        :timer      => [],
        :mouse      => []
      }

      @deferred_tasks = []
      @erase_on_end = []
      @unhide_on_end = []

      @simulation_events = {}
      # Lookups
      @group_to_body = {}
      @name_to_body = {}

      @frame_rate = model.get_attribute('SPSETTINGS', 'framerate')
      @gravity = model.get_attribute('SPSETTINGS', 'gravity')

      @sounds = SPSounds.new()

      @drawQueue = []
      @pointsQueue = []

      @log_ent = nil
      @log_lines = []
    end

    attr_reader :bodies, :joints, :frame_rate, :gravity, :frame, :drawQueue, :pointsQueue, :sounds
    attr_reader :simulation_events, :deferred_tasks, :unhide_on_end


    def draw(type, pts, color = 'Black', size = 1, stipple = '', style = 0)
      type = case type.to_s.downcase.to_sym
      when :line
        GL_LINE_STRIP
      when :loop
        GL_LINE_LOOP
      when :point
        GL_POINTS
      when :triangle
        GL_TRIANGLES
      when :quad
        GL_QUADS
      when :polygon
        GL_POLYGON
      else
        return
      end unless type.is_a?(Fixnum)
      @drawQueue << [type, pts, color, size, stipple, style]
    end

    # Draw with OpenGL.
    # @param [Fixnum, String, Symbol] type Drawing type. Valid types are <i>
    #   line, lines, line_strip, line_loop, triangle, triangles, triangle_strip,
    #   triangle_fan, quad, quads, quad_strip, convex_polygon, and polygon</i>.
    # @param [Array<Array[Numeric]>, Array<Geom::Point3d>] points An array of
    #   points.
    # @param [Array, String, Sketchup::Color] color
    # @param [Fixnum] width Width of a line in pixels.
    # @param [String] stipple Line stipple: '.' (Dotted Line), '-' (Short Dashes
    #   Line), '_' (Long Dashes Line), '-.-' (Dash Dot Dash Line), '' (Solid
    #   Line).
    # @param [Boolean] mode Drawing mode: +0+ : 2d, +1+ : 3d.
    def drawExt(type, points, color = 'black', width = 1, stipple = '', mode = 1)
      raise ArgumentError, 'Expected an array of points.' unless points.is_a?(Array) or points.is_a?(Geom::Point3d)
      points = [points] if points[0].is_a?(Numeric)
      s = points.size
      raise 'Not enough points: At least one required!' if s == 0
      type = case type.to_s.downcase.strip.gsub(/\s/i, '_').to_sym
      when :point, :points
        GL_POINTS
      when :line, :lines
        raise 'A pair of points is required for each line!' if (s % 2) != 0
        GL_LINES
      when :line_strip, :strip
        raise 'Not enough points: At least two required!' if s < 2
        GL_LINE_STRIP
      when :line_loop, :loop
        raise 'Not enough points: At least two required!' if s < 2
        GL_LINE_LOOP
      when :triangle, :triangles
        raise 'Not enough points: At least three required!' if s < 3
        GL_TRIANGLES
      when :triangle_strip
        raise 'Not enough points: At least three required!' if s < 3
        GL_TRIANGLE_STRIP
      when :triangle_fan
        raise 'Not enough points: At least three required!' if s < 3
        GL_TRIANGLE_FAN
      when :quad, :quads
        raise 'Not enough points: At least four required!' if s < 4
        GL_QUADS
      when :quad_strip
        raise 'Not enough points: At least four required!' if s < 4
        GL_QUAD_STRIP
      when :convex_polygon, :polygon
        raise 'Not enough points: At least three required!' if s < 3
        GL_POLYGON
      else
        raise ArgumentError, 'Invalid type.'
      end unless type.is_a?(Fixnum)
      @drawQueue << [type, points, color, width, stipple, mode.to_i]
    end

    def draw2D(type, pts, color = 'Black', size = 1, stipple='')
      draw(type, pts, color, size, stipple, 0)
    end

    def draw3D(type, pts, color = 'Black', size = 1, stipple='')
      draw(type, pts, color, size, stipple, 1)
    end

    # Draw 3d points with style.
    # @param [Array<Geom::Point3d>] points An array of points.
    # @param [Fixnum] size Size of the point in pixels.
    # @param [Fixnum] style Styles: 0 - none, 1 - open square, 2 - filled
    #   square, 3 - "+", 4 - "X", 5 - "*", 6 - open triangle, 7 - filled
    #   triangle.
    # @param [Array, Sketchup::Color, String] color
    # @param [Fixnum] width Width of a line in pixels.
    # @param [String] stipple Line stipple: '.' (Dotted Line), '-' (Short Dashes
    #   Line), '_' (Long Dashes Line), '-.-' (Dash Dot Dash Line), '' (Solid
    #   Line).
    def drawPoints(points, size = 1, style = 0, color = 'black', width = 1, stipple = '')
      raise ArgumentError, 'Expected an array of points.' unless points.is_a?(Array) or points.is_a?(Geom::Point3d)
      points = [points] if points[0].is_a?(Numeric)
      raise 'Not enough points: At least one required!' if points.empty?
      @pointsQueue << [points, size, style, color, width, stipple]
    end

    def emptyDrawQueue
      @drawQueue.clear
      @pointsQueue.clear
    end

    def logLine(str)
      unless @log_ent
        # Add blank text to screen at 10,50
        @log_ent = SketchyPhysics.addWatermarkText(10, 120, '')
        if @log_ent.material
          @log_ent.material.color = [120,80,200]
        end
      end
      @log_lines << str
      # Ensure only 10 lines on screen at once.
      @log_lines.shift if @log_lines.length > 10
      # Display lines
      @log_ent.text = @log_lines.join("\n")
    end

    # Signals

    def doOnStart
      @listeners[:start].each { |body| body.doOnStart }
      true
    end

    def doOnEnd
      @sounds.stopAll
      error = nil
      begin
        @listeners[:end].each { |body| body.doOnEnd }
      rescue Exception => e
        # Wait till the end, and then raise error.
        error = e
      end
      @erase_on_end.each { |e| e.erase! if e.valid? }
      @erase_on_end.clear
      @unhide_on_end.each { |e| e.visible = true if e.valid? }
      @unhide_on_end.clear
      if @log_ent
        mat = @log_ent.material
        @log_ent.material = nil
        mats = Sketchup.active_model.materials
        mats.remove(mat) if mats.respond_to?(:remove)
        @log_ent.erase! if @log_ent.valid?
        @log_ent = nil
        @log_lines.clear
      end
      # Make sure mouse is visible.
      MSketchyPhysics3.hideCursor(false)
      # Clear variables
      @listeners.clear
      @bodies.clear
      @joints.clear
      @deferred_tasks.clear
      @simulation_events.clear
      @group_to_body.clear
      @name_to_body.clear
      @sounds = nil
      @drawQueue.clear
      @pointsQueue.clear
      # Now raise the error if there was onEnd error.
      raise error if error
    end

    def doOnTick(frame = 0)
      @frame = frame
      @listeners[:tick].each { |body| body.doOnTick }
      true
    end

    def doOnDraw(view, bb)
      @listeners[:draw].each { |body| body.doOnDraw(view, bb) }
      true
    end

    def doOnKey
      @listeners[:key].each { |body| body.doOnKey }
      true
    end

    def doOnMouse(type, ent, x, y)
      @listeners[:mouse].each { |body|
        if body.group == ent
          body.doMouse(type, x, y)
          return true
        end
      }
      false
    end

    # Called whenever two bodies collide.
    def doTouching(grp, touching_grp, force, pos)
      body = findBody(grp)
      return false unless body
      touching_body = findBody(touching_grp)
      return false unless touching_body
      body.handleTouching(touching_body, force, pos) if body.touchable
      true
    end

    def doPreFrame
      emptyDrawQueue
      @listeners[:pre_frame].each { |body| body.doOnPreFrame }
    end

    def doPostFrame
      @deferred_tasks.each { |task| task.call }
      @deferred_tasks.clear
      # This is needed for the untouch AND touch to work.
      @listeners[:touching].each { |body| body.handleUntouching }
      @listeners[:post_frame].each { |body| body.doOnPostFrame }
      true
    end

    # Temp helper function
    def uniq_push(array, value)
      array.push(value) if !array.include?(value)
    end

    def unsubscribeAll(receiver)
      @listeners.keys.each { |evt|
        evt.delete(receiver)
      }
      @simulation_events.values.each { |events|
        events.each { |event|
          events.delete(receiver) if event[0] == receiver
        }
      }
    end

    def subscribeOn(receiver, name, block)
      @simulation_events[name] = [] unless @simulation_events[name]
      @simulation_events[name] << [receiver, block]
    end

    def signal(name, msg = nil)
      return unless @simulation_events[name]
      @simulation_events[name].each { |event|
        event[1].call(msg)
      }
    end

    def subscribeToEvent(name, receiver)
      case name.to_s.downcase.to_sym
      when :onstart
        uniq_push(@listeners[:start], receiver)
      when :onend
        uniq_push(@listeners[:end], receiver)
      when :ontouching, :ontouch, :onuntouching
        uniq_push(@listeners[:touching], receiver)
      when :ontick
        uniq_push(@listeners[:tick], receiver)
      when :ondraw
        uniq_push(@listeners[:draw], receiver)
      when :onkey
        uniq_push(@listeners[:onkey], receiver)
      when :onjoy
        uniq_push(@listeners[:onjoy], receiver)
      when :mouse
        uniq_push(@listeners[:mouse], receiver)
      when :onpreframe
        uniq_push(@listeners[:pre_frame], receiver)
      when :onpostframe
        uniq_push(@listeners[:post_frame], receiver)
      end
    end

    def findBody(grp)
      grp.is_a?(String) ? @name_to_body[grp] : @group_to_body[grp.to_s]
    end

    def createJoint(parent, child, type = 'ball', min = 0, max = 0, accel = 0, damp = 0, breaking_force = 0)
      jnt = SP3xJointContext.new(parent, child, type, min, max, accel, damp, breaking_force)
      @joints << jnt
      jnt
    end

    def createBody(grp, body_ptr)
      body = SP3xBodyContext.new(self, grp, body_ptr)
      @bodies << body
      @group_to_body[grp.to_s] = body
      @name_to_body[grp.name] = body unless grp.name.empty?
      body
    end

    def destroyBody(body)
      body.destroy
    end

    def connect(parent, child, type = 'ball', min = 0, max = 0, accel = 0, damp = 0, breaking_force = 0)
      createJoint(parent, child, type, min, max, accel, damp, breaking_force)
    end

    def view
      Sketchup.active_model.active_view
    end

    def camera
      Sketchup.active_model.active_view.camera
    end

    def getUniqueID
      @uniqueID = -1 unless @uniqueID
      @uniqueID += 1
      @uniqueID
    end

    def evalCurveAbs(name, dist)
      curveVerts = findCurve(name.to_s)
      return [0,0,0] unless curveVerts
      #puts("Count:"+curve.vertices.length.to_s)
      #puts ["length",calcPathLength(curveVerts)]
      curLen = 0.0
      lastVert = curveVerts[0]
      curveVerts.each { |v|
        len = v.distance(lastVert)
        if len+curLen > dist
          # puts "found edge: #{v.position.to_a.inspect}"
          r = dist - curLen
          # percent = r / len
          # return [lastVert, v, percent]
          rv = lastVert.vector_to(v)
          rv.length = r
          return Geom::Point3d.new(lastVert) + rv
        end
        lastVert = v
        curLen += len
      }
      # At this point we must be off end of curve.
      # return [lastVert, lastVert, 1.0]
      lastVert
    end

    def createCurve(curve)
      verts = curve.vertices.collect { |v| v.position.to_a }
      #len = calcPathLength(verts)
      return verts
    end

    def getCurveLength(curveVerts)
      len = 0
      lastVert = curveVerts[0]
      curveVerts.each { |v|
        len += v.distance(lastVert)
        lastVert = v
      }
      return len
    end

    def loadCurves
      @allCurves = {}
      Sketchup.active_model.entities.each { |ent|
        if ent.is_a?(Sketchup::Edge) && ent.curve != nil
          name = ent.curve.get_attribute('SPCURVE', 'name', nil)
          if name != nil && @allCurves[name].nil?
            @allCurves[name] = createCurve(ent.curve)
          end
        end
      }
    end

    def findCurve(name)
      loadCurves unless @allCurves
      @allCurves[name]
    end

    def _setEvent(name, script)
      eval("@#{name}=lambda{"+script+"}")
    end

    def setFrameRate(rate)
      $sketchyPhysicsToolInstance.setFrameRate(rate)
      @frame_rate = rate
    end

  end # class SP3xSimulationContext


  class SP3xJointContext

    attr_accessor :name, :type
    attr_reader :_jointPTR
    attr_reader :min, :max, :accel, :damp, :breakingForce
    attr_reader :desiredPosition, :desiredRotation
    attr_accessor :parent, :child

    def min=(v)
    end

    def setMin(v)
    end

    def controllerValue=(value)
      return unless value.is_a?(Numeric)
      joint_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(@_jointPTR) : FFI::Pointer.new(@_jointPTR.to_i)
      case type
      when 'servo'
        MSketchyPhysics3::NewtonServer.setJointRotation(joint_ptr, [value].pack('f*'))
      when 'piston'
        MSketchyPhysics3::NewtonServer.setJointPosition(joint_ptr, [value].pack('f*'))
      when 'motor'
        MSketchyPhysics3::NewtonServer.setJointAccel(joint_ptr, [value].pack('f*'))
      when 'gyro'
        return unless value.is_a?(Array)
        MSketchyPhysics3::NewtonServer.setGyroPinDir(joint_ptr, value.pack('f*'))
      end
    end

    def disconnect
      # Defer the disconnect till end of frame.
      # Disconnect can cause crash if called in ontouch.
      @simulation.deferred_tasks << lambda{ self.disconnectNow }
    end

    def disconnectNow
      return if (!@connected || @_jointPTR == 0)
      joint_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(@_jointPTR) : FFI::Pointer.new(@_jointPTR.to_i)
      MSketchyPhysics3::NewtonServer.destroyJoint(joint_ptr)
      @child.joints.delete(self)
      @parent.joints.delete(self)
      @connected = false
    end

    def setDesiredTransformation(xform)
      # return if @type != 'desired'
      joint_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(@_jointPTR) : FFI::Pointer.new(@_jointPTR.to_i)
      MSketchyPhysics3::NewtonServer.setDesiredMatrix(joint_ptr, xform.to_a.pack('f*'))
      # extern "void setDesiredParams(DesiredJoint*, float*)"
    end

    def initialize(parent, child, type = 'ball', min = 0, max = 0, accel = 0, damp = 0, breakingForce = 0)
      if parent
        parentBody = parent._bodyPTR
        xform = parent.group.transformation
      else
        parentBody = nil
        # xform = child.group.transformation
        xform = Geom::Transformation.new
      end
      pinDir = xform.zaxis.to_a + xform.yaxis.to_a

      childBody = child._bodyPTR
      limits = [min, max, accel, damp, 0, 0, breakingForce]
      pos = xform.origin.to_a
      # pos = [0,0,0]
      jnt =  MSketchyPhysics3::NewtonServer.createJoint(type, pos.pack('f*'), pinDir.pack('f*'), childBody, parentBody, limits.pack('f*'))
      # ToDo. fix joints that return 0.
      # if(jnt!=0)
        @simulation = child.simulation
        @_jointPTR = jnt.to_i
        @connected = true
        @child = child
        @parent = parent
        @type = type
        parent.joints << self if parent
        child.joints << self
      # end
    end

  end # class SP3xJointContext


  class SP3xBodyContext < SP3xCommonContext

    def initialize(sim, grp, bodyPTR)
      @simulation = sim
      @group = grp
      @_bodyPTR = bodyPTR
      @name = grp.name
      @joints = []
      @uniqueID = @simulation.getUniqueID
      @dragable = true
      @valid = true

      #_setEvent(:ontouch, "puts @name+' touched'")
      #_setEvent(:ontouching, "puts @name+' touching'")
      #_setEvent(:onuntouch, "puts @name+' untouched'")
      #_setEvent(:ontick, "puts @name+' ticked'")
      #_setEvent(:onstart, "puts @name+' start'")
      #_setEvent(:onend, "puts @name+' end'")
      #eval("setEvent(:onend){ puts group; puts 321 }")

      initEvents(grp)

      if grp.attribute_dictionary('SPEvents')
        grp.attribute_dictionary('SPEvents').each { |k,v|
          _setEvent(k,v)
        }
      end
    end

    # Properties
    attr_accessor :name, :joints, :valid
    attr_reader :_bodyPTR

    # Automatic set prop
    attr_reader :touchable
    attr_accessor :dragable

    # Used to calc touch and untouch.
    attr_reader :touchingBodies, :touchingBodiesLastFrame

    def frame
      @simulation.frame
    end

    def moveTo(pos, accel, damp)
    end

    def group
      @group
    end

    def simulation
      @simulation
    end

    def sp_tool
      MSketchyPhysics3::SketchyPhysicsClient
    end

    def sp_tool_instance
      $sketchyPhysicsToolInstance
    end

    def camera
      Sketchup.active_model.active_view.camera
    end

    def magnetic=(v)
      return unless @_bodyPTR
      @simulation.deferred_tasks.push(lambda{
        MSketchyPhysics3::NewtonServer.setBodyMagnetic(@_bodyPTR, v ? 1 : 0)
      })
    end

    def teleport(pos, recurse = true)
      deferedVelocity=getVelocity()
      deferedTorque=getTorque()
      @simulation.deferred_tasks.push(lambda{
        setVelocity(deferedVelocity)
        setTorque(deferedTorque)
      })
      # Convert to c bool.
      recurse = recurse ? 1 : 0
      if pos.is_a?(Geom::Transformation)
        MSketchyPhysics3::NewtonServer.setMatrix(@_bodyPTR, pos.to_a.pack('f*'), recurse)
      else
        MSketchyPhysics3::NewtonServer.setMatrix(@_bodyPTR, Geom::Transformation.new(pos).to_a.pack('f*'), recurse)
      end
    end

    def push(kick = nil)
      $sketchyPhysicsToolInstance.pushBody(@group, kick) if kick
    end

    def nocollision=(v)
      return unless @_bodyPTR
      MSketchyPhysics3::NewtonServer.setBodySolid(@_bodyPTR, v ? 0 : 1)
    end

    def solid=(v)
      self.nocollision = !v
    end

    def static=(v)
    end

    def destroy
      return unless @valid
      body_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(@_bodyPTR) : FFI::Pointer.new(@_bodyPTR.to_i)
      MSketchyPhysics3::NewtonServer.destroyBody(body_ptr)
      @group.hidden = true
      @valid = false
      @simulation.unhide_on_end << @group
    end

    def copy(pos = nil, lifetime = 0)
      return unless @group
      pos = Geom::Transformation.new(pos) if pos
      grp = $sketchyPhysicsToolInstance.copyBody(@group, pos, lifetime)
      simulation.findBody(grp)
    end

    def position
      @group.transformation.origin
    end

    def transformation
      @group.transformation
    end

    # @return [Geom::Vector3d]
    def getVelocity
      if RUBY_VERSION =~ /1.8/
        velocity = (0.chr*12).to_ptr
        MSketchyPhysics3::NewtonServer.bodyGetVelocity(@_bodyPTR, velocity)
        Geom::Vector3d.new(velocity.to_a("F3"))
      else
        velocity = 0.chr*12
        MSketchyPhysics3::NewtonServer.bodyGetVelocity(@_bodyPTR, velocity)
        Geom::Vector3d.new(velocity.unpack('F*'))
      end
    end

    # @param [Geom::Vector3d, Array<Numeric>] velocity
    def setVelocity(velocity)
      MSketchyPhysics3::NewtonServer.bodySetVelocity(@_bodyPTR, velocity.to_a.pack('f*'))
    end

    # Set the drag force applied to the body.
    # @param [Numeric] damp
    def setLinearDamping(damp)
      MSketchyPhysics3::NewtonServer.bodySetLinearDamping(@_bodyPTR, damp.to_f)
    end

    # Se angular drag applied to the body.
    # @param [Geom::Vector3d, Array<Numeric>] damp
    def setAngularDamping(damp)
      MSketchyPhysics3::NewtonServer.bodySetAngularDamping(@_bodyPTR, damp.to_a.pack('f*'))
    end

    # @return [Geom::Vector3d]
    def getTorque
      if RUBY_VERSION =~ /1.8/
        torque = (0.chr*12).to_ptr
        MSketchyPhysics3::NewtonServer.bodyGetTorque(@_bodyPTR, torque)
        Geom::Vector3d.new(torque.to_a("F3"))
      else
        torque = 0.chr*12
        MSketchyPhysics3::NewtonServer.bodyGetTorque(@_bodyPTR, torque)
        Geom::Vector3d.new(torque.unpack('F*'))
      end
    end

    # @param [Geom::Vector3d, Array<Numeric>] torque
    def setTorque(torque)
      MSketchyPhysics3::NewtonServer.bodySetTorque(@_bodyPTR, torque.to_a.pack('f*'))
    end

    def attach(child, breaking_force = 0)
      connect(child, 'fixed', 0, 0, 0, 0, breaking_force)
    end

    def split(bdy=self,recurse=0)
      @simulation.deferred_tasks.push(lambda{
        _splitNow(bdy, recurse)
      })
    end

    def _splitNow(bdy = self, recurse = 0)
      a, b = bdy.breakit(bdy.group)
      bdy.group.hidden = true
      @simulation.unhide_on_end << @group
      bdy.solid = false
      bdy.static = false # fix this.
      bdy.touchable = false
      @simulation.unsubscribeAll(bdy)
      $sketchyPhysicsToolInstance.newBody(a)
      $sketchyPhysicsToolInstance.newBody(b)
      ba = @simulation.findBody(a)
      ba.setVelocity(bdy.getVelocity)
      ba.setTorque(bdy.getTorque)
      bb = @simulation.findBody(b)
      bb.setVelocity(bdy.getVelocity)
      bb.setTorque(bdy.getTorque)
      ret = []
      if recurse > 0
        ret += split(ba, recurse-1)
        ret += split(bb, recurse-1)
      else
        ret = [ba, bb]
      end
      ret
    end

    def setDesired
      @simulation.createJoint(self, self)
    end

    def connect(child, type = 'ball', min = 0, max = 0, accel = 0, damp = 0, breaking_force = 0)
      @simulation.createJoint(self, child, type, min, max, accel, damp, breaking_force)
    end

    def handleTouching(toucher, force, pos)
      # Return if already processed this collision.
      return if @touchingBodies.include?(toucher)
      if (@ontouchFunc != nil || @ontouchingFunc != nil)
        if (@ontouchFunc != nil && !@touchingBodiesLastFrame.include?(toucher))
          @ontouchFunc.call(toucher, force, pos)
          # puts @touchingBodiesLastFrame.length
        end
        @touchingBodies << toucher
      end
      @ontouchingFunc.call(toucher) if @ontouchingFunc
    end

    def handleUntouching
      uc = 0
      if @onuntouchFunc
        untouched = @touchingBodiesLastFrame - @touchingBodies
        # Insure only one call per object.
        # Should not be needed, but safer during development.
        untouched.uniq!
        if untouched.size > 0
          uc += 1
          # puts "untouching #{untouched.size}"
        end
        untouched.each { |toucher|
          @onuntouchFunc.call(toucher)
        }
      end
      # puts [@touchingBodiesLastFrame.size, @touchingBodies.size, uc].inspect
      @touchingBodiesLastFrame = @touchingBodies
      @touchingBodies = []
    end

    def _getBinding
      binding
    end

    # Needs to be private. do not use public. unexpected results.
    def touchable=(flag)
      @touchable = flag
      return unless flag
      @simulation.subscribeToEvent(:ontouching, self)
      @touchingBodies = []
      @touchingBodiesLastFrame = []
      MSketchyPhysics3::NewtonServer.bodySetMaterial(@_bodyPTR, 1)
      MSketchyPhysics3::NewtonServer.setBodyCollideCallback(@_bodyPTR, MSketchyPhysics3::NewtonServer::COLLIDE_CALLBACK)
    end

    def ontouching(&_block)
      eval("@ontouchingFunc=_block")
      self.touchable=true
    end

    alias onTouching ontouching

    def onuntouch(&_block)
      eval("@onuntouchFunc=_block")
      self.touchable = true
    end

    alias onUntouch onuntouch

    def ontouch(&_block)
      eval("@ontouchFunc=_block")
      self.touchable = true
    end

    alias onTouch ontouch

    def onstart(&_block)
      eval("@onstartFunc=_block")
      @simulation.subscribeToEvent(:onstart, self)
    end

    alias onStart onstart

    def onend(&_block)
      eval("@onendFunc=_block")
      @simulation.subscribeToEvent(:onend, self)
    end

    alias onEnd onend

    def ontick(&_block)
      eval("@ontickFunc=_block")
      @simulation.subscribeToEvent(:ontick, self)
    end

    alias onTick ontick
    alias onupdate ontick
    alias onUpdate ontick

    def ondraw(&_block)
      eval("@ondrawFunc=_block")
      @simulation.subscribeToEvent(:ondraw, self)
    end

    alias onDraw ondraw

    def onpreframe(&_block)
      eval("@onpreframeFunc=_block")
      @simulation.subscribeToEvent(:onpreframe, self)
    end

    alias onPreFrame onpreframe
    alias onpreupdate onpreframe
    alias onPreUpdate onpreframe

    def onpostframe(&_block)
      eval("@onpostframeFunc=_block")
      @simulation.subscribeToEvent(:onpostframe, self)
    end

    alias onPostFrame onpostframe
    alias onpostupdate onpostframe
    alias onPostUpdate onpostframe

    def onclick(&_block)
      eval("@onclickFunc=_block")
      @simulation.subscribeToEvent(:mouse, self)
    end

    alias onClick onclick

    def onunclick(&_block)#event#
      eval("@onunclickFunc=_block")
      @simulation.subscribeToEvent(:mouse, self)
    end

    alias onUnclick onunclick

    def ondoubleclick(&_block)#event#
      eval("@ondoubleclickFunc=_block")
      @simulation.subscribeToEvent(:mouse, self)
    end

    alias onDoubleClick ondoubleclick

    def ondrag(&_block)#event#
      eval("@ondragFunc=_block")
      @simulation.subscribeToEvent(:mouse, self)
    end

    alias onDrag ondrag

    def on(name, &block)
      @simulation.subscribeOn(self, name, block)
    end

    def signal(name, msg = nil)
      @simulation.signal(name, msg)
    end

    def doOnStart
      @onstartFunc.call if @onstartFunc
    end

    def doOnClick
      @onclickFunc.call if @onclickFunc
    end

    def doOnDrag
      @ondragFunc.call if @ondragFunc
    end

    def doOnUnClick
      @onunclickFunc.call if @onunclickFunc
    end

    def doOnEnd
      @onendFunc.call if @onendFunc
    end

    def doOnTick
      @ontickFunc.call if @ontickFunc
    end

    def doOnDraw(view, bb)
      @ondrawFunc.call(view, bb) if @ondrawFunc
    end

    def doOnKey
      @onkeyFunc.call if @onkeyFunc
    end

    def doOnPreFrame
      @onpreframeFunc.call if @onpreframeFunc
    end

    def doOnPostFrame
      @onpostframeFunc.call if @onpostframeFunc
    end

    def doMouse(type, x, y)
      case type
      when :click
        @onclickFunc.call(x,y) if @onclickFunc
      when :drag
        @ondragFunc.call(x,y) if @ondragFunc
      when :unclick
        @onunclickFunc.call(x,y) if @onunclickFunc
      when :doubleclick
        @ondoubleclickFunc.call(x,y) if @ondoubleclickFunc
      end
    end

    def getCursorPosition
      MSketchyPhysics3.getCursor
    end

    def setCursorPosition(x,y)
      MSketchyPhysics3.setCursor(x,y)
    end

    def showCursor(bool)
      MSketchyPhysics3.hideCursor(!bool)
    end

    def setEvent(event, &block)
      event = event.to_s.downcase
      eval("@#{event}Func=block")
      @simulation.subscribeToEvent(event, self)
      case event
      when 'ontouching', 'ontouch', 'onuntouching'
        self.touchable = true
      end
    end

    def _setEvent(event, script)
      event = event.to_s.downcase
      eval("@#{event}Func=lambda{"+script+"}")
      @simulation.subscribeToEvent(event, self)
      case event
      when 'ontouching', 'ontouch', 'onuntouching'
        self.touchable = true
      end
    end

    def initEvents(events_grp)
      if (events_grp.get_attribute('SPOBJ', 'scripted', false) &&
        events_grp.get_attribute('SPOBJ', 'script', nil) != nil)
        eval(events_grp.get_attribute('SPOBJ', 'script').to_s)
      end
    rescue Exception => e
      i = Sketchup.active_model.entities.to_a.index(events_grp)
      raise "An error occurred while assigning script to entity [#{i}]:\n#{e}"
    end

    def logLine(str)
      @simulation.logLine(str)
    end

    def __log(str)
      @simulation.deferred_tasks.push(lambda{
        MSketchyPhysics3.logPhysicsMessage(str)
      })
    end

    def delete_ents_behind_plane(ents, t1, plane)
      # ents = get_entities(first)
      to_delete = []
      ents.each { |e|
        if e.is_a?(Sketchup::Face) && e.valid?
          mesh = e.mesh
          mesh.transform!(t1) # transform face to global coordinates
          p1 = mesh.point_at(1)
          p2 = mesh.point_at(2)
          p3 = mesh.point_at(3)
          cent = [(p1.x+p2.x+p3.x)/3.0, (p1.y+p2.y+p3.y)/3.0, (p1.z+p2.z+p3.z)/3.0]
          result = plane[0]*cent.x+plane[1]*cent.y+plane[2]*cent.z+plane[3]
          to_delete.push(e) if result < 0.0
        elsif e.is_a?(Sketchup::Edge) && e.valid?
          p1 = e.start.position.transform(t1)
          p2 = e.end.position.transform(t1)
          cent = [(p1.x+p2.x)/2.0, (p1.y+p2.y)/2.0, (p1.z+p2.z)/2.0]
          result = plane[0]*cent.x+plane[1]*cent.y+plane[2]*cent.z+plane[3]
          to_delete << e if result < 0.0 and cent.distance_to_plane(plane) > 0.001
          # to_delete << e if cent.distance_to_plane(plane) > 0.1
        end
      }
      ents.erase_entities(to_delete) # delete entities behind the plane
    end

    def breakit(grp)
      model = Sketchup.active_model
      ents = model.entities
      # model.active_entities.add_group(model.selection)
      cutGroup = model.active_entities.add_group
      xlate = Geom::Transformation.new(grp.bounds.center)
      rot = xlate*Geom::Transformation.rotation([0,0,0], [rand-0.5,rand-0.5,rand-0.5], (rand-0.5)*10.0)
      f = cutGroup.entities.add_face(
        [-1000,-1000,0].transform!(rot),
        [1000,-1000,0].transform!(rot),
        [1000,1000,0].transform!(rot),
        [-1000,1000,0].transform!(rot))
      # xform = Geom::Transformation.rotation(grp.transformation.origin, [rand-0.5,rand-0.5,rand-0.5], (rand-0.5)*10.0)
      # xform = xform*Geom::Transformation.new(grp.bounds.center)
      # cutGroup.transform!(xform)

      agrp = ents.add_instance(MSketchyPhysics3.get_definition(grp), grp.transformation)
      agrp = agrp.make_unique
      agrp.set_attribute('SPOBJ', 'shape', 'convexhull')
      edges = agrp.definition.entities.intersect_with(false, agrp.transformation, agrp.definition.entities, agrp.transformation, false, [cutGroup])
      delete_ents_behind_plane(agrp.definition.entities, agrp.transformation, f.plane)
      edges.each { |e| e.find_faces if e.valid? }

      bgrp = ents.add_instance(MSketchyPhysics3.get_definition(grp), grp.transformation)
      bgrp.make_unique
      bgrp.set_attribute('SPOBJ', 'shape', 'convexhull')
      pl = f.plane
      pl[0] *= -1.0
      pl[1] *= -1.0
      pl[2] *= -1.0
      pl[3] *= -1.0
      edges = bgrp.definition.entities.intersect_with(false, bgrp.transformation, bgrp.definition.entities, agrp.transformation, false, [cutGroup])
      delete_ents_behind_plane(bgrp.definition.entities, agrp.transformation, pl)
      edges.each { |e| e.find_faces if e.valid? }

      #grp.hidden = true
      cutGroup.erase!

      return agrp, bgrp
    end

  end # SP3xBodyContext


  class SP3xControllerContext < ControllerContext

    def position
      if $sketchyPhysicsToolInstance
        $curEvalGroup.transformation.origin.to_a
      else
        [0,0,0]
      end
    end

    def setAnimation(name, frame)
      return if  $sketchyPhysicsToolInstance.nil? || $curEvalGroup.nil?
      for ent in MSketchyPhysics3.get_definition($curEvalGroup).entities
        state = (MSketchyPhysics3.get_definition(ent).name == name+("%02d"%frame))
        ent.hidden = state
      end
    end

    def touching
      $curEvalTouchingGroup
    end

    def this
      $curEvalGroup
    end

    def attach(child, breaking_force = 0)
      connect(child, 'fixed', 0, 0, 0, 0, breaking_force)
    end

    def setMagnetic(v, grp = $curEvalGroup)
      return if $sketchyPhysicsToolInstance.nil? || $curEvalGroup.nil?
      address = grp.get_attribute('SPOBJ', 'body', 0).to_i
      body_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
      MSketchyPhysics3::NewtonServer.setBodyMagnetic(body_ptr, v ? 1 : 0)
    end

    def connect(child, type = 'ball', min = 0, max = 0, accel = 0, damp = 0, breaking_force = 0)
      return unless $sketchyPhysicsToolInstance
      parent = $curEvalGroup
      xform = parent.transformation
      pin_dir = xform.zaxis.to_a + xform.yaxis.to_a
      parent_address = parent.get_attribute('SPOBJ', 'body', 0).to_i
      child_address = child.get_attribute('SPOBJ', 'body', 0).to_i
      parent_body_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(parent_address) : FFI::Pointer.new(parent_address)
      child_body_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(child_address) : FFI::Pointer.new(child_address)
      limits = [min, max, accel, damp, 0, 0, breaking_force]
      MSketchyPhysics3::NewtonServer.createJoint(type.to_s, xform.origin.to_a.pack('f*'), pin_dir.pack('f*'), child_body_ptr, parent_body_ptr, limits.pack('f*'))
    end

  end # SP3xControllerContext
end # module MSketchyPhysics 3
