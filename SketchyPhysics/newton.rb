require 'sketchup.rb'

dir = File.dirname(__FILE__)
if RUBY_VERSION =~ /1.8/
  require File.join(dir, 'lib/dl/import.rb')
  require File.join(dir, 'lib/dl/struct.rb')
else
  require File.join(dir, 'lib/ffi')
end

module MSketchyPhysics3
  class << self

    # Dump top level faces
    # Recursively dump the definitions
    # Create instances
    def dumpit
        geom = []
        instances = []
        definitions = {}
        Sketchup.active_model.entities.each { |ent|
            if ent.is_a?(Sketchup::Face)
                pts = []
                ent.mesh.points.each { |p| pts.push(p.to_a) }
                geom << [pts.length, ent.normal.to_a, pts]
            elsif ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
                dguid = MSketchyPhysics3.get_definition(ent).guid
                unless definitions[dguid]
                    out = []
                    dumpents(MSketchyPhysics3.get_definition(ent).entities, out)
                    definitions[dguid] = out
                end
                instances << ent
            end
        }
        #puts ['Geom', geom.length].inspect
        #puts ['Definitions', definitions.length].inspect
        #puts ['Instances', instances.length].inspect
        #dumpents(Sketchup.active_model.entities,out)
        return [geom, definitions, instances]
    end

    def dumpents(ents, out)
        ents.each { |ent|
            if ent.is_a?(Sketchup::Face)
                pts = []
                ent.mesh.points.each { |p| pts << p.to_a }
                out << [pts.length, ent.normal.to_a, pts]
                #puts [ent.class, ent.vertices.length].inspect
            elsif ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
                dumpents(MSketchyPhysics3.get_definition(ent).entities, out)
            end
        }
    end

    def testRender
        group = Sketchup.active_model.selection[0]
        tris = []
        normals = []
        group.entities.each { |ent|
            if ent.is_a?(Sketchup::Face)
                normals += ent.normal.to_a
                normals += ent.normal.to_a
                normals += ent.normal.to_a
                ent.mesh.polygons.each_index { |pi|
                    pts = ent.mesh.polygon_points_at( pi+1 ).each { |pt|
                        tris = tris + pt.to_a
                    }
                }
            end
        }
        SketchyRender.buildDisplayList(tris.to_a.pack('f*'), normals.to_a.pack('f*'), tris.length/3).to_i
    end

  end # proxy class
end # module MSketchyPhysics3


module MSketchyPhysics3::SketchyRender

if RUBY_VERSION =~ /1.8/
    extend DL::Importable

    dir = File.dirname(__FILE__)
    if RUBY_PLATFORM =~ /mswin|mingw/i
        #dlload File.join(dir, 'lib/SketchyRender.dll')
    else
        #dlload File.join(dir, 'lib/libNewtonServer3.dylib')
    end
    #extern "int buildDisplayList(float*, float*, int)"
else
    extend FFI::Library

    if RUBY_PLATFORM =~ /mswin|mingw/i
        #ffi_lib File.join(dir, 'lib/SketchyRender.dll')
    else
        #ffi_lib File.join(dir, 'lib/libNewtonServer3.dylib')
    end
    #attach_function :buildDisplayList, [:pointer, :pointer, :int], :int
end

end # module MSketchyPhysics3::SketchyRender


module MSketchyPhysics3::NewtonServer

dir = File.dirname(__FILE__)

