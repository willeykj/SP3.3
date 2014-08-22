require 'sketchup.rb'

module MSketchyPhysics3

def self.setDefaultPhysicsSettings
    model = Sketchup.active_model
    model.set_attribute('SPSETTINGS', 'defaultobjectdensity', 0.2)
    model.set_attribute('SPSETTINGS', 'worldscale', 9.0)
    model.set_attribute('SPSETTINGS', 'gravity', 1.0)
    model.set_attribute('SPSETTINGS', 'framerate', 3)
    #model.set_attribute('SPSETTINGS', 'water', 1)
end

=begin
class SP3xCommonContext
    # Security
    class Kernel
    end
    class Dir
    end
    class File
    end
    class IO
    end
    class Thread
    end
    class Process
    end
end # class SP3xCommonContext
=end

class SketchyPhysicsClient

    def extractScaleFromGroup(group)
        Geom::Transformation.scaling(
            (Geom::Vector3d.new(1.0,0,0).transform!(group.transformation)).length,
            (Geom::Vector3d.new(0,1.0,0).transform!(group.transformation)).length,
            (Geom::Vector3d.new(0,0,1.0).transform!(group.transformation)).length
        )
    end

    def findParentInstance(ci)
        MSketchyPhysics3.get_definition(ci).instances.each { |di|
            return di if ci == di
        }
        nil
    end

    def resetAxis(ent)
        SketchyPhysicsClient.resetAxis(ent)
    end

    @@origAxis = {}

    def self.resetAxis(ent)
        if ent.is_a?(Sketchup::ComponentDefinition)
            cd = ent
        else
            cd = MSketchyPhysics3.get_definition(ent)
        end
        realBounds = Geom::BoundingBox.new
        # Calculate the real bounding box of the entities in the component.
        cd.entities.each { |de| realBounds.add(de.bounds) }
        # Desired center.
        center = Geom::Point3d.new(0,0,0)
        # If not already centred.
        if realBounds.center != center
            # Save original axis.
            c = realBounds.center
            orig = Geom::Point3d.new(-c.x, -c.y, -c.z)
            @@origAxis[cd.entityID] = orig
            # Transform all the entities to be around the new center.
            cd.entities.transform_entities(Geom::Transformation.new(center-realBounds.center), cd.entities.to_a)
            cd.invalidate_bounds if cd.respond_to?(:invalidate_bounds)
            # Move each instance of this component to account for the entities moving inside the component.
            cd.instances.each { |ci|
                newCenter = realBounds.center.transform(ci.transformation)
                matrix = ci.transformation.to_a
                matrix[12..14] = newCenter.to_a
                ci.move! Geom::Transformation.new(matrix)
            }
        end
    end

    #~ def copyAndKick(grp, pos = nil, kick = nil)
        #~ kick= [0, 0, kick.to_f] unless kick.is_a?(Array)

        #~ grp=Sketchup.active_model.add_instance(ogrp.definition,ogrp.transformation)

        #~ @tempObjects.push(grp)
        #~ grp.material=ogrp.material
        #~ grp.name="__copy"
        #~ grp.set_attribute( 'SPOBJ', 'shape',ogrp.get_attribute( 'SPOBJ', 'shape', nil))
        #~ collisions=dumpGroupCollision(grp,0,extractScaleFromGroup(grp)*(grp.transformation.inverse))

        #~ if(!collisions.empty?)
            #~ if(pos!=nil)
                #~ xform=Geom::Transformation.new(pos)
            #~ else
                #~ xform=nil
            #~ end
            #~ body=createBodyFromCollision(grp,collisions,xform);

            #~  MSketchyPhysics3::NewtonServer.addImpulse(body,kick.to_a.pack('f*'),grp.transformation.origin.to_a.pack('f*'))
        #~ end


            #~ if(grp.valid?)
                #~ newgrp=emitGroup(grp,value)
                #~ if(newgrp!=nil) #sucessfully copied?
                    #~ rate=grp.get_attribute('SPOBJ',"emitterrate",10)
                    #~ grp.set_attribute('SPOBJ',"lastemissionframe",@@frame)
                    #~ lifetime=grp.get_attribute('SPOBJ',"lifetime",0).to_f
                    #~ if(lifetime!=nil && lifetime>0)
                        #~ #puts "dying obj"+lifetime.to_s
                        #~ #newgrp.set_attribute('SPOBJ',"diesatframe",nil)
                        #~ @dyingObjects.push([newgrp,@@frame+lifetime])
                    #~ end

                #~ end
            #~ end

    #~ end

    def destroyTempObject(grp)
        address = grp.get_attribute('SPOBJ', 'body', 0).to_i
        return if address.zero?
        body_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
        MSketchyPhysics3::NewtonServer.destroyBody(body_ptr)
    end

    def emitGroup(grp, xform = nil, strength = 15, lifetime = nil, density = nil)
        if strength.is_a?(Numeric)
            kick = grp.transformation.zaxis
            kick.length = strength
        else
            kick = Geom::Vector3d.new(strength.to_a)
        end
        lifetime = grp.get_attribute('SPOBJ', 'lifetime', 0) unless lifetime
        newgrp = copyBody(grp, xform, lifetime, density)
        return unless newgrp
        pushBody(newgrp, kick)
        grp.set_attribute('SPOBJ', 'lastemissionframe', @@frame)
        newgrp
    end

    def setLifetime(grp, lifetime)
        return unless grp.is_a?(Sketchup::Group) || grp.is_a?(Sketchup::ComponentInstance)
        @dyingObjects << [grp, @@frame + lifetime.to_i]
    end

    def newBody(grp, xform = nil, lifetime = 0)
        return unless grp.is_a?(Sketchup::Group) || grp.is_a?(Sketchup::ComponentInstance)
        xform = xform ? Geom::Transformation.new(xform) : grp.transformation
        collisions = dumpGroupCollision(grp, 0, extractScaleFromGroup(grp)*(grp.transformation.inverse))
        return if collisions.empty?
        body = createBodyFromCollision(grp, collisions)
        if lifetime.is_a?(Numeric) and lifetime.to_i > 0
            setLifetime(grp, lifetime.to_i)
        end
        @tempObjects << grp
        grp
    end

    def copyBody(grp, xform = nil, lifetime = 0, density = nil)
        return unless grp.is_a?(Sketchup::Group) || grp.is_a?(Sketchup::ComponentInstance)
        address = grp.get_attribute('SPOBJ', 'body', 0).to_i
        return if address.zero?
        xform = xform ? Geom::Transformation.new(xform) : grp.transformation
        newgrp = Sketchup.active_model.entities.add_instance(MSketchyPhysics3.get_definition(grp), xform)
        newgrp.material = grp.material
        #newgrp.make_unique
        shape = grp.get_attribute('SPOBJ', 'shape', nil)
        newgrp.set_attribute('SPOBJ', 'shape', shape)
        unless density.is_a?(Numeric)
            density = grp.get_attribute('SPOBJ', 'density', 0.2)
            newgrp.set_attribute('SPOBJ', 'density', density)
        end
        collisions = dumpGroupCollision(newgrp, 0, extractScaleFromGroup(newgrp)*(xform.inverse))
        if collisions.empty?
            newgrp.erase! if newgrp.valid?
            return
        end
        newbody = createBodyFromCollision(newgrp, collisions)
        if lifetime.is_a?(Numeric) and lifetime.to_i > 0
            setLifetime(newgrp, lifetime.to_i)
        end
        @tempObjects << newgrp
        newgrp
    end

    def pushBody(grp, strength)
        return unless strength
        return unless grp.is_a?(Sketchup::Group) || grp.is_a?(Sketchup::ComponentInstance)
        address = grp.get_attribute('SPOBJ', 'body', 0).to_i
        return if address.zero?
        body_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
        if strength.is_a?(Numeric)
            return if strength.zero?
            kick = grp.transformation.zaxis
            kick.length = strength
        else
            kick = Geom::Vector3d.new(strength.to_a)
        end
        MSketchyPhysics3::NewtonServer.addImpulse(body_ptr, kick.to_a.pack('f*'), grp.transformation.origin.to_a.pack('f*'))
    end

    def dumpCollision
        Sketchup.active_model.entities.each { |ent|
            next unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
            if ent.attribute_dictionary('SPWATERPLANE')
                density = ent.get_attribute('SPWATERPLANE', 'density', 1.0)
                linearViscosity = ent.get_attribute('SPWATERPLANE', 'linearViscosity', 1.0)
                angularViscosity = ent.get_attribute('SPWATERPLANE', 'angularViscosity', 1.0)
                current = ent.get_attribute('SPWATERPLANE', 'current', [0,0,0])
                xform = ent.transformation
                plane = Geom.fit_plane_to_points(xform.origin, xform.origin+xform.xaxis, xform.origin+xform.yaxis)
                MSketchyPhysics3::NewtonServer.setupBouyancy(plane.to_a.pack('f*'),
                    [0.0+current[0], 0.0+current[1], -9.8+current[2]].pack('f*'),
                    [density, linearViscosity, angularViscosity].pack('f*'))
            end
            unless ent.get_attribute('SPOBJ', 'ignore', false)
                resetAxis(ent)
                collisions = dumpGroupCollision(ent, 0, extractScaleFromGroup(ent)*(ent.transformation.inverse))
                createBodyFromCollision(ent, collisions) unless collisions.empty?
            end
        }
    end

    def createBodyFromCollision(group, collisions, newXform = nil)
        id = @dynamicObjectList.size
        bDynamic = group.get_attribute('SPOBJ', 'static', false) ? 0 : 1
        collisions.flatten!
        xform = newXform ? Geom::Transformation.new(newXform) : group.transformation
        # Figure out the scaling of the xform.
        scale = [(Geom::Vector3d.new(1.0, 0, 0).transform!(xform)).length,
                 (Geom::Vector3d.new(0, 1.0, 0).transform!(xform)).length,
                 (Geom::Vector3d.new(0, 0, 1.0).transform!(xform)).length]
        # Find the real size of the bounding box and offset to center.
        bb = MSketchyPhysics3.get_definition(group).bounds
        size = [bb.width*scale[0], bb.height*scale[1], bb.depth*scale[2]]
        tt = Geom::Transformation.new
        density = group.get_attribute('SPOBJ', 'density', 0.2)
        body = MSketchyPhysics3::NewtonServer.createBody(
            id, collisions.pack('L*'),
            collisions.size, bDynamic, size.pack('f*'),
            xform.to_a.pack('f*'), density
        )
        # Save body in obj for later reference.
        group.set_attribute('SPOBJ', 'body', body.to_i)
        group.set_attribute('SPOBJ', 'savedScale', extractScaleFromGroup(group).to_a)
        if group.get_attribute('SPOBJ', 'showgeometry', false)
            showCollision(group, body)
        end

        updateEmbeddedGeometry(group, body)
        jnames = JointConnectionTool.getParentJointNames(group)

        @allJointChildren.push(group) unless jnames.empty?

        # Set freeze if needed
        s = group.get_attribute('SPOBJ', 'frozen', false)
        MSketchyPhysics3::NewtonServer.bodySetFreeze(body, s ? 1 : 0)
        if group.get_attribute('SPOBJ', 'noautofreeze', false)
            # Hack! to force unfreeze of body
            MSketchyPhysics3::NewtonServer.setBodyMagnetic(body, 1)
            MSketchyPhysics3::NewtonServer.setBodyMagnetic(body, 0)
            # hack!
        end
        if (group.get_attribute('SPOBJ', 'magnet', false) &&
            group.get_attribute('SPJOINT', 'type', nil) == nil)
            #strength = group.get_attribute('SPOBJ', 'strength', 0.0)
            #puts strength
            force = MSketchyPhysics3::NewtonServer.addForce(body, 0.0)
            #puts force
            group.set_attribute('SPOBJ', '__force', force.to_i)
            @allForces << group
        end
        if (group.get_attribute('SPOBJ', 'thruster', false) &&
            group.get_attribute('SPJOINT', 'type', nil) == nil)
            # Hack! to force unfreeze of body
            MSketchyPhysics3::NewtonServer.setBodyMagnetic(body, 1)
            MSketchyPhysics3::NewtonServer.setBodyMagnetic(body, 0)
            # hack!
            @allThrusters << group
        end
        if (group.get_attribute('SPOBJ', 'tickable', false) &&
            group.get_attribute('SPJOINT', 'type', nil) == nil)
            @allTickables << group
            # Ensure it ticks right away.
            group.set_attribute('SPOBJ', 'nexttickframe', 0)
        end
        if group.get_attribute('SPOBJ', 'touchable', false)
            MSketchyPhysics3::NewtonServer.bodySetMaterial(body, 1)
            MSketchyPhysics3::NewtonServer.setBodyCollideCallback(body, MSketchyPhysics3::NewtonServer::COLLIDE_CALLBACK)
            group.set_attribute('SPOBJ', 'lasttouchframe', 0)
        end
        if (group.get_attribute('SPOBJ', 'materialid', false) &&
            group.get_attribute('SPJOINT', 'type', nil) == nil)
            matid = group.get_attribute('SPOBJ', 'materialid', 0)
            #puts ["matid", matid]
            MSketchyPhysics3::NewtonServer.bodySetMaterial(body, matid.to_i)
        end
        if (group.get_attribute('SPOBJ', 'emitter', false) &&
            group.get_attribute('SPJOINT', 'type', nil) == nil)
            group.set_attribute('SPOBJ',"lastemissionframe",0)
            @allEmitters << group
        end
        if group.get_attribute('SPOBJ', 'magnetic', false)
            MSketchyPhysics3::NewtonServer.setBodyMagnetic(body, 1)
        end
        s = group.get_attribute('SPOBJ', 'nocollison', false)
        MSketchyPhysics3::NewtonServer.setBodySolid(body, s ? 0 : 1)
        # Used by touchable etc.
        @bodyToGroup[body.to_i] = group
        boxCenter = MSketchyPhysics3.get_definition(group).bounds.center.transform(extractScaleFromGroup(group))
        MSketchyPhysics3::NewtonServer.setBodyCenterOfMass(body, boxCenter.to_a.pack('f*'))
        # Used in update to lookup object.
        @dynamicObjectList << group
        # Used to lookup scale.
        scale = group.get_attribute('SPOBJ', 'savedScale')
        @saved_scale[group.entityID] = scale if scale
        # Clear some temporary variables.
        group.set_attribute('SPOBJ', '__lookAtJoint', nil)
        @simulationContext.createBody(group, body)
        # Save position of all objects for reset.
        @dynamicObjectBodyRef << body
        body
    end

    def dumpGroupCollision(group, depth, parentXform)
        return [] if group.get_attribute('SPOBJ', 'ignore', false)
        xform = parentXform*group.transformation
        shape = group.get_attribute( 'SPOBJ', 'shape', nil)
        if shape == 'staticmesh' || group.get_attribute('SPOBJ', 'staticmesh', false)
            return [createStaticMeshCollision(group)]
        end
        if shape.nil? || shape == 'compound'
            groupCollisions = []
            MSketchyPhysics3.get_entities(group).each { |ent|
                if ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
                    groupCollisions << dumpGroupCollision(ent, depth+1, xform)
                end
            }
            return groupCollisions unless groupCollisions.empty?
        end
        # If still nil make this it default shape.
        shape = 'box' unless shape
        # Figure out the scaling of the xform.
        scale = [(Geom::Vector3d.new(1.0,0,0).transform!(xform)).length,
                 (Geom::Vector3d.new(0,1.0,0).transform!(xform)).length,
                 (Geom::Vector3d.new(0,0,1.0).transform!(xform)).length]
        # Find the real size of the bounding box and offset to center.
        bb = MSketchyPhysics3.get_definition(group).bounds
        size = [bb.width*scale[0], bb.height*scale[1], bb.depth*scale[2]]
        center = [bb.center.x*scale[0], bb.center.y*scale[1], bb.center.z*scale[2]]
        center = Geom::Transformation.new(center)
        noscale = Geom::Transformation.new(xform.xaxis, xform.yaxis, xform.zaxis, xform.origin)
        finalXform = noscale*center
        verts = []
        if shape == 'convexhull'
          # fill with convex hull verts
          verts = createConvexHullVerts(group)
          finalXform = xform
          return [] if verts.size < 4
        end
        @allCollisionEntities << group
        # if convexhull
        col = MSketchyPhysics3::NewtonServer.createCollision(
            shape,size.pack('f*'),
            finalXform.to_a.pack('f*'),
            verts.to_a.pack('f*')
        )
        return [col.to_i]
    end

    def createConvexHullVerts(group)
        verts = [0] #0 is placeholder for vert count.
        MSketchyPhysics3.get_entities(group).each { |ent|
            next unless ent.is_a?(Sketchup::Face)
            ent.vertices.each { |v|
                verts = verts + v.position.to_a
            }
        }
        verts[0] = (verts.size-1)/3
        return verts
    end

    def createStaticMeshCollision(group)
        tris = []
        MSketchyPhysics3.get_entities(group).each { |ent|
            next unless ent.is_a?(Sketchup::Face)
            ent.mesh.polygons.each_index { |pi|
                ent.mesh.polygon_points_at( pi+1 ).each { |pt|
                    tris = tris + pt.to_a
                }
            }
        }
        MSketchyPhysics3::NewtonServer.createCollisionMesh(tris.to_a.pack('f*'), tris.size/9).to_i
    end

    def showCollision(group, body, bEmbed = false)
        unless @collisionBuffer
            #@collisionBuffer = Array.new.fill(255.chr, 0..400*1024).join
            if RUBY_VERSION =~ /1.8/
              @collisionBuffer = (0.chr*4*400*256).to_ptr
            else
              @collisionBuffer = 0.chr*4*400*256
            end
        end
        if bEmbed
            colGroup = MSketchyPhysics3.get_entities(group).add_group
        else
            colGroup = Sketchup.active_model.entities.add_group
        end
        faceCount = MSketchyPhysics3::NewtonServer.getBodyCollision(body, @collisionBuffer, @collisionBuffer.size)
        puts "Read back collision #{faceCount} faces."
        cb = RUBY_VERSION =~ /1.8/ ? @collisionBuffer.to_a("F400") : @collisionBuffer.unpack('F*')
        pos = 0
        scale = Sketchup.active_model.get_attribute('SPSETTINGS', 'worldscale', 9.0).to_f
        while faceCount > 0
            count = cb.shift
            points = []
            while count > 0
                points << [cb.shift*scale, cb.shift*scale, cb.shift*scale]
                count -= 3
            end
            #puts points.inspect
            f = MSketchyPhysics3.get_entities(colGroup).add_face(points) if points.size > 0
            f.erase! if f.valid?
            faceCount -= 1
        end
        colGroup.set_attribute('SPOBJ', 'ignore', true)
        colGroup.set_attribute('SPOBJ', 'EmbeddedGeometryObject', true)
        colGroup.transform!(group.transformation.inverse) if bEmbed
        @tempObjects << colGroup
        colGroup
    end

    def updateEmbeddedGeometry(group, body)
        cd = MSketchyPhysics3.get_definition(group)
        cd.entities.each { |e|
            e.erase! if e.get_attribute('SPOBJ', 'EmbeddedGeometryObject', false)
        }
        if group.get_attribute('SPOBJ', 'showcollision', false)
            showCollision(group, body, true)
        end
    end

    def findGroupNamed(name)
        name = name.downcase
        @dynamicObjectList.each_index { |di|
            return @dynamicObjectList[di] if @dynamicObjectList[di].name.downcase == name
        }
        puts "Didn't find body #{name}" if $debug
        nil
    end

    def findBodyNamed(name)
        name = name.downcase
        @dynamicObjectList.each_index { |di|
            return @dynamicObjectBodyRef[di] if @dynamicObjectList[di].name.downcase == name
        }
        puts "Didn't find body #{name}" if $debug
        nil
    end

    def findEntityWithID(id)
        @allCollisionEntities.each { |ent|
            puts ent.entityID.to_s+"=="+id.to_s if $debug
            return ent if ent.entityID == id
        }
        puts "Didn't find entity #{id}" if $debug
        nil
    end

    def findBodyWithID(id)
        @dynamicObjectList.each_index { |di|
            puts @dynamicObjectList[di].entityID.to_s+"=="+id.to_s if $debug
            return @dynamicObjectBodyRef[di] if @dynamicObjectList[di].entityID == id
        }
        puts "Didn't find body #{id}" if $debug
        nil
    end

    def findBodyFromInstance(componentInstance)
        @dynamicObjectList.each_index { |di|
            return @dynamicObjectBodyRef[di] if @dynamicObjectList[di] == componentInstance
        }
        nil
    end

    def findJointNamed(name)
        @allJoints.each { |j|
            return j if j.get_attribute('SPJOINT', 'name', 'none') == name
        }
        nil
    end


    @@autoExplodeInstanceObserver = nil

    class AutoExplodeInstanceObserver
        def onComponentInstanceAdded(definition, instance)
            puts [definition, instance]
            definition.remove_observer(@@autoExplodeInstanceObserver)
            UI.start_timer(0.25, false){
                #ents = definition.instances[0].explode
                SketchyPhysicsClient.openComponent(definition.instances[0])
            }
        end
    end

    def self.physicsSafeCopy
        ents = Sketchup.active_model.selection
        cd = Sketchup.active_model.definitions.add
        unless @@autoExplodeInstanceObserver
            @@autoExplodeInstanceObserver = AutoExplodeInstanceObserver.new
        end
        cd.add_observer(@@autoExplodeInstanceObserver)
        ents.each { |ent|
            next unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
            resetAxis(ent)
            grp = cd.entities.add_instance(MSketchyPhysics3.get_definition(ent), ent.transformation)
        }
        resetAxis(cd)
        Sketchup.active_model.place_component(cd)
        return

        prefix = "_" + rand(10000).to_s
        newGrps = []
        ents.each { |ent|
            next unless ent.is_a?(Sketchup::Group)
            #ent.make_unique
            newGrps << ent
            resetAxis(ent)
            MSketchyPhysics3::Group.get_joints(ent).each { |j|
                # Rename joint
                #j.make_unique
                newname = j.get_attribute('SPJOINT', 'name', nil)+prefix
                j.set_attribute('SPJOINT', 'name', newname)
                #puts "renamed #{newname}"
            }
            renamedconnections = []
            MSketchyPhysics3::Group.get_connections(ent).each { |c|
                # Rename joint
                renamedconnections.push(c+prefix) if c
            }
            #puts "renamed connections #{renamedconnections.inspect}"
            ent.set_attribute('SPOBJ', 'parentJoints', renamedconnections) if renamedconnections.length > 0
        }
    end

    def self.openComponent(group)
        ents = group.explode
        prefix = "_" + rand(10000).to_s
        ents.each { |ent|
            if ent.is_a?(Sketchup::Group)
                #ent.make_unique
                resetAxis(ent)
                MSketchyPhysics3::Group.get_joints(ent).each { |j|
                    # Rename joint
                    #j.make_unique
                    newname = j.get_attribute('SPJOINT', 'name', nil)+prefix
                    j.set_attribute('SPJOINT', 'name', newname)
                    #puts "renamed #{newname}"
                }
                renamedconnections = []
                MSketchyPhysics3::Group.get_connections(ent).each { |c|
                    #puts "rename connection"
                    renamedconnections.push(c+prefix) if c
                }
                #puts "renamed connections #{renamedconnections.inspect}"
                ent.set_attribute('SPOBJ', 'parentJoints', renamedconnections) if renamedconnections.length > 0
            end
        }
    end

    def self.initDirectInput
        MSketchyPhysics3::JoyInput.initInput
    end

    def freeDirectInput
        MSketchyPhysics3::JoyInput.freeInput
    end

    def readJoystick
        MSketchyPhysics3::JoyInput.readJoystick(@joyDataBuffer)
    end

    def setFrameRate(rate)
        @frameRate = rate.to_i
    end

    private

    def handle_operation(message = nil, &block)
        block.call
        true
    rescue Exception => e
        @error = message ? "#{message}\nException:\n  #{e}\nLocation:\n  #{e.backtrace[0..1].join("\n")}" : e
        SketchyPhysicsClient.safePhysicsReset
        false
    end

    def update_status_text
      Sketchup.status_text = "Frame : #{@frame}    FPS : #{@fps[:val]}    #{@note}"#~ if @mouse_enter
    end

    public

    def focus_control
        dlg = MSketchyPhysics3.control_panel_dialog
        dlg.bring_to_front if dlg
    end

    def initialize
        SketchyPhysics.checkVersion
        model = Sketchup.active_model
        view = model.active_view
        # Buffer used to hold results from reading Joystick
        if RUBY_VERSION =~ /1.8/
          @joyDataBuffer = Array.new.fill(0.0, 0..16).pack('f*').to_ptr
        else
          @joyDataBuffer = 0.chr*4*16
        end
        @@frame = 0
        @frame = 0
        @@bPause = false
        @time = { :start => 0, :end => 0, :last => 0, :sim => 0, :total => 0 }
        @fps = { :val => 0, :update_rate => 10, :last => 0, :change => 0 }
        @note = 'Click and drag to move. Hold SHIFT while dragging to lift.'
        @pause_updated = false
        @animation_stop = false
        @mouse_enter = false
        @error = nil
        @cameraTarget = nil
        @cameraParent = nil
        @savedCameraPosition = nil
        @recordSamples = []
        @dynamicObjectList = []
        @dynamicObjectResetPositions = {}
        @dynamicObjectBodyRef = []
        @allMagnets = []
        @allJoints = []
        @allJointChildren = []
        @allCollisionEntities = []
        @controlledJoints = []
        @tempObjects = []
        @allForces = []
        @allThrusters = []
        @allTickables = []
        @allEmitters = []
        @dyingObjects = []
        @bodyToGroup = {}
        @picked_body = nil
        @magnetLocation = nil
        @mouseX = 0
        @mouseY = 0
        @ctrlDown = false
        @shiftDown = false
        @tabDown = false
        @cursorCount = 0
        @cursorMagnet = nil
        @controllerContext = nil
        @simulationContext = nil
        @bb = Geom::BoundingBox.new
        @drag = {
            :line_width     => 2,
            :line_stipple   => '',
            :point_size     => 15,
            :point_style    => 4,
            :point_color    => Sketchup::Color.new(0,0,0),
            :line_color     => Sketchup::Color.new(255,0,0)
        }
        @cursor_id = 671
        @@origAxis = {}
        @last_drag_frame = 0
        @pick_drag_enabled = true
        @clicked_body = nil
        @overwrite_check = nil
        @saved_scale = {}
        @collisionBuffer = nil
        $sketchyPhysicsToolInstance = self
    end

    attr_reader :bb

    # Set cursor id.
    # @param [Symbol, String, Fixnum] id
    # @return [Boolean] success
    def setCursor(id = :hand)
        if id.is_a?(String) or id.is_a?(Symbol)
          id = MSketchyPhysics3::CURSORS[id.to_s.downcase.gsub(' ', '_').to_sym]
          return false unless id
        end
        @cursor_id = id.to_i
        true
    end

    # Get cursor id.
    # @return [Fixnum]
    def getCursor(id)
        @cursor_id
    end

    # Enable/Disable drag tool.
    # @param [Boolean] state
    def pick_drag_enabled=(state)
        @pick_drag_enabled = state ? true : false
    end

    # Determine whether the drag tool is enabled.
    # @return [Boolean]
    def pick_drag_enabled?
        @pick_drag_enabled
    end

    def activate
        model = Sketchup.active_model
        view = model.active_view
        # Wrap operations
        op_name = 'SketchyPhysics Simulation'
        if Sketchup.version.to_i > 6
            model.start_operation(op_name, true, false, false)
        else
            model.start_operation(op_name)
        end
        # Close active path
        state = true
        while state
            state = model.close_active
        end
        # Clear selection.
        model.selection.clear
        # Save original positions
        model.entities.each { |ent|
            if ent.is_a?(Sketchup::Group) or ent.is_a?(Sketchup::ComponentInstance)
                @dynamicObjectResetPositions[ent.entityID] = ent.transformation
            end
        }
        # Initialize Newton Server
        MSketchyPhysics3::NewtonServer.init()
        explodeList = []
        model.entities.each { |ent|
            explodeList << ent if ent.get_attribute('SPOBJ', 'component', false)
        }
        @cursorMagnet = MSketchyPhysics3::NewtonServer.magnetAdd([0,0,0].to_a.pack('f*'))
        @allMagnets << @cursorMagnet
        if $spExperimentalFeatures
            @controllerContext = MSketchyPhysics3::SP3xControllerContext.new
        else
            @controllerContext = MSketchyPhysics3::ControllerContext.new
        end
        @simulationContext = SP3xSimulationContext.new(model)
        $curPhysicsSimulation = @simulationContext
        explodeList.each { |ent| openComponent(ent) }
        checkModelUnits
        # Parse and set physics constants.
        dict = model.attribute_dictionary('SPSETTINGS')
        unless dict
            MSketchyPhysics3.setDefaultPhysicsSettings
            dict = model.attribute_dictionary('SPSETTINGS')
        end
        if dict
            dict.each_pair { |key, value|
                MSketchyPhysics3::NewtonServer.newtonCommand('set', "#{key} #{value}")
            }
        end
        @frameRate = model.get_attribute('SPSETTINGS', 'framerate', 3)
        state = handle_operation { dumpCollision }
        return unless state
        # Find joints
        puts 'Finding joints' if $debug
        model.entities.each { |ent|
            next unless ent.is_a?(Sketchup::Group)
            type = ent.get_attribute('SPJOINT', 'type', nil)
            if type == 'magnet'
                strength = ent.get_attribute('SPJOINT', 'strength', 0.0)
                range = ent.get_attribute('SPJOINT', 'range', 0.0)
                falloff = ent.get_attribute('SPJOINT', 'falloff', 0.0)
                duration = ent.get_attribute('SPJOINT', 'duration', 0)
                delay = ent.get_attribute('SPJOINT', 'delay', 0)
                rate = ent.get_attribute('SPJOINT', 'rate', 0)
                MSketchyPhysics3::NewtonServer.addGlobalForce(
                    ent.transformation.origin.to_a.pack('f*'),
                    [strength, range, falloff].pack('f*'),
                    duration, delay, rate)
            elsif type != nil
                # Save joints for later processing.
                @allJoints << ent
                puts "Found joint #{ent.entityID}" if $debug
            else
                ent.entities.each { |gent|
                    next unless gent.is_a?(Sketchup::Group)
                    next unless gent.get_attribute('SPJOINT', 'type', nil)
                    gent.set_attribute('SPOBJ', 'body', ent.get_attribute('SPOBJ', 'body', nil))
                    # Save joints for later processing.
                    @allJoints << gent
                }
            end
        }
        # Init control sliders.
        MSketchyPhysics3.initJointControllers
        # Find joint/joint connections. gears.
        @allJoints.each { |joint|
            parents = JointConnectionTool.getParentJointNames(joint)
            next if parents.empty?
            next unless joint.get_attribute('SPJOINT', 'gearjoint', nil)
            #puts "Joint/Joint"
            gname = joint.get_attribute('SPJOINT', 'gearjoint', nil)
            gjoint = findJointNamed(gname)
            if joint.parent.is_a?(Sketchup::ComponentDefinition)
                pgrp = joint.parent.instances[0]
                address = pgrp.get_attribute('SPOBJ', 'body', 0).to_i
                next if address.zero?
                bodya = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
                pina = (pgrp.transformation*joint.transformation).zaxis.to_a
            end
            if gjoint.parent.is_a?(Sketchup::ComponentDefinition)
                pgrp = gjoint.parent.instances[0]
                address = pgrp.get_attribute('SPOBJ', 'body', 0).to_i
                next if address.zero?
                bodyb = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
                pinb = (pgrp.transformation*gjoint.transformation).zaxis.to_a
            end
            ratio = joint.get_attribute('SPJOINT', 'ratio', 1.0)
            gtype = joint.get_attribute('SPJOINT', 'geartype', nil)
            #puts "Making gear #{gtype}"
            if bodya != nil && bodyb != nil && gtype != nil
                jnt = MSketchyPhysics3::NewtonServer.createGear(gtype,
                    pina.pack('f*'), pinb.pack('f*'),
                    bodya, bodyb, ratio)
                if jnt != 0 && joint.get_attribute('SPJOINT', 'GearConnectedCollide', false)
                    jnt_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(jnt.to_i) : FFI::Pointer.new(jnt.to_i)
                    MSketchyPhysics3::NewtonServer.setJointCollisionState(jnt_ptr, 1)
                end
            end
        }
        # Now create joints
        model.selection.clear
        @allJointChildren.each{ |ent|
            jnames = JointConnectionTool.getParentJointNames(ent)
            jnames.each { |jointParentName|
                puts "Connecting foo #{ent} to #{jointParentName}." if $debug
                joint = findJointNamed(jointParentName)
                next unless joint
                jointType = joint.get_attribute('SPJOINT', 'type', nil)
                puts "Created #{joint.get_attribute('SPJOINT', 'name', 'error')}" if $debug
                defaultJointBody = nil
                jointChildBody = findBodyWithID(ent.entityID)
                # TODO. This might not be needed.
                jointChildBody = 0 unless jointChildBody
                if joint.parent.is_a?(Sketchup::ComponentDefinition)
                    pgrp = joint.parent.instances[0]
                    address = pgrp.get_attribute('SPOBJ', 'body', 0).to_i
                    next if address.zero?
                    defaultJointBody = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
                    parentXform = pgrp.transformation
                else
                    parentXform = Geom::Transformation.new
                end
                xform = parentXform*joint.transformation
                limits = []
                limits << joint.get_attribute('SPJOINT', 'min', 0)
                limits << joint.get_attribute('SPJOINT', 'max', 0)
                limits << joint.get_attribute('SPJOINT', 'accel', 0)
                limits << joint.get_attribute('SPJOINT', 'damp', 0)
                limits << joint.get_attribute('SPJOINT', 'rate', 0)
                limits << joint.get_attribute('SPJOINT', 'range', 0)
                limits << joint.get_attribute('SPJOINT', 'breakingForce', 0)
                controller = joint.get_attribute('SPJOINT', 'controller', nil)
                controller = nil if controller.is_a?(String) && controller.strip.empty?
                # Convert if its a 2.0 joint.
                MSketchyPhysics3.convertControlledJoint(joint) if controller
                controller = joint.get_attribute('SPJOINT', 'Controller', nil)
                controller = nil if controller.is_a?(String) && controller.strip.empty?
                # Allow conversion of old and new style joints
                unless controller
                    jointType = 'hinge' if jointType == 'servo'
                    jointType = 'slider' if jointType == 'piston'
                else
                    if jointType == 'hinge'
                        jointType = 'servo'
                        if limits[0].zero? && limits[1].zero?
                            limits[0] = -180.0
                            limits[1] = 180.0
                        end
                    elsif jointType == 'slider'
                        jointType = 'piston'
                    end
                    #puts "Promoted joint #{jointType}" if $debug
                end
                #puts "Joint parents: #{JointConnectionTool.getParentJointNames(joint).inspect}"
                # detect joint to joint connection
                # detect parent body for each joint
                # determine gear type based on joint types
                # get ratio (where?)
                pinDir = xform.zaxis.to_a+xform.yaxis.to_a
                # Old style gears. REMOVE.
                if %w(gear pulley wormgear).include?(jointType)
                    #puts "Gear parent: #{defaultJointBody.class}, child: #{jointChildBody}"
                    ratio = joint.get_attribute('SPJOINT', 'ratio', 1.0)
                    jnt = MSketchyPhysics3::NewtonServer.createGear(jointType,
                        pinDir.pack('f*'), pinDir.pack('f*'),
                        jointChildBody, defaultJointBody, ratio)
                else
                    jnt = MSketchyPhysics3::NewtonServer.createJoint(jointType,
                        xform.origin.to_a.pack('f*'),
                        pinDir.pack('f*'),
                        jointChildBody, defaultJointBody,
                        limits.pack('f*'))
                    #puts joint.get_attribute('SPJOINT', 'ConnectedCollide', 0)
                    # Set collision between connected bodies.
                    if jnt != 0
                        joint.set_attribute('SPJOINT', 'jointPtr', jnt.to_i)
                        if jnt != 0 && joint.get_attribute('SPJOINT', 'ConnectedCollide', false)
                            jnt_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(jnt.to_i) : FFI::Pointer.new(jnt.to_i)
                            MSketchyPhysics3::NewtonServer.setJointCollisionState(jnt_ptr, 1)
                        end
                        # Handle controlled joints.
                        # controller = joint.get_attribute('SPJOINT', 'controller', '')
                        if controller
                            @controlledJoints << joint
                            value = limits[0] + (limits[1]-limits[0])/2
                            value = 0.5 # utb 0.5 jan 7.
                            #MSketchyPhysics3::createController(controller, value, 0.0, 1.0)
                            #puts 'Controlled joint'
                        end
                    end
                end
            }
        }
        #handleAttachments
        setupCameras
        state = handle_operation('onStart error:'){
            @simulationContext.doOnStart
        }
        return unless state
        MSketchyPhysics3.showControlPanel
        # Initialize timers
        t = Time.now
        @time[:start] = t
        @time[:last] = t
        @fps[:last] = t
        view.animation = self
    rescue Exception => e
        @error = "An error occurred while starting simulation:\n#{e}\n#{e.backtrace.first}"
        SketchyPhysicsClient.safePhysicsReset
    end

    def deactivate(view)
        model = Sketchup.active_model
        model.active_view.animation = nil
        begin
            @simulationContext.doOnEnd
        rescue Exception => e
            @error = "onEnd error:\nException:\n  #{e}\nLocation:\n  #{e.backtrace.first}" unless @error
        end
        $sketchyPhysicsToolInstance = nil
        $curPhysicsSimulation = nil
        if @savedCameraPosition
            model.active_view.camera = @savedCameraPosition
            @savedCameraPosition = nil
        end
        # Erase all objects added during simulation.
        @tempObjects.each { |ent| ent.erase! if ent.valid? }
        # Reset original axis in case the abort_operation fails.
        model.definitions.each { |cd|
            orig = @@origAxis[cd.entityID]
            next unless orig
            cd.entities.transform_entities(Geom::Transformation.new(orig), cd.entities.to_a)
            cd.invalidate_bounds if cd.respond_to?(:invalidate_bounds)
            pt = Geom::Point3d.new(0,0,0)
            cd.instances.each { |ci|
                rel_center = orig.transform(ci.transformation)
                matrix = ci.transformation.to_a
                matrix[12..14] = rel_center.to_a
                ci.move! Geom::Transformation.new(matrix)
            }
        }
        @@origAxis.clear
        model.definitions.purge_unused
        model.materials.purge_unused
        # Commit operation. Use abort_operation to undo most operations done
        # during simulation.
        model.abort_operation
        # Reset positions
        model.entities.each { |ent|
            if ent.is_a?(Sketchup::Group) or ent.is_a?(Sketchup::ComponentInstance)
                tra = @dynamicObjectResetPositions[ent.entityID]
                next unless tra
                ent.move! tra
            end
        }
        # Destroy Newton world
        MSketchyPhysics3::NewtonServer.stop
        # Free direct input
        freeDirectInput
        # Clear big variables.
        @joyDataBuffer = nil
        @cameraTarget = nil
        @cameraParent = nil
        @savedCameraPosition = nil
        @dynamicObjectResetPositions.clear
        @dynamicObjectBodyRef.clear
        @allMagnets.clear
        @allJoints.clear
        @allJointChildren.clear
        @allCollisionEntities.clear
        @controlledJoints.clear
        @tempObjects.clear
        @allForces.clear
        @allThrusters.clear
        @allTickables.clear
        @allEmitters.clear
        @dyingObjects.clear
        @bodyToGroup.clear
        @picked_body = nil
        @magnetLocation = nil
        @bb.clear
        @cursorMagnet = nil
        @controllerContext = nil
        @simulationContext = nil
        @saved_scale.clear
        @collisionBuffer = nil
        # Refresh view
        model.active_view.invalidate
        # Show info
        if @error
            msg = "SketchyPhysics Simulation was aborted due to an error!\n#{@error}\n\n"
            puts msg
            UI.messagebox(msg)
        else
            @time[:end] = Time.now
            @time[:total] = @time[:end] - @time[:start]
            @time[:sim] += @time[:end] - @time[:last] unless @@bPause
            average_fps = (@time[:sim].zero? ? 0 : (@frame / @time[:sim]).round)
            puts 'SketchyPhysics Simulation Results:'
            printf("  frames          : %d\n", @frame)
            printf("  average FPS     : %d\n", average_fps)
            printf("  simulation time : %.2f seconds\n", @time[:sim])
            printf("  total time      : %.2f seconds\n\n", @time[:total])
        end
        MSketchyPhysics3.closeControlPanel
        unless @recordSamples.empty?
            result = UI.messagebox('Save animation?', MB_YESNO, 'Save Animation')
            case result
            when 6 #yes
                model.start_operation('Save Animation')
                @dynamicObjectList.each_index { |ci|
                    ent = @dynamicObjectList[ci]
                    if @recordSamples[ci] != nil && @dynamicObjectList[ci] != nil && @dynamicObjectList[ci].valid?
                        @dynamicObjectList[ci].set_attribute('SPTAKE', 'samples', @recordSamples[ci].inspect)
                    end
                }
                model.commit_operation
                # brand each group.
                # save anim data in group.
                # save anim data in model attributes.
                # compress and embed animation
            when 7 #no
            when 2 #cancel
            end
        end
        # Clear some more variables
        @error = nil
        @recordSamples.clear
        @dynamicObjectList.clear
    end

    def handleOnTouch(bodies, speed, pos)
        grpa = @bodyToGroup[bodies[0].to_i]
        grpb = @bodyToGroup[bodies[1].to_i]
        state = handle_operation('onTouch error:'){
            @simulationContext.doTouching(grpa, grpb, speed, pos)
            @simulationContext.doTouching(grpb, grpa, speed, pos)
        }
        return false unless state
        bodies.each { |b|
            grp = @bodyToGroup[b.to_i]
            next unless grp
            $curEvalGroup = grp
            # Kinda klugy, loop should be rewritten.
            if b == bodies[0]
                $curEvalTouchingGroup = @bodyToGroup[bodies[1].to_i]
            else
                $curEvalTouchingGroup = @bodyToGroup[bodies[0].to_i]
            end
            func = grp.get_attribute('SPOBJ', 'ontouch', '').to_s
            next if func == ''
            last = grp.get_attribute('SPOBJ', 'lasttouchframe', 0)
            rate = grp.get_attribute('SPOBJ', 'touchrate', 0).to_i
            # Too early?
            next if (@@frame-last) < rate
            state = handle_operation('onTouch error:'){
                eval(func, @curControllerBinding)
                grp.set_attribute('SPOBJ', 'lasttouchframe', @@frame)
            }
            # Clean out value.
            #$curEvalTouchingGroup = nil
            return false unless state
        }
        true
    end

    def updateControlledJoints
        MSketchyPhysics3::JoyInput.updateInput
        cbinding = @controllerContext.getBinding(@@frame)
        @curControllerBinding = cbinding
        state = handle_operation('onTick error:'){
            @simulationContext.doOnTick(@@frame)
        }
        return false unless state
        @allTickables.each { |grp|
            $curEvalGroup = grp
            func = grp.get_attribute('SPOBJ', 'ontick', '').to_s.strip
            next if func.empty?
            next_frame = grp.get_attribute('SPOBJ', 'nexttickframe', 0)
            # Too early?
            next if @@frame < next_frame
            state = handle_operation('Tick error:'){
                rate = grp.get_attribute('SPOBJ', 'tickrate', 0).to_i
                result = eval(func, @curControllerBinding)
                if rate.zero? && result.is_a?(Numeric) && result != 0
                    grp.set_attribute('SPOBJ', 'nexttickframe', @@frame + result.to_i)
                else
                    grp.set_attribute('SPOBJ', 'nexttickframe', @@frame + rate)
                end
            }
            return false unless state
        }
        @allForces.each { |grp|
            $curEvalGroup = grp
            strength = grp.get_attribute('SPOBJ', 'strength', 0.0).to_s
            state = handle_operation('Force error:'){
                value = eval(strength, cbinding).to_f
                value = 0.0 unless value.is_a?(Numeric)
                address = grp.get_attribute('SPOBJ', '__force', 0).to_i
                next if address.zero?
                force = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
                MSketchyPhysics3::NewtonServer.setForceStrength(force, value) if force
            }
            return false unless state
        }
        @allThrusters.each { |grp|
            $curEvalGroup = grp
            expression = grp.get_attribute('SPOBJ', 'tstrength', 0.0).to_s
            state = handle_operation('Thruster error:'){
                value = eval(expression, cbinding).to_f
                next unless value.is_a?(Numeric)
                address = grp.get_attribute('SPOBJ', 'body', 0).to_i
                next if address.zero?
                body = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
                MSketchyPhysics3::NewtonServer.bodySetThrust(body, value) if body
            }
            return false unless state
        }
        @allEmitters.each { |grp|
            $curEvalGroup = grp
            # Is it time for this object to dupe itself yet?
            ratestr = grp.get_attribute('SPOBJ', 'emitterrate', 0).to_s
            rate = nil
            state = handle_operation('Emitter Rate error:'){
                rate = eval(ratestr, cbinding)
            }
            return false unless state
            next unless rate.is_a?(Numeric)
            next if rate.zero?
            last = grp.get_attribute('SPOBJ', 'lastemissionframe', 0)
            # Too early?
            next if (@@frame - last) < rate
            expression = grp.get_attribute('SPOBJ', 'emitterstrength', 0.0).to_s
            value = nil
            state = handle_operation('Emitter Strength error:'){
                value = eval(expression, cbinding)
            }
            return false unless state
            next unless value.is_a?(Numeric)
            next if value.zero?
            # TODO: need to check type here.
            #address = grp.get_attribute('SPOBJ', 'body', 0).to_i
            #next if address.zero?
            #body = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
            state = handle_operation('Emitter Copying Group error:'){
                emitGroup(grp, nil, value, nil) if grp.valid?
            }
            return false unless state
        }
        @dyingObjects.each { |grp, lastframe|
            next if @@frame < lastframe
            destroyTempObject(grp) if grp.valid?
            @dyingObjects.delete([grp, lastframe])
            grp.erase! if grp.valid?
        }
        @controlledJoints.each { |joint|
            $curEvalGroup = joint
            expression = joint.get_attribute('SPJOINT', 'Controller', nil)
            value = nil
            if expression
                begin
                  value = eval(expression, cbinding)
                rescue Exception => e
                  puts "Exception in Joint Controller:\nExpression:\n  #{expression}\nException:\n  #{e}\n\n"
                  value = nil
                end
                #return false unless state
            end
            address = joint.get_attribute('SPJOINT', 'jointPtr', 0).to_i
            next if address.zero?
            joint_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
            case joint.get_attribute('SPJOINT', 'type', nil)
            when 'hinge', 'servo'
                next unless value.is_a?(Numeric)
                MSketchyPhysics3::NewtonServer.setJointRotation(joint_ptr, [value].pack('f*'))
            when 'piston', 'slider'
                next unless value.is_a?(Numeric)
                MSketchyPhysics3::NewtonServer.setJointPosition(joint_ptr, [value].pack('f*'))
            when 'motor'
                next unless value.is_a?(Numeric)
                maxAccel = joint.get_attribute('SPJOINT', 'maxAccel', 0)
                accel = value*maxAccel
                MSketchyPhysics3::NewtonServer.setJointAccel(joint_ptr, [accel].pack('f*'))
            when 'gyro'
                next unless value.is_a?(Array) or value.is_a?(Geom::Point3d) or value.is_a?(Geom::Vector3d)
                MSketchyPhysics3::NewtonServer.setGyroPinDir(joint_ptr, value.to_a.pack('f*'))
            end
        }
        true
    end

    def oldupdateControlledJoints
        frame = @@frame
        @controlledJoints.each { |joint|
            controller = joint.get_attribute('SPJOINT', 'controller', '')
            value = nil
            if controller.index('oscillator')
                vals = controller.split(',')
                rate = vals[1].to_f
                inc = (2*3.141592)/rate
                pos = Math.sin(inc*(@@frame))
                MSketchyPhysics3.control_sliders[controller].value = (pos/2.0)+0.5
                value = MSketchyPhysics3.control_sliders[controller].value
            else
                #value = eval(controller, binding)
                value = MSketchyPhysics3.control_sliders[controller].value
            end
            raise 'Controller failure' unless value
            address = joint.get_attribute('SPJOINT', 'jointPtr', 0).to_i
            next if address.zero?
            joint_ptr = RUBY_VERSION =~ /1.8/ ? DL::PtrData.new(address) : FFI::Pointer.new(address)
            case joint.get_attribute('SPJOINT', 'type', nil)
            when 'oscillator'
                rate = joint.get_attribute('SPJOINT', 'rate', 100.0)
                rate /= value
                inc = (2*Math::PI)/rate
                pos = Math.sin(inc*(@@frame))
                MSketchyPhysics3::NewtonServer.setJointPosition(joint_ptr, [pos].pack('f*'))
            when 'servo', 'hinge'
                MSketchyPhysics3::NewtonServer.setJointRotation(joint_ptr, [value].pack('f*'))
            when 'piston', 'slider'
                MSketchyPhysics3::NewtonServer.setJointPosition(joint_ptr,[value].pack('f*'))
            when 'motor'
                maxAccel = joint.get_attribute('SPJOINT', 'maxAccel', 0)
                accel = value*maxAccel
                MSketchyPhysics3::NewtonServer.setJointAccel(joint_ptr, [accel].pack('f*'))
            end
        }
    end

    def setupCameras
        model = Sketchup.active_model
        camera = model.active_view.camera
        @savedCameraPosition = Sketchup::Camera.new(camera.eye, camera.target, camera.up, camera.perspective?, camera.fov)
        desc = model.pages.selected_page.description.downcase if model.pages.selected_page
        return unless desc
        sentences = desc.split('.')
        sentences.each { |l|
            words = l.split(' ')
            if words[0] == 'camera'
                @cameraTarget = findGroupNamed(words[2]) if words[1] == 'track'
                @cameraParent = findGroupNamed(words[2]) if words[1] == 'follow'
            end
        }
    end

    def nextFrame(view)
        @overwrite_check = true
        # Handle simulation play/pause events.
        if @@bPause
            unless @pause_updated
                t = Time.now
                @time[:sim] += t - @time[:last]
                @fps[:change] += t - @fps[:last]
                @pause_updated = true
            end
            view.show_frame
            return true
        end
        if @pause_updated
            t = Time.now
            @time[:last] = t
            @fps[:last] = t
            @pause_updated = false
        end
        # Call onPreFrame, before update takes place.
        state = handle_operation('onPreFrame error:'){
            @simulationContext.doPreFrame
        }
        return false unless state
        # Call onUpdate, just before update takes place.
        state = updateControlledJoints
        return false unless state
        # Update Newton
        MSketchyPhysics3::NewtonServer.requestUpdate(@frameRate)
        cameraPreMoveOffset = view.camera.eye-@cameraParent.bounds.center if @cameraParent
        # Fetch positions for all moving objects.
        if RUBY_VERSION =~ /1.8/
          dat = (0.chr*4*16).to_ptr
        else
          dat = 0.chr*4*16
        end
        outstr = ''
        while(id = MSketchyPhysics3::NewtonServer.fetchSingleUpdate(dat)) != 0xffffff
            matrix = RUBY_VERSION =~ /1.8/ ? dat.to_a('F', 16) : dat.unpack('F*')
            instance = @dynamicObjectList[id]
            if instance && instance.valid?
                dest = Geom::Transformation.new(matrix.to_a)
                # Reapply scaling.
                scale = @saved_scale[instance.entityID]
                if scale
                    upscale = Geom::Transformation.new(scale)
                    dest = dest*upscale
                end
                if $sketchyViewerDialog
                    # Converts from inches to meters.
                    mat = dest*Geom::Transformation.scaling(1/39.3700787401575)
                    mat = mat.to_a
                    mat[12] = mat[12]/39.3700787401575
                    mat[13] = mat[13]/39.3700787401575
                    mat[14] = mat[14]/39.3700787401575
                    outstr += 'x=g_nameToTransform["SV' + instance.entityID.to_s+'"];'
                    outstr += 'if(x!=null) g_nameToTransform["SV'+instance.entityID.to_s+'"].localMatrix='+
                        [mat[0,4],mat[4,4],mat[8,4],mat[12,4]].inspect+';'
                end
                instance.move! dest
                if $spDoRecord
                    matrix = dest.to_a
                    cd = MSketchyPhysics3.get_definition(instance)
                    orig = @@origAxis[cd.entityID]
                    matrix[12..14] = orig.transform(dest).to_a if orig
                    @recordSamples[id] ||= []
                    @recordSamples[id][@@frame] = matrix
                end
            end
        end
        $sketchyViewerDialog.execute_script(outstr) if $sketchyViewerDialog
        # Update camera
        if @cameraTarget and @cameraTarget.valid?
            camera = view.camera
            camera.set(camera.eye, @cameraTarget.bounds.center, Geom::Vector3d.new(0, 0, 1))
        else
            @cameraTarget = nil
        end
        if @cameraParent and @cameraParent.valid?
            camera = view.camera
            dest = @cameraParent.bounds.center + cameraPreMoveOffset
            camera.set(dest, dest+camera.direction, Geom::Vector3d.new(0, 0, 1))
        else
            @cameraParent = nil
        end
        # Call onPostFrame, after update takes place.
        state = handle_operation('onPostFrame error:'){
            @simulationContext.doPostFrame
        }
        return false unless state
        # Update FPS
        if @frame % @fps[:update_rate] == 0
            @fps[:change] += Time.now - @fps[:last]
            @fps[:val] = ( @fps[:change] == 0 ? 0 : (@fps[:update_rate] / @fps[:change]).round )
            @fps[:last] = Time.now
            @fps[:change] = 0
        end
        update_status_text
        # Increment frame
        @@frame += 1
        @frame = @@frame
        view.show_frame
        true
    rescue Exception => e
        puts "nextFrame Error: #{e}\n#{e.backtrace}"
        SketchyPhysicsClient.safePhysicsReset
    end

    def getExtents
      if Sketchup.version.to_i > 6
        Sketchup.active_model.entities.each { |ent|
          @bb.add(ent.bounds)
        }
      end
      @bb
    end

    def stop
        if @overwrite_check
          @animation_stop = true
          @overwrite_check = nil
          Sketchup.active_model.active_view.show_frame
        else
          @error = "It seems current script overwrites some vital SP content. Overwriting is a bad coding habit!"
          UI.start_timer(0.1, false){
            SketchyPhysicsClient.safePhysicsReset
          }
        end
    end

    def onMouseMove(flags, x, y, view)
        @mouseX = x
        @mouseY = y
        return unless @cursorMagnetBody
        ip = Sketchup::InputPoint.new
        ip.pick(view, x, y)
        return unless ip.valid?
        if @picked_body and @picked_body.valid?
            state = handle_operation('onDrag error:'){
                @simulationContext.doOnMouse(:drag, @picked_body, x, y) if @last_drag_frame != @frame
            }
            @last_drag_frame = @frame
            return unless state
            # Project the input point on a plane described by our normal and center.
            #~ line = [view.camera.eye, ip.position]
            #~ plane = [@attachWorldLocation, getKeyState(VK_LSHIFT) ? view.camera.zaxis : Z_AXIS]
            #~ @attachWorldLocation = Geom.intersect_line_plane(line, plane)

            cam = view.camera
            line = [cam.eye, ip.position]
            if getKeyState(VK_LSHIFT)
                normal = view.camera.zaxis
                normal.z = 0
                normal.normalize!
            else
                normal = Z_AXIS
            end
            plane = [@attachWorldLocation, normal]
            vector = cam.eye.vector_to(ip.position)
            theta = vector.angle_between(normal).radians
            if (90 - theta).abs > 1
                pt = Geom.intersect_line_plane(line, plane)
                v = cam.eye.vector_to(pt)
                @attachWorldLocation = pt if cam.zaxis.angle_between(v).radians < 90
            end

            @magnetLocation = @attachWorldLocation
            MSketchyPhysics3::NewtonServer.magnetMove(@cursorMagnet, @magnetLocation.to_a.pack('f*')) if @cursorMagnet
        else
            @picked_body = nil
        end
    end

    def cursorPos
        [@mouseX, @mouseY]
    end

    def onMouseEnter(view)
        @mouse_enter = true
        #focus_control
    end

    def onMouseLeave(view)
        @mouse_enter = false
    end

    def suspend(view)
    end

    def resume(view)
        #focus_control
    end

    def getMenu(menu)
        ph = Sketchup.active_model.active_view.pick_helper
        ph.do_pick @mouseX, @mouseY
        ent = ph.best_picked
        return unless ent.is_a?(Sketchup::Group) or ent.is_a?(Sketchup::ComponentInstance)
        Sketchup.active_model.selection.add(ent)
        menu.add_item('Camera Track'){
            @cameraTarget = ent
            focus_control
        }
        menu.add_item('Camera Follow'){
            @cameraParent = ent
            focus_control
        }
        menu.add_item('Camera Clear'){
            @cameraTarget = nil
            @cameraParent = nil
            focus_control
        }
        #menu.add_item('Copy Body'){ copyBody(ent) }
    end

    def onMButtonDown(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick x,y
        ent = ph.best_picked
        return unless ent.is_a?(Sketchup::Group) or ent.is_a?(Sketchup::ComponentInstance)
        @cameraTarget = ent
        #focus_control
    end

    #def onMButtonUp(flags, x, y, view)
        #focus_control
    #end

    #def onMButtonDoubleClick(flags, x, y, view)
        #focus_control
    #end

    def onRButtonDown(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick x,y
        ent = ph.best_picked
        focus_control
    end

    def onRButtonUp(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick x,y
        ent = ph.best_picked
        focus_control
    end

    def onRButtonDoubleClick(flags, x, y, view)
        focus_control
    end

    def onLButtonDoubleClick(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick x,y
        ent = ph.best_picked
        return unless ent.is_a?(Sketchup::Group) or ent.is_a?(Sketchup::ComponentInstance)
        state = handle_operation('onDoubleClick error:'){
            @simulationContext.doOnMouse(:doubleclick, ent, x, y)
        }
        return unless state
        if MSketchyPhysics3.getKeyState(VK_LSHIFT)
            ip = view.inputpoint(x,y)
            #copyBody(ent)
        else
            #~ direction = ent.transformation.origin-view.camera.eye
            #~ direction.normalize!
            #~ direction[0] *= 3.0
            #~ direction[1] *= 3.0
            #~ direction[2] = 15.0
            #~ kick = direction
            #~ body = findBodyWithID(ent.entityID)
            #~ MSketchyPhysics3::NewtonServer.addImpulse(body, kick.to_a.pack('f*'), ent.transformation.origin.to_a.pack('f*')) if body
        end
        focus_control
    end

    def onLButtonDown(flags, x, y, view)
        model = Sketchup.active_model
        ph = view.pick_helper
        ph.do_pick x,y
        ent = ph.best_picked
        if @cursorMagnetBody.is_a?(Numeric) and @cursorMagnetBody != 0
            MSketchyPhysics3::NewtonServer.bodySetMagnet(@cursorMagnetBody, 0, 0)
            @cursorMagnetBody = nil
            model.selection.clear
        end
        if ent.is_a?(Sketchup::Group) or ent.is_a?(Sketchup::ComponentInstance)
            model.selection.clear
            @clicked_body = ent
            state = handle_operation('onClick error:'){
                @simulationContext.doOnMouse(:click, @clicked_body, x, y)
            }
            return unless state
            if @pick_drag_enabled
                model.selection.add(ent)
                @picked_body = ent
                gd = MSketchyPhysics3.get_entities(ent).parent
                @dynamicObjectList.each_index { |doi|
                    next if @dynamicObjectList[doi] != ent
                    # Transform input point into component space.
                    ip = view.inputpoint x,y
                    cdbounds = MSketchyPhysics3.get_entities(@picked_body)[0].parent.bounds
                    dsize = cdbounds.max - cdbounds.min
                    cmass = Geom::Point3d.new(dsize.to_a)
                    cmass.x/=2; cmass.y/=2; cmass.z/=2;
                    pcenter = Geom::Point3d.new(dsize.y/2, dsize.x/2, dsize.z/2)
                    xlate = Geom::Transformation.new(pcenter).inverse

                    ip = view.inputpoint x,y
                    tra = @picked_body.transformation
                    @attachPoint = ip.position.transform(tra.inverse)

                    @attachWorldLocation = ip.position # Used to calc movement planes.
                    MSketchyPhysics3::NewtonServer.bodySetMagnet(@dynamicObjectBodyRef[doi], @cursorMagnet, @attachPoint.to_a.pack('f*'))
                    @cursorMagnetBody = @dynamicObjectBodyRef[doi]
                }
                @last_drag_frame = @frame
            end
            onMouseMove(flags, x, y, view) # force magnet location to update.
        end
        focus_control
    end

    def onLButtonUp(flags, x, y, view)
        if @clicked_body
            state = handle_operation('onUnclick error:'){
                @simulationContext.doOnMouse(:unclick, @clicked_body, x, y) if @clicked_body.valid?
            }
            @clicked_body = nil
        end
        @picked_body = nil
        @magnetLocation = nil
        if @cursorMagnetBody
            MSketchyPhysics3::NewtonServer.bodySetMagnet(@cursorMagnetBody, nil, nil)
            @cursorMagnetBody = nil
            Sketchup.active_model.selection.clear
        end
        return unless state
        focus_control
    end

    def draw(view)
        @bb.clear
        if @picked_body && @magnetLocation && @picked_body.valid?
            pt1 = @attachPoint.transform(@picked_body.transformation)
            pt2 = @magnetLocation
            @bb.add(pt1, pt2)
            view.line_width = @drag[:line_width]
            view.line_stipple = @drag[:line_stipple]
            view.drawing_color = @drag[:line_color]
            view.draw_line(pt1, pt2)
            view.line_stipple = ''
            view.draw_points(pt1, @drag[:point_size], @drag[:point_style], @drag[:point_color])
            if getKeyState(VK_LSHIFT)
                view.drawing_color = 'blue'
                view.line_width = 2
                view.line_stipple = '-'
                tp = @magnetLocation.clone
                tp.z = 0
                @bb.add(tp)
                view.draw_line(tp, @magnetLocation)
            end
        end
        if @animation_stop
            view.animation = self
            @animation_stop = false
        end
        return unless @simulationContext
        @simulationContext.drawQueue.each { |data|
            view.drawing_color = data[2]
            view.line_width = data[3]
            view.line_stipple = data[4]
            if data[5] == 0 # 2D
                view.draw2d(data[0], data[1])
            else # 3D
                @bb.add(data[1])
                if data[0] == GL_POINTS
                    view.draw_points(data[1], data[3], 2, data[2])
                    next
                end
                view.draw(data[0], data[1])
            end
        }
        @simulationContext.pointsQueue.each{ |points, size, style, color, width, stipple|
            view.line_width = width
            view.line_stipple = stipple
            @bb.add(points)
            view.draw_points(points, size, style, color)
        }
        view.drawing_color = 'black'
        view.line_width = 1
        view.line_stipple = ''
        state = handle_operation('onDraw error:'){
            @simulationContext.doOnDraw(view, @bb)
        }
        return unless state
    end

    def onSetCursor
        UI.set_cursor(@cursor_id)
    end

    def onKeyDown(key, rpt, flags, view)
        @ctrlDown = true if key == COPY_MODIFIER_KEY && rpt == 1
        @shiftDown = true if key == CONSTRAIN_MODIFIER_KEY && rpt == 1
    end

    def onKeyUp(key, rpt, flags, view)
        @ctrlDown = false if key == COPY_MODIFIER_KEY
        @shiftDown = false if key == CONSTRAIN_MODIFIER_KEY
    end

    def checkModelUnits
        manager = Sketchup.active_model.options
        provider = manager[3]
        puts provider.name if $debug
        provider['SuppressUnitsDisplay'] = true
        provider['LengthFormat'] = 0
    end

    # Start the physics simulation
    # @return [Boolean] success
    def self.physicsStart
        return false if $sketchyPhysicsToolInstance
        initDirectInput
        SketchyPhysicsClient.new
        Sketchup.active_model.select_tool $sketchyPhysicsToolInstance
        $sketchyPhysicsToolInstance ? true : false
    end

    def self.physicsTogglePlay
        if $sketchyPhysicsToolInstance
            @@bPause = !@@bPause
        else
            physicsStart
            @@bPause = false
        end
    end

    # Added because some prior models modify SP content which causes crash.
    def self.safePhysicsReset
        return false unless $sketchyPhysicsToolInstance
        Sketchup.active_model.select_tool nil
        true
    end

    def self.physicsReset
        safePhysicsReset
    end

    def self.physicsRecord
        if @bDoRecord == true
            @@bPause = true
            msg = "Recorded #{@@frame} frames. Save animation? Press Cancel to continue recording."
            result = UI.messagebox(msg, MB_YESNOCANCEL, 'Save Animation')
            case result
            when 6 #yes
                physicsReset
                # Compress and embed animation
            when 7 #no
                physicsReset
            when 2 #cancel
                return
            end
        end
        @bDoRecord = true
        physicsTogglePlay
    end

    def self.paused?
        return false unless $sketchyPhysicsToolInstance
        @@bPause
    end

    def self.active?
        $sketchyPhysicsToolInstance ? true : false
    end

    def self.instance
        $sketchyPhysicsToolInstance
    end

end # class SketchyPhysicsClient


unless file_loaded?(__FILE__)
    file_loaded(__FILE__)

    toolbar = UI::Toolbar.new 'Sketchy Physics'

    cmd = UI::Command.new('Play'){
        SketchyPhysicsClient.physicsTogglePlay
    }
    cmd.set_validation_proc {
        next MF_UNCHECKED unless SketchyPhysicsClient.active?
        SketchyPhysicsClient.paused? ? MF_UNCHECKED : MF_CHECKED
    }
    cmd.menu_text = cmd.tooltip = 'Play/Pause physics simulation.'
    cmd.status_bar_text = 'Play/Pause physics simulation.'
    cmd.small_icon = 'images/SketchyPhysics-PlayPauseButton.png'
    cmd.large_icon = 'images/SketchyPhysics-PlayPauseButton.png'
    toolbar.add_item(cmd)


    cmd = UI::Command.new('Reset'){
        SketchyPhysicsClient.physicsReset
    }
    cmd.set_validation_proc {
        SketchyPhysicsClient.active? ? MF_ENABLED : MF_GRAYED
    }
    cmd.menu_text = cmd.tooltip = 'Reset physics simulation.'
    cmd.status_bar_text = 'Reset physics simulation.'
    cmd.small_icon = 'images/SketchyPhysics-RewindButton.png'
    cmd.large_icon = 'images/SketchyPhysics-RewindButton.png'
    toolbar.add_item(cmd)


    cmd = UI::Command.new('ShowUI'){
        $spObjectInspector.toggleDialog
    }
    cmd.set_validation_proc {
        $spObjectInspector.dialogVisible? ? MF_CHECKED : MF_UNCHECKED
    }
    cmd.menu_text = cmd.tooltip = 'Show/Hide UI'
    cmd.status_bar_text = 'Show/Hide UI'
    cmd.small_icon = 'images/SketchyPhysics-ShowUIButton.png'
    cmd.large_icon = 'images/SketchyPhysics-ShowUIButton.png'
    toolbar.add_item(cmd)


    cmd = UI::Command.new('JointConnectionTool'){
        model = Sketchup.active_model
        if JointConnectionTool.active?
            model.select_tool nil
            model.selection.clear
        else
            model.select_tool JointConnectionTool.new
        end
    }
    cmd.set_validation_proc {
        JointConnectionTool.active? ? MF_CHECKED : MF_UNCHECKED
    }
    cmd.menu_text = cmd.tooltip = 'Activate/Deactivate joint connection tool.'
    cmd.status_bar_text = 'Activate/Deactivate joint connection tool.'
    cmd.small_icon = 'images/joint_connector.png'
    cmd.large_icon = 'images/joint_connector.png'
    toolbar.add_item(cmd)

    toolbar.show
end

end # module MSketchyPhysics3
