require 'sketchup.rb'

module SketchyReplay

class SKPViewer

    def initialize(dlg)
        @dlg = dlg
    end

    def onViewChanged(v)
        puts v.camera.eye
        puts v.camera.target
        puts @dlg
    end

end # class SKPViewer


class << self

def exportit
    model = Sketchup.active_model
    model.definitions.each { |d|
        if d.instances.length > 0
            model.start_operation('temp')
            model.entities.add_instance(d, Geom::Transformation.new)
            elist = model.entities.to_a
            model.entities.erase_entities(elist)
            model.abort_operation
        end
    }
end

def showit
    dir = File.dirname(__FILE__)
    wdir = File.join(dir, 'o3d')
    fname = File.join(wdir, 'temp.kmz')
    # Note weird ending. Needed to make it work on win.
    outdir = wdir + '/temp\\'
    outname = rand(0xffffffff).to_s + 'temp.tgz'

    Sketchup.active_model.export(fname, false)
    system('del "'+outdir+'*.tgz" ')
    system(wdir+'/converter/o3dconverter.exe "'+fname+'" "'+outdir+outname+'"')

    dlg = UI::WebDialog.new('SPKViewer', true, 'asdfa2342', 739, 641, 640, 480, true)
    dlg.set_file(wdir+'/simpleviewer.html?fname='+outname)
    dlg.set_file(wdir+'/SKPViewer/viewer.html?fname='+outname)
    puts wdir
    dlg.show
    #Sketchup.active_model.active_view.add_observer(SKPViewer.new(dlg))
    dlg
end

def fakeExport
    # Get animation accessors
    sr = SketchyReplay::SketchyReplay.new
    # Check for animation in the file
    return if sr.lastFrame == 0
    # Set objects pos and camera for first frame.
    sr.start
    # Export first frame here
    0.upto(sr.lastFrame){
        # Advance object and camera positions
        sr.nextFrame
        puts sr.frame
        # Export frame here:
    }
    # Cleanup
    sr.rewind
end

end # proxy class


#~ class Array #Array to Hash. Nice! found on codesnipets.com
  #~ def to_h(&block)
    #~ Hash[*self.collect { |v|
      #~ [v, block.call(v)]
    #~ }.flatten]
  #~ end
#~ end


