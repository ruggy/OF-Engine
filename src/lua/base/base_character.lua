---
-- base_character.lua, version 1<br/>
-- Character handling for Lua<br/>
-- <br/>
-- @author q66 (quaker66@gmail.com)<br/>
-- license: MIT/X11<br/>
-- <br/>
-- @copyright 2011 OctaForge project<br/>
-- <br/>
-- Permission is hereby granted, free of charge, to any person obtaining a copy<br/>
-- of this software and associated documentation files (the "Software"), to deal<br/>
-- in the Software without restriction, including without limitation the rights<br/>
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell<br/>
-- copies of the Software, and to permit persons to whom the Software is<br/>
-- furnished to do so, subject to the following conditions:<br/>
-- <br/>
-- The above copyright notice and this permission notice shall be included in<br/>
-- all copies or substantial portions of the Software.<br/>
-- <br/>
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR<br/>
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,<br/>
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE<br/>
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER<br/>
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,<br/>
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN<br/>
-- THE SOFTWARE.
--

--- This module takes care of character entity, states and player entity.
-- @class module
-- @name of.character
module("of.character", package.seeall)

--- Client state table, reflects ents.h.
-- @field ALIVE Client is alive.
-- @field DEAD Client is dead, unused, handled differently.
-- @field SPAWNING Client is spawning, unused.
-- @field LAGGED Client is lagged.
-- @field EDITING Client is editing.
-- @field SPECTATOR Client is spectator.
-- @class table
-- @name CSTATE
CSTATE = {
    ALIVE = 0,
    DEAD = 1, -- unused by us
    SPAWNING = 2, -- unused by us
    LAGGED = 3,
    EDITING = 4,
    SPECTATOR = 5
}

--- Physical state table, reflects ents.h.
-- @field FLOAT Client is floating.
-- @field FALL Client is falling.
-- @field SLIDE Client is sliding.
-- @field SLOPE Client is sloping.
-- @field FLOOR Client is on floor.
-- @field STEP_UP Client is stepping up.
-- @field STEP_DOWN Client is stepping down.
-- @field BOUNCE Client is bouncing.
-- @class table
-- @name PSTATE
PSTATE = {
    FLOAT = 0,
    FALL = 1, 
    SLIDE = 2, 
    SLOPE = 3, 
    FLOOR = 4, 
    STEP_UP = 5, 
    STEP_DOWN = 6, 
    BOUNCE = 7
}

--- Base character class, inherited from animatable_logent.
-- Used as a base for player of.class.
-- @class table
-- @name character
character = of.class.new(of.animatable.animatable_logent)
character._class = "character"
character._sauertype = "fpsent"

