require 'sketchup.rb'

dir = File.dirname(__FILE__)
$LOAD_PATH.insert(0, dir)

# List of all global variables in SP
$spExperimentalFeatures = true
$spDoRecord = false
$spMovieMode = false
$spObjectInspector = nil
$sketchyPhysicsToolInstance = nil
$curPhysicsSimulation = nil
$curEvalGroup = nil
$curEvalTouchingGroup = nil
# The following global variables are used in SP but are never created.
$spSoundInst = nil
$sketchyViewerDialog = nil
$debug = nil


begin
  require 'class_extensions.rb'
  require 'newton.rb'
  require 'virtual_key_codes.rb'
  require 'input.rb'
  require 'midi.rb'
  require 'sound.rb'
  require 'controller_commands.rb'
  require 'sp_tool.rb'
  require 'sp_util.rb'
  require 'control_panel.rb'
  require 'inspector.rb'
  require 'prims_tool.rb'
  require 'box_prim_tool.rb'
  require 'joint_tool.rb'
  require 'joint_connection_tool.rb'
  require 'attach_tool.rb'
  require 'sketchy_replay.rb'
  #~ require 'child_frame.rb'
  #~ require 'sp_midi.rb'
rescue Exception => e
  err = RUBY_VERSION =~ /1.8/ ? "#{e}\n\n#{e.backtrace.join("\n")}" : e
  raise e
ensure
  $LOAD_PATH.delete_at(0)
end

unless file_loaded?(__FILE__)
  file_loaded(__FILE__)

  menu = UI.menu('Plugins').add_submenu('SketchyPhysics')
  help_menu = UI.menu('Help')

  menu.add_item('Physics Settings'){
    MSketchyPhysics3.editPhysicsSettings
  }

  menu.add_item('Buoyancy Settings'){
    MSketchyPhysics3.setupBuoyancy
  }

  menu.add_item('Sounds'){
    MSketchyPhysics3.soundEmbedder
  }

  menu.add_separator

  menu.add_item('Homepage'){
    UI.openURL("http://sketchucation.com/forums/viewforum.php?f=61")
  }

  menu.add_item('Wiki'){
    UI.openURL("http://sketchyphysics.wikia.com/wiki/SketchyPhysicsWiki")
  }

  about_msg = "SketchyPhysics #{MSketchyPhysics3::VERSION}\n"
  about_msg << "Powered by the Newton Dynamics physics SDK.\n"
  about_msg << "Copyright © 2009-2014, Chris Phillips\n"
  about_msg << "Use SketchUcation PluginStore to check for updates."

  menu.add_item('About'){ UI.messagebox(about_msg) }

  #~ help_menu.add_separator
  #~ help_menu.add_item('About SketchyPhysics'){ UI.messagebox(about_msg) }
end