class SketchyReplay

    attr_reader :frame
    attr_reader :lastFrame

    def initialize
        @frame = 0
        @lastFrame = 0
        @bPaused = false
        @bStopped = true
        @started = false
        @animationObjectList = {}
        @transformations = {}
        @animationRate = 1
        @cameraParent = nil
        @cameraTarget = nil
        @cameraType = nil # type=fixed,relative,drag
    end

    def findAnimationObjects
        @animationObjectList.clear
        @lastFrame = 0
        Sketchup.active_model.entities.each { |ent|
            next unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
            attr = ent.get_attribute('SPTAKE', 'samples', nil)
            next unless attr
            begin
                samps = eval(attr)
            rescue
                ent.delete_attribute('SPTAKE', 'samples')
                next
            end
            @lastFrame = samps.size if samps.size > @lastFrame
            @animationObjectList[ent] = samps if ent.valid?
        }
    end

    def export
        findAnimationObjects
        startFrame = 0
        endFrame = @lastFrame
        rate = @animationRate
        saveType = 'skp'
        prompts = ['Start Frame', 'End Frame', 'Rate', 'Save As']
        values = [startFrame, endFrame, @animationRate, saveType]
        results = inputbox(prompts, values, [[],[],[],['skp|png|jpg']], 'Export Settings')
        return unless results
        startFrame, endFrame, @animationRate, saveType = results
        path = Sketchup.active_model.path
        path = File.basename(path, '.skp')
        sf = UI.savepanel('Export Animation', nil, path)
        return unless sf
        dir = File.dirname(sf)
        fn = File.basename(sf, '.skp')
        dir.gsub!(/\\/,'/')# change \ to /. I HATE how ruby needs regexpr for this crap!!!!!!
        Sketchup.active_model.start_operation 'Export Animation'
        expFrame = 0
        begin
            self.start
            @animationObjectList.each { |ent|
                ent[0].attribute_dictionaries.delete('SPTAKE')
            }
            while(@frame < endFrame)
                nextFrame(nil)
                fname = "#{dir}/#{fn}_%06d.#{saveType}" % expFrame
                if saveType.downcase == 'skp'
                    Sketchup.active_model.save(fname)
                else
                    Sketchup.active_model.active_view.write_image(fname)
                end
                expFrame += 1
            end
            setFrame(0)
        rescue Exception => e
            UI.messagebox("Error: #{e}\n#{e.backtrace[0..2].join("\n")}", MB_OK, 'Error Exporting Animation')
        end
        Sketchup.active_model.abort_operation
    end

    def start
        return if @started
        model = Sketchup.active_model
        @bPaused = false
        @bStopped = false
        @transformations.clear
        model.entities.each { |ent|
            if ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
                @transformations[ent.entityID] = ent.transformation
            end
        }
        camera = model.active_view.camera
        @cameraRestore = Sketchup::Camera.new(camera.eye, camera.target, camera.up)
        setCameraToPage(model.pages.selected_page)
        model.active_view.show_frame
        @started = true
    end

    # Start the animation
    def play
        @animationRate = @animationRate.abs
        @bPaused = !@bPaused
        start
        Sketchup.active_model.active_view.show_frame
    end

    def pause
        @bPaused = true
        Sketchup.active_model.active_view.show_frame
    end

    def isPaused
        @bPaused
    end

    def paused?
        @bPaused
    end

    def reverse
        return if @frame <= 0
        @bPaused = false
        @animationRate = -@animationRate
        Sketchup.active_model.active_view.show_frame
    end

    def rewind
        return unless @started
        @started = false
        @bPaused = true
        setCameraToPage(Sketchup.active_model.pages.selected_page)
        cameraPreFrame
        setFrame(0)
        updateCamera()
        @bStopped = true
        if @cameraRestore
            Sketchup.active_model.active_view.camera = @cameraRestore
        end
        @transformations.clear
        @animationObjectList.clear
    end

    def setFrame(frameNumber)
        @frame = frameNumber
        #Sketchup.vcb_value = frameNumber
        Sketchup.set_status_text "Frame: #{@frame}", SB_VCB_LABEL
        # If needed find objects.
        findAnimationObjects() if @animationObjectList.empty?
        # Move objects to original placement if frame is zero.
        if @frame == 0
          Sketchup.active_model.entities.each { |ent|
            tra = @transformations[ent.entityID]
            next unless tra
            ent.move! tra
          }
          return
        end
        # Move objects to desired positions.
        @animationObjectList.each { |ent, data|
            next unless ent.valid?
            tra = data[frame]
            ent.transformation = tra if tra.is_a?(Array)
        }
    end

    def nextFrame(view = nil)
        unless @bPaused
            @frame += @animationRate
            cameraPreFrame()
            setFrame(@frame)
            updateCamera()
            view.show_frame if view
            Sketchup.set_status_text "Frame #{@frame} / #{@lastFrame}"
        end
        true
    end

    def findComponentNamed(name)
        return unless name.is_a?(String)
        return if name.empty?
        Sketchup.active_model.definitions.each { |cd|
            cd.instances.each { |ci|
                return ci if ci.name.casecmp(name) == 0
            }
        }
        nil
    end

    #camera follow, target, whatever.
    #duration
    #start frame, end frame.
    #next/prev frame name (optional for out of sequence cuts.

    def findPageNamed(name)
        return unless name.is_a?(String)
        Sketchup.active_model.pages.each { |p|
            return p if p.name.casecmp(name) == 0
        }
        nil
    end

    def setCameraToPage(page)
        return unless $spMovieMode
        @cameraParent = nil
        @cameraTarget = nil
        @cameraType = nil
        @cameraNextPage = nil
        @cameraFrameEnd = nil
        return unless page
        #Sketchup.active_model.pages.selected_page.description.downcase.gsub(/ /, '').split(';')
        paramArray = page.description.downcase.gsub(/ /, '').split(';')
        params = Hash[*paramArray.collect { |v|
            [v.split('=')[0], v.split('=')[1]]
        }.flatten]
        # if series
        # find right page in series
        # set transition frame and next page
        @cameraParent = findComponentNamed(params['parent']) # follow
        @cameraTarget = findComponentNamed(params['target']) # track

        #@cameraParent = findComponentNamed(params['follow']) # follow
        #@cameraTarget = findComponentNamed(params['track']) # track

        @cameraType = params['type']
        @cameraNextPage = findPageNamed(params['nextpage'])

        # Defaults to first (0) and last frame in animation
        @cameraEndFrame = params['endframe']
        @cameraStartFrame = params['startFrame']

        @frame = params['setframe'].to_i if params['setframe']
        @pauseFrame = params['pauseframe'] ? params['pauseframe'].to_i : nil
        @animationRate = params['animationrate'] ? params['animationrate'].to_i : 1
        #print @cameraNextPage, ',', @cameraEndFrame.to_i
        Sketchup.active_model.active_view.camera = page.camera
    end

    def onUserText(text, view)
        puts "onUserText: #{text}"
    end

    def findCameras
        @cameraEntity = nil
        @cameraTargetEntity = nil
        @cameraPreMoveOffset = nil
        begin
            params = Sketchup.active_model.pages.selected_page.description.downcase.split(';')
            if pageDesc.include?('parent=')
                pageDesc.chomp!
                targetname = pageDesc.split('=')[1]
                Sketchup.active_model.entities.each { |ent|
                    if ent.typename.downcase == 'componentinstance' and ent.name.downcase == targetname
                        @cameraTargetEntity = ent
                        camera = Sketchup.active_model.active_view.camera
                    end
                }
            end
        rescue Exception => e
            puts "Error finding cameras:\n#{e}\n#{e.backtrace[0..2].join("\n")}"
        end
    end

    def cameraPreFrame
        if @cameraEndFrame != nil and @frame > @cameraEndFrame.to_i and @cameraNextPage != nil
            setCameraToPage(@cameraNextPage)
        end
        if @pauseFrame != nil and @frame > @pauseFrame.to_i
            self.pause
        end
        if @frame > @lastFrame
            @frame = @lastFrame
            self.pause
        end
        if @animationRate < 0 and @frame < 0
            @frame = 0
            self.reverse
            self.pause
        end
        if @cameraParent
            #@cameraPreMoveOffset = Sketchup.active_model.active_view.camera.eye-@cameraParent.transformation.origin
            @cameraPreMoveOffset = Sketchup.active_model.active_view.camera.eye - @cameraParent.bounds.center
        end
    end

    def updateCamera
        #Sketchup.active_model.selection.first.curve.vertices.each { |v| print v.position }
        #Sketchup.active_model.selection.first.curve.vertices[curVert].each { |v| print v.position }
        def calcPointAlongCurve(curve, percent)
            curve = Sketchup.active_model.selection.first.curve
            totalLength = 0
            curve.edges.each { |e|
                totalLength += e.length
            }
            dist = (1.0/totalLength)*percent
            curve.edges.each { |e|
                dist = dist-e.length
                if dist < 0
                    return e.line[0]+(e.line[1].length=(e.length-dist))
                end
            }
        end
        camera = Sketchup.active_model.active_view.camera
        if @cameraParent
            #if @cameraParent.description.downcase.include?('animationpath')
            #   dest = calcPointAlongCurve(@cameraPath, 1.0/(frameEnd-frameStart)) + @cameraPreMoveOffset
            #else
                #dest = @cameraParent.transformation.origin + @cameraPreMoveOffset
                dest = @cameraParent.bounds.center + @cameraPreMoveOffset
            #end
            camera.set(dest, dest+camera.direction, Z_AXIS)
        end
        if @cameraTarget
            target = @cameraTarget
            camera.set(camera.eye, @cameraTarget.bounds.center, Z_AXIS)
        end
    end

    # The stop method will be called when SketchUp wants an animation to stop
    # this method is optional.
    def stop
    end

    ############################## Start of Tool ###################################

    # The activate method is called when a tool is first activated.  It is not
    # required, but it is a good place to initialize stuff.
    def activate
    end

    def deactivate
    end

    def onLButtonDown(flags, x, y, view)
    end

    # onLButtonUp is called when the user releases the left mouse button
    def onLButtonUp(flags, x, y, view)
    end

    # draw is optional.  It is called on the active tool whenever SketchUp
    # needs to update the screen.
    #def draw(view)
    #end

    #def onSetCursor()
    #end

    ############################## End of Tool ###################################