--- Base properties of character entity.
-- Inherits properties of animatable_logent plus adds its own.
-- @field _name Character name.
-- @field facing_speed How fast can character change facing
-- (yaw / pitch) in degrees/second, integer.
-- @field movement_speed Character movement speed, float.
-- @field yaw Character yaw, integer.
-- @field pitch Character pitch, integer.
-- @field move -1 when moving backwards, 0 when not, 1 when forward, integer.
-- @field strafe -1 when strafing left, 1 when right, 0 when not, integer.
-- @field position Character position, vec3 (x, y, z).
-- @field velocity Character velocity, vec3 (x, y, z).
-- @field falling Character falling, vec3 (x, y, z).
-- @field radius Character bounding box radius, float.
-- @field aboveeye Distance from position vector to eyes.
-- @field eyeheight Distance from eyes to feet.
-- @field blocked True if character was blocked by obstacle on last
-- movement cycle, boolean. Floor is not an obstacle.
-- @field canmove If false, character can't move, boolean.
-- @field mapdefinedposdata Position protocol data specific to current map,
-- see fpsent, integer (TODO: make unsigned)
-- @field cs Client state, integer. (see CSTATE table)
-- @field ps Physical state, integer. (see PSTATE table)
-- @field inwater 1 if character is underwater, integer.
-- @field timeinair Time in miliseconds spent in the air, integer (Should be unsigned, TODO)
-- @class table
-- @name character.properties
character.properties = {
    of.animatable.animatable_logent.properties[1], -- tags
    of.animatable.animatable_logent.properties[2], -- _persitent
    of.animatable.animatable_logent.properties[3], -- animation
    of.animatable.animatable_logent.properties[4], -- starttime
    of.animatable.animatable_logent.properties[5], -- modelname
    of.animatable.animatable_logent.properties[6], -- attachments

    { "_name", of.state_variables.state_string() },
    { "facing_speed", of.state_variables.state_integer() },

    { "movement_speed", of.state_variables.wrapped_cfloat({ cgetter = "CAPI.getmaxspeed", csetter = "CAPI.setmaxspeed" }) },
    { "yaw", of.state_variables.wrapped_cfloat({ cgetter = "CAPI.getyaw", csetter = "CAPI.setyaw", customsynch = true }) },
    { "pitch", of.state_variables.wrapped_cfloat({ cgetter = "CAPI.getpitch", csetter = "CAPI.setpitch", customsynch = true }) },
    { "move", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.getmove", csetter = "CAPI.setmove", customsynch = true }) },
    { "strafe", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.getstrafe", csetter = "CAPI.setstrafe", customsynch = true }) },
--  intention to yaw / pitch. todo: enable
--  { "yawing", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.getyawing", csetter = "CAPI.setyawing", customsynch = true }) },
--  { "pitching", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.getpitching", csetter = "CAPI.setpitching", customsynch = true }) },
    { "position", of.state_variables.wrapped_cvec3({ cgetter = "CAPI.getdynent0", csetter = "CAPI.setdynent0", customsynch = true }) },
    { "velocity", of.state_variables.wrapped_cvec3({ cgetter = "CAPI.getdynentvel", csetter = "CAPI.setdynentvel", customsynch = true }) },
    { "falling", of.state_variables.wrapped_cvec3({ cgetter = "CAPI.getdynentfalling", csetter = "CAPI.setdynentfalling", customsynch = true }) },
    { "radius", of.state_variables.wrapped_cfloat({ cgetter = "CAPI.getradius", csetter = "CAPI.setradius" }) },
    { "aboveeye", of.state_variables.wrapped_cfloat({ cgetter = "CAPI.getaboveeye", csetter = "CAPI.setaboveeye" }) },
    { "eyeheight", of.state_variables.wrapped_cfloat({ cgetter = "CAPI.geteyeheight", csetter = "CAPI.seteyeheight" }) },
    { "blocked", of.state_variables.wrapped_cbool({ cgetter = "CAPI.getblocked", csetter = "CAPI.setblocked" }) },
    { "canmove", of.state_variables.wrapped_cbool({ csetter = "CAPI.setcanmove", clientset = true }) },
    { "mapdefinedposdata", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.getmapdefinedposdata", csetter = "CAPI.setmapdefinedposdata", customsynch = true }) },
    { "cs", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.getclientstate", csetter = "CAPI.setclientstate", customsynch = true }) },
    { "ps", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.getphysstate", csetter = "CAPI.setphysstate", customsynch = true }) },
    { "inwater", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.getinwater", csetter = "CAPI.setinwater", customsynch = true }) },
    { "timeinair", of.state_variables.wrapped_cinteger({ cgetter = "CAPI.gettimeinair", csetter = "CAPI.settimeinair", customsynch = true }) }
}

--- Jump handler method for character.
function character:jump()
    CAPI.setjumping(self, true)
end

--- Initializer. See animatable_logent.
function character:init(uid, kwargs)
    of.logging.log(of.logging.DEBUG, "character:init")
    of.animatable.animatable_logent.init(self, uid, kwargs)

    self._name = "-?-" -- set by the server later
    self.cn = kwargs and kwargs.cn or -1
    self.modelname = "player"
    self.eyeheight = 14.0
    self.aboveeye = 1.0
    self.movement_speed = 50.0
    self.facing_speed = 120
    self.position = { 512, 512, 550 }
    self.radius = 3.0
    self.canmove = true
end

--- Serverside activation. See animatable_logent.
function character:activate(kwargs)
    of.logging.log(of.logging.DEBUG, "character:activate")
    self.cn = kwargs and kwargs.cn or -1
    assert(self.cn >= 0)

    CAPI.setupcharacter(self)
    of.animatable.animatable_logent.activate(self, kwargs)
    self:_flush_queued_sv_changes()

    of.logging.log(of.logging.DEBUG, "character:activate complete.")
end

--- Clientside activation. See serverside.
function character:client_activate(kwargs)
    of.animatable.animatable_logent.client_activate(self, kwargs)
    self.cn = kwargs and kwargs.cn or -1
    CAPI.setupcharacter(self)

    self.rendering_args_timestamp = -1
end

--- Serverside entity deactivation.
function character:deactivate()
    CAPI.dismantlecharacter(self)
    of.animatable.animatable_logent.deactivate(self)
end

--- Clientside entity deactivation.
function character:client_deactivate()
    CAPI.dismantlecharacter(self)
    of.animatable.animatable_logent.client_deactivate(self)
end

--- Serverside act method for character. Ran every frame.
-- Can be overriden, but make sure to call this in your
-- method in custom class on the beginning.
-- @param sec Length of time to simulate.
function character:act(sec)
    if self.action_system:isempty() then
        self:default_action(sec)
    else
        of.animatable.animatable_logent.act(self, sec)
    end
end

--- Called serverside by act if action queue is empty.
-- Override as you want, by default it does nothing.
-- @param sec Length of time to simulate.
function character:default_action(sec)
end

--- Dynamic render method for character. Ran every frame clientside,
-- taking care of character model rendering, with proper caching
-- so it doesn't have to regenerate parameters every frame.
-- @param hudpass True if we're rendering HUD right now.
-- @param needhud True if model should be shown as HUD model (== we're in first person)
function character:render_dynamic(hudpass, needhud)
    if not self.initialized then return nil end
    if not hudpass and needhud then return nil end

    if self.rendering_args_timestamp ~= of.logent.store.curr_timestamp then
        local state = self.cs
        if state == CSTATE.SPECTAROR or state == CSTATE.SPAWNING then return nil end

        local mdlname = (hudpass and needhud) and self.hud_modelname or self.modelname
        local yaw = self.yaw + 90
        local pitch = self.pitch
        local o = self.position:copy()
        
        if hudpass and needhud and self.hud_modeloffset then o:add(self.hud_modeloffset) end
        local basetime = self.starttime
        local physstate = self.ps
        local inwater = self.inwater
        local move = self.move
        local strafe = self.strafe
        local vel = self.velocity:copy()
        local falling = self.falling:copy()
        local timeinair = self.timeinair
        local anim = self:decide_animation(state, physstate, move, strafe, vel, falling, inwater, timeinair)
        local flags = self:get_renderingflags(hudpass, needhud)

        self.rendering_args = { self, mdlname, anim, o.x, o.y, o.z, yaw, pitch, flags, basetime }
        self.rendering_args_timestamp = of.logent.store.curr_timestamp
    end

    -- render only when model is set
    if self.rendering_args[2] ~= "" then of.model.render(unpack(self.rendering_args)) end
end

--- Used in render_dynamic to get rendering flags. Enables some occlusion, dynamic shadow, etc.
-- @param hudpass True if we're rendering HUD right now.
-- @param needhud True if model should be shown as HUD model (== we're in first person)
function character:get_renderingflags(hudpass, needhud)
    local flags = math.bor(of.model.LIGHT, of.model.DYNSHADOW)
    if self ~= of.logent.store.get_plyent() then
        flags = math.bor(flags, of.model.CULL_VFC, of.model.CULL_OCCLUDED, of.model.CULL_QUERY)
    end
    if hudpass and needhud then
        flags = math.bor(flags, of.model.HUD)
    end
    return flags -- TODO: for non-characters, use flags = math.bor(flags, of.model.CULL_DIST)
end

--- Used in render_dynamic to decide character animation (falling, strafing, etc.) from given arguments.
-- See assigned properties in character.properties table (cs == state, ps == pstate, vel == velocity).
-- @see character.properties
function character:decide_animation(state, pstate, move, strafe, vel, falling, inwater, timeinair)
    -- same naming convention as rendermodel.cpp in cube 2
    local anim = self:decide_action_animation()

    if state == CSTATE.EDITING or state == CSTATE.SPECTATOR then
        anim = math.bor(of.action.ANIM_EDIT, of.action.ANIM_LOOP)
    elseif state == CSTATE.LAGGED then
        anim = math.bor(of.action.ANIM_LAG, of.action.ANIM_LOOP)
    else
        if inwater and pstate <= PSTATE.FALL then
            anim = math.bor(anim, math.lsh(math.bor(((move or strafe) or vel.z + falling.z > 0) and of.action.ANIM_SWIM or of.action.ANIM_SINK, of.action.ANIM_LOOP), of.action.ANIM_SECONDARY))
        elseif timeinair > 250 then
            anim = math.bor(anim, math.lsh(math.bor(of.action.ANIM_JUMP, of.action.ANIM_END), of.action.ANIM_SECONDARY))
        elseif move or strafe then
            if move > 0 then
                anim = math.bor(anim, math.lsh(math.bor(of.action.ANIM_FORWARD, of.action.ANIM_LOOP), of.action.ANIM_SECONDARY))
            elseif strafe then
                anim = math.bor(anim, math.lsh(math.bor((strafe > 0 and ANIM_LEFT or ANIM_RIGHT), of.action.ANIM_LOOP), of.action.ANIM_SECONDARY))
            elseif move < 0 then
                anim = math.bor(anim, math.lsh(math.bor(of.action.ANIM_BACKWARD, of.action.ANIM_LOOP), of.action.ANIM_SECONDARY))
            end
        end

        if math.band(anim, of.action.ANIM_INDEX) == of.action.ANIM_TITLE and math.band(math.rsh(anim, of.action.ANIM_SECONDARY), of.action.ANIM_INDEX) then
            anim = math.rsh(anim, of.action.ANIM_SECONDARY)
        end
    end

    if not math.band(math.rsh(anim, of.action.ANIM_SECONDARY), of.action.ANIM_INDEX) then
        anim = math.bor(anim, math.lsh(math.bor(of.action.ANIM_IDLE, of.action.ANIM_LOOP), of.action.ANIM_SECONDARY))
    end

    return anim
end

--- Returns the "action" animation to show. Does not handle things like
-- inwater, lag, etc which are handled in decide_animation.
-- By default, simply returns self.animation, but can be overriden to handle more complex
-- things like taking into account map-specific information in mapdefinedposdata.
function character:decide_action_animation()
    return self.animation
end

--- Get center position of character, something like gravity center.
-- For example AI bots would better aim at this point instead of "position"
-- which is feet position. Override if your center is nonstandard.
-- By default, it's 0.75 * eyeheight above feet.
-- @return Center position which is a vec3.
function character:get_center()
    local r = self.position:copy()
    r.z = r.z + self.eyeheight * 0.75
    return r
end

--- Get whether character is on floor.
-- @return True if it is, otherwise false.
function character:is_onfloor()
    if floor_dist(self.position, 1024) < 1 then return true end
    if self.velocity.z < -1 or self.falling.z < -1 then return false end
    return of.utils.iscolliding(self.position, self.radius + 2, self)
end

--- Base player class, inherited from character.
-- Default player if not overriden.
-- @class table
-- @name player
-- @see character
player = of.class.new(character)
player._class = "player"

--- Base properties of player entity.
-- Inherits properties of character plus adds its own.
-- @field _can_edit True if player can edit (== is in private edit mode),
-- false otherwise, boolean.
-- @field hud_modelname HUD model name, used instead of modelname when in first person.
-- @class table
-- @name player.properties
-- @see character.properties
player.properties = {
    character.properties[1], -- tags
    character.properties[2], -- _persitent
    character.properties[3], -- animation
    character.properties[4], -- starttime
    character.properties[5], -- modelname
    character.properties[6], -- attachments

    character.properties[7], -- _name
    character.properties[8], -- facing_speed

    character.properties[9], -- movement_speed
    character.properties[10], -- yaw
    character.properties[11], -- pitch
    character.properties[12], -- move
    character.properties[13], -- strafe
    -- character.properties[X], -- yawing
    -- character.properties[X], -- pitching
    character.properties[14], -- position
    character.properties[15], -- velocity
    character.properties[16], -- falling
    character.properties[17], -- radius
    character.properties[18], -- aboveeye
    character.properties[19], -- eyeheight
    character.properties[20], -- blocked
    character.properties[21], -- canmove
    character.properties[22], -- mapdefinedposdata
    character.properties[23], -- cs
    character.properties[24], -- ps
    character.properties[25], -- inwater
    character.properties[26], -- timeinair

    { "_can_edit", of.state_variables.state_bool() },
    { "hud_modelname", of.state_variables.state_string() }
}

--- Overriden initializer, calls base
-- and sets default values of added properties.
function player:init(uid, kwargs)
    of.logging.log(of.logging.DEBUG, "player:init")
    character.init(self, uid, kwargs)

    self._can_edit = false
    self.hud_modelname = ""
end

of.logent.classes.reg(character, "fpsent")
of.logent.classes.reg(player, "fpsent")