if RUBY_VERSION =~ /1.8/
    extend DL::Importable

    if RUBY_PLATFORM =~ /mswin|mingw/i
        dlload File.join(dir, 'lib/NewtonServer3.dll')
        # extern "int readJoystick(float *)"
        # extern "int initDirectInput()"
        # extern "void freeDirectInput()"
    else
        dlload File.join(dir, 'lib/libNewtonServer3.dylib')
    end

    extern "void init()"
    extern "void stop()"
    extern "void update(int)"
    extern "int fetchSingleUpdate(float*)"
    extern "void* fetchAllUpdates()"
    extern "void requestUpdate(int)"
    extern "void* NewtonCommand(void*, void*)"
    extern "int CreateBallJoint(float*, NewtonBody*, NewtonBody*)"
    extern "int CreateJoint(void*, float*, float*, NewtonBody*, NewtonBody*, float*)"
    extern "void BodySetMagnet(NewtonBody*, CMagnet*, float*)"
    extern "int GetBodyCollision(NewtonBody*, float*, int)"
    extern "void SetBodyCenterOfMass(NewtonBody*, float*)"
    extern "void BodySetFreeze(NewtonBody*, int)"
    extern "void setJointData(void*, float*)"
    extern "void addImpulse(NewtonBody*, float*, float*)"
    extern "void MagnetMove(CMagnet*, float*)"
    extern "CGlobalForce* addGlobalForce(float*, float*, int, int, int)"
    extern "CGlobalForce* addForce(NewtonBody*, float)"
    extern "void setForceStrength(CGlobalForce*, float)"
    extern "void setBodyMagnetic(NewtonBody*, int)"
    extern "void setBodySolid(NewtonBody*, int)"
    extern "void BodySetMaterial(NewtonBody*, int)"

    extern "CMagnet* MagnetAdd(float*)"
    extern "NewtonCollision* CreateCollision(void*, float*, float*, float*)"
    extern "NewtonCollision* CreateCollisionMesh(float*, int)"

    extern "void DestroyBody(NewtonBody*)"
    extern "void DestroyJoint(NewtonJoint*)"
    extern "void SetMatrix(NewtonBody*, dFloat*, int)"

    extern "NewtonBody* CreateBody(int, NewtonCollision*, int, int, float*, float*, float)"
    extern "void setupBouyancy(float*, float*, float*)"
    extern "int CreateGear(void*, float*, float*, NewtonBody*, NewtonBody*, float)"
    extern "void setJointRotation(ControlledJoint*, float*)"
    extern "void setJointPosition(ControlledJoint*, float*)"
    extern "void setJointAccel(ControlledJoint*, float*)"
    extern "void setJointDamp(ControlledJoint*, float*)"
    extern "void setJointCollisionState(NewtonCustomJoint*, int)"
    extern "void bodyGetVelocity(NewtonBody*, float*)"
    extern "void bodySetVelocity(NewtonBody*, float*)"
    extern "void bodyGetTorque(NewtonBody*, float*)"
    extern "void bodySetTorque(NewtonBody*, float*)"

    extern "void bodySetLinearDamping(NewtonBody*, float)"
    extern "void bodySetAngularDamping(NewtonBody*, float*)"

    extern "void setDesiredMatrix(DesiredJoint*, float*)"
    extern "void setDesiredParams(DesiredJoint*, float*)"

    extern "void bodySetThrust(NewtonBody*, float)"
    extern "void setGyroPinDir(CustomUpVector*, float*)"
    extern "void setBodyCollideCallback(NewtonBody*, void*)"
    extern "void glueBodies(NewtonBody*, NewtonBody*, float)"

    def doCollideCallback(body0, body1, contactSpeed, x, y, z)
        return unless $curPhysicsSimulation
        return unless $sketchyPhysicsToolInstance
        # Have it in deferred task, so Newton doesn't crash if reset is called.
        $curPhysicsSimulation.deferred_tasks << lambda {
            #puts contactPos.ptr.to_s.unpack("f3")
            #MSketchyPhysics3::NewtonServer.glueBodies(body1, body0, 3300.0)
            $sketchyPhysicsToolInstance.handleOnTouch([body0, body1], contactSpeed, [x,y,z])
            #puts "CollideCallback: #{body0.to_i} #{body1.to_i}"
        }
    end
    COLLIDE_CALLBACK = (callback "void doCollideCallback(body*, body*, float, float, float, float)")

