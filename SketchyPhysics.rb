# ------------------------------------------------------------------------------
# ** SketchyPhysics **
#
# Overview
#   SketchyPhysics is a real-time physics simulation plugin for SketchUp.
#
# Homepage
#   http://sketchucation.com/forums/viewforum.php?f=61
#
# Access
#   * (Menu) Plugins → SketchyPhysics → [option]
#   * SketchyPhysics Toolbars
#
# Version
#   3.3.0 (Unofficial)
#
# Release Date
#   July 20, 2014
#
# Compatibility and Requirements
#   * SU6 or later
#   * Windows or Mac OS X
#     Mac OS X is not yet fully supported in terms of SketchyPhysics script API.
#
# Change Log
#   Version 3.3.0 - July 17, 2014
#     - Compatible in SU2013, and SU2014.
#     - Replaced all Sketchup API modifying and adding methods, including
#       Sketchup::Group.#copy. Warning, this change prevents many scripted
#       models from working, especially those that rely on object entities.
#       ComponentInstance doesn't have a .entities method, but its definition
#       does. You will have to check before getting entities:
#           if ent.is_a?(Sketchup::ComponentInstnace)
#               ents = ent.definition.entities
#           elsif ent.is_a?(Sketchup::Group)
#               ents = ent.entities
#           end
#       Or use an available function: ents = MSketchyPhysics3.get_entities(ent).
#     - Minimized the use of global variables. Warning, this change prevents
#       many scripted models from working, especially LazyScript which depends
#       on $sketchyphysics_script_version variable. Use MSketchyPhysics::VERSION
#       instead. Many more global variables were removed as well; however,
#       $curPhysicsSimulation and $sketchyPhysicsToolInstance were not removed,
#       as they are quite handy.
#     - Improved script error handlers. Simulation will reset properly if an
#       error occurs. All detected errors, except those in joint controllers,
#       will force simulation to abort. Due to that change many models that were
#       uploaded with script errors will no longer work until they r' fixed.
#     - Fixed minor inspector dialog errors.
#           - Dialog clears when selection clears.
#           - Script can handle all sorts of escape characters.
#           - No longer throws two error messages.
#           - You're no longer required to click on the element to save the
#             written script.
#     - Rewrote most Ruby files, just to improve the way code looks and fixed
#       some minor bugs and inconsistencies. Note: This change could raise more
#       errors as I didn't pay much attention to what I did there. Need testers!
#     - Used Ruby DL to export functions for Ruby 1.8.x, used FFI to export
#       functions for Ruby 2.0.0.
#     - Added setSoundPosition2, which properly distributes 3d sound to the
#       left and right speakers, and controls volume depending by the specified
#       hearing range.
#     - Added drawPoints to simulation context, which allows you to draw points
#       with style.
#     - Added $sketchyPhysicsSimulationTool.cursorPos method - get cursor
#       position relative to view origin.
#     - Added more virtual key codes, 0-9 keys, semicolons, brackets, etc.
#     - Improved SP3xCommonContext.#key method. You may pass key values
#       to determine whether the specified key is down. This was added as a
#       backup technique if the desired key name is missing, you can pass key
#       constant value to get its up/down state.
#     - Emit bodies with original density. Previously copied bodies did not
#       have same density as the original bodies did. This is fixed now.
#     - Temporarily removed check for update as it would recommend downloading
#       SP3.2. Use SketchyUcation PluginStore instead.
#     - Added simulation.drawExt method, which basically behaves the same as
#       simulation.draw, but with more available types. Including, the 'line'
#       type yields GL_LINES rather than GL_LINE_STRIP like in the
#       simulation.draw method. The simulation.draw method was not replaced
#       just to remain compatible.
#     - View OpenGL drawn geometry is now included in the bounding box.
#     - Added ondraw { |view, bb| } - bb is the Geom::BoundingBox. Use it to add
#       3d points to the bounding box, so they don't get clipped. First, add
#       points and then draw.
#     - Used abort_operation rather than commit_operation to reset simulation.
#       This undoes most model changes made during simulation.
#     - Created joints will no longer add 'jointBlue' material...
#     - Removed MSketchyPhysics3::SketchyPhysicsClient.resetSimulation method.
#       Use MSketchyPhysics3::SketchyPhysicsClient.physicsStart to start.
#       Use MSketchyPhysics3::SketchyPhysicsClient.physicsReset to reset.
#       Use MSketchyPhysics3::SketchyPhysicsClient.physicsTogglePlay to play or
#       pause.
#       Use MSketchyPhysics3::SketchyPhysicsClient.paused? to determine whether
#       simulation is paused.
#       Use MSketchyPhysics3::SketchyPhysicsClient.active? to determine whether
#       simulation has started.
#     - Entity axis are no longer modified. They are modified, but they are set
#       back when simulation resets.
#     - Clears reference to all big variables at end, so garbage collection
#       cleans stuff up.
#     - Improved drag tool. Objects won't go to far, and lift object works
#       even if camera is looking from the top.
#     - Fix the glitch in joint connection tool where cursors didn't update.
#     - Added cursor access method.
#       $sketchyPhysicsToolInstance.getCursor - returns cursor id.
#       $sketchyPhysicsToolInstance.setCursor(id) - id: can be String, Symbol,
#       or Fixnum. Available names are select_plus, select_plus_minus, hand, and
#       target. For instance, set target cursor when creating FPS games:
#           onstart {
#               $sketchyPhysicsToolInstance.setCursor(:target)
#           }
#     - Added toggle pick and drag tool. When creating FPS games you might want
#       to disable the drag tool, so player can't pick bodies.
#       Use $sketchyPhysicsToolInstance.pick_drag_enabled = state (true or false)
#       Use $sketchyPhysicsToolInstance.pick_drag_enabled? to determine whether
#       the drag tool is enabled.
#       Example:
#           onstart {
#               $sketchyPhysicsToolInstance.pick_drag_enabled = false
#           }
#     - Added aliased event names:
#       onstart : onStart
#       onend : onEnd
#       ontick : onTick : onupdate :onUpdate
#       onpreframe : onPreFrame : onpreupdate :onPreUpdate
#       onpostframe : onPostFrame : onpostupdate :onPostUpdate
#       ontouch : onTouch
#       ontouching : onTouching
#       onuntouch : onUntouch
#       ondraw : onDraw
#       onclick : onClick
#       onunclick : onUnclick
#       ondoubleclick : onDoubleClick
#       ondrag : onDrag
#     - Improve record tool:
#       * Objects will move to their original positions when you press the
#         rewind button, regardless of when you started the recording.
#       * You may toggle recording any-time during simulation.
#       * Missing frames will no longer force the object to hide (move! 0).
#     - onDrag is called once a frame now (if the mouse is moved).
#     - Added onDoubleClick implementation.
#     - Added sp_tool which returns MSketchyPhysics3::SketchyPhysicsClient.
#     - Added sp_tool_instance which returns $sketchyPhysicsToolInstance.
#
# To Do
#   - Avoid modifying object axis. From my understanding it was added to apply
#     proper forces to the picked body.
#   - Centre of mass should not depend on the bounding box. Use Newton to
#     calculate centre of mass.
#   - Magnetic/Picked bodies act improperly when their origin is not the same as
#     their predefined centre of mass.
#   ~ Change method names from mymethod/myMethod to my_method.
#   - Add yardoc documentation.
#   - Upgrade to Newton 2.36 or Newton 3.
#   - Upgrade to SDL2.
#   ~ Proper interpretation of Foreign keys.
#   - Update dialog style.
#   - Improve brakeit method. Add face at split location. Destroy original body.
#   - Add lookAt(nil) to destroy the lookAt joint.
#   - Add more virtual keys to Mac OS X. You added semicolons and other symbols
#     to windows, but not to Mac. Fix it!
#   - Get rid of global getKeyState in input.rb.
#   - Fix $spSoundInst in sound.rb
#   - Work on sp_midi.rb
#   - Rewrite all dialogs. Use jquery. Have major web content in html, css, and
#     js files.
#   - Add explosion function.
#   - Set body mass via script or inspector.
#   - Toggle body static.
#   - Add compatibility files for SP3RC1, SP3X, SP3.1, SP3.2, and SP3.3.
#   - Test all events: onuntouch works only if ontouch is included.
#   - Capture/Release mouse (For FPS games)
#   ~ Add App observer. Could be useful to detect undo; however, its not needed
#     as major operations are undone manually via script.
#   - Commented out all make_unique in sp_tool.rb. Test!
#   - Add particle effects, and more goodies from the LazyScript.
#   - Add overwrite detectors. Models that overwrite SP content force SU to
#     freeze or crash in many cases.
#   - Create Wiki
#   - Test midi on Mac.
#
# Licence
#   Copyright © 2009-2014, Chris Phillips
#
# Credits
#   * Juleo Jerez for the NewtonDynamics physics engine.
#   * Anton Synytsia for 3.3.0. Thanks to Mtriple for starting out ;)
#
# Author
#   Chris Phillips
#
# ------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

dir = File.dirname(__FILE__)

module MSketchyPhysics3

  NAME         = 'SketchyPhysics'.freeze
  VERSION      = '3.3.0 (Unofficial)'.freeze
  RELEASE_DATE = 'July 20, 2014'.freeze

  # Create the extension.
  @extension = SketchupExtension.new NAME, 'SketchyPhysics/main.rb'

  desc = 'Realtime physics simulation plugin for SketchUp.'

  # Attach some nice info.
  @extension.description = desc
  @extension.version     = VERSION
  @extension.copyright   = 'Copyright © 2009-2014, Chris Phillips'
  @extension.creator     = 'Chris Phillips'

  # Register and load the extension on start-up.
  Sketchup.register_extension @extension, true

  class << self
    attr_reader :extension
  end

end