end # class SketchyReplay


unless file_loaded?(__FILE__)
    file_loaded(__FILE__)

    toolbar = UI::Toolbar.new('Sketchy Replay')
    $spDoRecord = false
    $spMovieMode = false

    cmd = UI::Command.new('Record'){ $spDoRecord = !$spDoRecord }
    cmd.set_validation_proc {
        $spDoRecord ? MF_CHECKED : MF_UNCHECKED
    }
    cmd.small_icon = 'images/SketchyPhysics-StopButton.png'
    cmd.large_icon = 'images/SketchyPhysics-StopButton.png'
    cmd.menu_text = cmd.tooltip = 'Toggle recording'
    cmd.status_bar_text = 'Toggle recording'
    toolbar.add_item cmd


    cmd = UI::Command.new('Play'){
        unless @@replayAnimation
            @@replayAnimation = SketchyReplay.new
        end
        Sketchup.active_model.active_view.animation = @@replayAnimation
        @@replayAnimation.play
        #~ if Sketchup.active_model.active_view.animation = @@replayAnimation and @@replayAnimation.paused?
            #~ Sketchup.active_model.active_view.animation = nil
        #~ end
    }
    cmd.small_icon = 'images/SketchyReplay-PlayPauseButton.png'
    cmd.large_icon = 'images/SketchyReplay-PlayPauseButton.png'
    cmd.menu_text = cmd.tooltip = 'Play animation.'
    cmd.status_bar_text = 'Play animation.'
    toolbar.add_item cmd


    cmd = UI::Command.new('Rewind'){
        #@@replayAnimation.setFrame(1)
        @@replayAnimation.rewind if @@replayAnimation
        Sketchup.active_model.active_view.animation = nil
    }
    cmd.small_icon = 'images/SketchyReplay-RewindButton.png'
    cmd.large_icon = 'images/SketchyReplay-RewindButton.png'
    cmd.menu_text = cmd.tooltip = 'Rewind to first frame.'
    cmd.status_bar_text = 'Rewind to first frame.'
    toolbar.add_item cmd


    cmd = UI::Command.new('Reverse'){
        @@replayAnimation.reverse if @@replayAnimation
    }
    cmd.small_icon = 'images/SketchyReplay-ReverseButton.png'
    cmd.large_icon = 'images/SketchyReplay-ReverseButton.png'
    cmd.menu_text = cmd.tooltip = 'Reverse'
    cmd.status_bar_text = 'Reverse animation.'
    toolbar.add_item cmd


    cmd = UI::Command.new('Record'){
        $spMovieMode = !$spMovieMode
    }
    cmd.set_validation_proc {
        $spMovieMode ? MF_CHECKED : MF_UNCHECKED
    }
    cmd.small_icon = 'images/SketchyReplay-MovieButton.png'
    cmd.large_icon = 'images/SketchyReplay-MovieButton.png'
    cmd.menu_text = cmd.tooltip = 'Toggle movie mode.'
    cmd.status_bar_text = 'Toggle movie mode.'
    #toolbar.add_item cmd


    submenu = UI.menu('Plugins').add_submenu('Sketchy Replay')
    submenu.add_item('Export Animation'){
        sr = SketchyReplay.new
        sr.export
    }
    submenu.add_item('Erase Animation'){
        Sketchup.active_model.definitions.each { |cd|
            cd.instances.each { |ci|
                ci.delete_attribute('SPTAKE', 'samples')
            }
        }
    }
    submenu.add_separator
    submenu.add_item('About'){
        UI.messagebox("Version 1.1.0\nWritten by Chris Phillips.")
    }


    #~ cmd = UI::Command.new('Export'){
        #~ sr = SketchyReplay.new
        #~ sr.export
    #~ }
    #~ cmd.small_icon = 'images/SketchyReplay-ReverseButton.png'
    #~ cmd.large_icon = 'images/SketchyReplay-ReverseButton.png'
    #~ cmd.menu_text = cmd.tooltip = 'Export animation.'
    #~ cmd.status_bar_text = 'Export animation.'
    #~ toolbar.add_item cmd


    #~ cmd = UI::Command.new('ClearAnimation'){
        #~ #@@replayAnimation.rewind
        #~ @@replayAnimation.clearAllAnimation
        #~ Sketchup.active_model.active_view.animation = nil
    #~ }
    #~ cmd.small_icon = 'images/SketchyReplay-ClearAnimationButton.png'
    #~ cmd.large_icon = 'images/SketchyReplay-ClearAnimationButton.png'
    #~ cmd.menu_text = cmd.tooltip = 'Clear animation.'
    #~ cmd.status_bar_text = 'Clear all animation data'
    #~ toolbar.add_item cmd

    toolbar.show
    @@replayAnimation = nil
end

end # module SketchyReplay