else
    extend FFI::Library

    if RUBY_PLATFORM =~ /mswin|mingw/i
        ffi_lib File.join(dir, 'lib/NewtonServer3.dll')
    else
        ffi_lib File.join(dir, 'lib/libNewtonServer3.dylib')
    end

    callback :collide_callback, [:pointer, :pointer, :float, :float, :float, :float], :void

    attach_function :init, [], :void
    attach_function :stop, [], :void
    attach_function :update, [:int], :void
    attach_function :fetchSingleUpdate, [:pointer], :int
    attach_function :fetchAllUpdates, [], :pointer
    attach_function :requestUpdate, [:int], :void
    attach_function :newtonCommand, :NewtonCommand, [:pointer, :pointer], :pointer
    attach_function :createBallJoint, :CreateBallJoint, [:pointer, :pointer, :pointer], :int
    attach_function :createJoint, :CreateJoint, [:pointer, :pointer, :pointer, :pointer, :pointer, :pointer], :int
    attach_function :bodySetMagnet, :BodySetMagnet, [:pointer, :pointer, :pointer], :void
    attach_function :getBodyCollision, :GetBodyCollision, [:pointer, :pointer, :int], :int
    attach_function :setBodyCenterOfMass, :SetBodyCenterOfMass, [:pointer, :pointer], :void
    attach_function :bodySetFreeze, :BodySetFreeze, [:pointer, :int], :void
    attach_function :setJointData, [:pointer, :pointer], :void
    attach_function :addImpulse, [:pointer, :pointer, :pointer], :void
    attach_function :magnetMove, :MagnetMove, [:pointer, :pointer], :void
    attach_function :addGlobalForce, [:pointer, :pointer, :int, :int, :int], :pointer
    attach_function :addForce, [:pointer, :float], :pointer
    attach_function :setForceStrength, [:pointer, :float], :void
    attach_function :setBodyMagnetic, [:pointer, :int], :void
    attach_function :setBodySolid, [:pointer, :int], :void
    attach_function :bodySetMaterial, :BodySetMaterial, [:pointer, :int], :void

    attach_function :magnetAdd, :MagnetAdd, [:pointer], :pointer
    attach_function :createCollision, :CreateCollision, [:pointer, :pointer, :pointer, :pointer], :pointer
    attach_function :createCollisionMesh, :CreateCollisionMesh, [:pointer, :int], :pointer

    attach_function :destroyBody, :DestroyBody, [:pointer], :void
    attach_function :destroyJoint, :DestroyJoint, [:pointer], :void
    attach_function :setMatrix, :SetMatrix, [:pointer, :pointer, :int], :void

    attach_function :createBody, :CreateBody, [:int, :pointer, :int, :int, :pointer, :pointer, :float], :pointer
    attach_function :setupBouyancy, [:pointer, :pointer, :pointer], :void
    attach_function :createGear, :CreateGear, [:pointer, :pointer, :pointer, :pointer, :pointer, :float], :int
    attach_function :setJointRotation, [:pointer, :pointer], :void
    attach_function :setJointPosition, [:pointer, :pointer], :void
    attach_function :setJointAccel, [:pointer, :pointer], :void
    attach_function :setJointDamp, [:pointer, :pointer], :void
    attach_function :setJointCollisionState, [:pointer, :int], :void
    attach_function :bodyGetVelocity, [:pointer, :pointer], :void
    attach_function :bodySetVelocity, [:pointer, :pointer], :void
    attach_function :bodyGetTorque, [:pointer, :pointer], :void
    attach_function :bodySetTorque, [:pointer, :pointer], :void

    attach_function :bodySetLinearDamping, [:pointer, :float], :void
    attach_function :bodySetAngularDamping, [:pointer, :pointer], :void

    attach_function :setDesiredMatrix, [:pointer, :pointer], :void
    attach_function :setDesiredParams, [:pointer, :pointer], :void

    attach_function :bodySetThrust, [:pointer, :float], :void
    attach_function :setGyroPinDir, [:pointer, :pointer], :void
    attach_function :setBodyCollideCallback, [:pointer, :collide_callback], :void
    attach_function :glueBodies, [:pointer, :pointer, :float], :void

    COLLIDE_CALLBACK = Proc.new { |body0, body1, contact_speed, x, y, z|
      next unless $curPhysicsSimulation
      next unless $sketchyPhysicsToolInstance
      # Have it in deferred task, so Newton doesn't crash if reset is called.
      $curPhysicsSimulation.deferred_tasks << lambda {
        $sketchyPhysicsToolInstance.handleOnTouch([body0, body1], contact_speed, [x,y,z])
      }
    }
end

end # MSketchyPhysics3::NewtonServer
