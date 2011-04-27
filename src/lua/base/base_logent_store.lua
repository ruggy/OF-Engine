---
-- base_logent_store.lua, version 1<br/>
-- Logic entity system for Lua - storage<br/>
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

--- This module takes care of logic entity storage.
-- @class module
-- @name of.logent.store
module("of.logent.store", package.seeall)

-- caching by time delay
function cache_by_time_delay(func, delay)
    func.last_time = ((-delay) * 2)
    return function(...)
        if (of.global.time - func.last_time) >= delay then
            func.last_cached_val = func(...)
            func.last_time = of.global.time
        end
        return func.last_cached_val
    end
end

-- local store of entities, parallels the c++ store
local __entities_store = {}
-- caching
local __entities_store_by_class = {}

--- Access a logent from the store, knowing its unique ID.
-- @param uid Unique ID of the logent to get.
-- @return The logent if found, nil otherwise.
function get(uid)
    of.logging.log(of.logging.DEBUG, "get: entity " .. tostring(uid))
    local r = __entities_store[tonumber(uid)]
    if r then
        of.logging.log(of.logging.DEBUG, "get: entity " .. tostring(uid) .. " found (" .. r.uid .. ")")
        return r
    else
        of.logging.log(of.logging.DEBUG, "get: could not find entity " .. tostring(uid))
        return nil
    end
end

--- Get a table of logents from store which share the same tag.
-- @param wtag The tag to use for searching.
-- @return Table of logents (empty table if none found)
function get_all_bytag(wtag)
    local r = {}
    for k, v in pairs(__entities_store) do
        if v:has_tag(wtag) then
            table.insert(r, v)
        end
    end
    return r
end

--- Get a single logent of known tag.
-- @param wtag The tag to use for searching.
-- @return Logent with known tag (and none if not found or more than one found)
function get_bytag(wtag)
    local r = get_all_bytag(wtag)
    if #r == 1 then return r[1]
    elseif #r > 1 then
        of.logging.log(of.logging.WARNING, "Attempt to get a single entity with tag '" .. tostring(wtag) .. "', but several exist.")
        return nil
    else
        of.logging.log(of.logging.WARNING, "Attempt to get a single entity with tag '" .. tostring(wtag) .. "', but none exist.")
        return nil
    end
end

--- Get a table of logents of the same class.
-- @param cl Class to use for searching.
-- @return Table of logents (empty table if none found)
function get_all_byclass(cl)
    if type(cl) == "table" then
        cl = tostring(cl)
    end

    -- caching
    if __entities_store_by_class[cl] then
        return __entities_store_by_class[cl]
    else
        return {}
    end
end

--- Get a table of all clients (== all logents of currently set player class)
-- @return Table of clients. (empty if no clients found, that means we're probably in menu)
function get_all_clients()
    local ret = get_all_byclass(type(player_class) == "string" and player_class or "player")
    of.logging.log(of.logging.DEBUG, "logent store: get_all_clients: got %(1)s clients" % { #ret })
    return ret
end

--- Get a table of all client numbers.
-- @return Table of client numbers. (empty if no clients found, that means we're probably in menu)
function get_all_clientnums()
    return table.map(get_all_clients(), function(c) return c.cn end)
end

--- Get whether player is editing.
-- @return True if player is editing, false otherwise.
function is_player_editing(ply)
    if of.global.CLIENT then
        ply = ply or get_plyent()
    end
    return ply and ply.cs == 4 -- of.character.CSTATE.EDITING
end

--- Get table of entities close to a position.
-- @param origin The position they should be close to.
-- @param maxdist Distance after which the entities are considered "far"
-- @param cl If set, only entities of that class will be returned.
-- @param wtag If set, only entities of that tag will be returned.
-- @param unsorted If not set, table will contain entities sorted by distance (from nearest to farest).
-- @return Table of entities.
function get_all_close(origin, maxdist, cl, wtag, unsorted)
    local r = {}

    local ents = cl and get_all_byclass(cl) or table.values(__entities_store)
    for i = 1, #ents do
        local oe = ents[i]

        local skip = false
        if wtag and not oe:has_tag(wtag) then skip = true end
        if not oe.position then skip = true end

        if not skip then
            local dist = origin:sub_new(oe.position):magnitude()
            if dist <= maxdist then
                table.insert(r, { oe, dist })
            end
        end
    end

    if not unsorted then
        table.sort(r, function(a, b) return a[2] < b[2] end)
    end

    return r
end

--- Add a logic entity. The entity will get stored and activated.
-- @param cn Class of the new entity.
-- @param uid Unique ID of the entity.
-- @param kwargs Additional parameters to pass to constructor (contents depend on entity type).
-- @param _new Works only serverside, if set, init() of the entity will get called instead of just setting uid.
-- @return The newly created entity.
function add(cn, uid, kwargs, _new)
    uid = uid or 1337 -- debugging

    of.logging.log(of.logging.DEBUG, "Adding new scripting logent of type " .. tostring(cn) .. " with uid " .. tostring(uid))
    of.logging.log(of.logging.DEBUG, "   with arguments: " .. of.json.encode(kwargs) .. ", " .. tostring(_new))

    assert(not get(uid)) -- cannot recreate

    local _class = of.logent.classes.get_class(cn)
    local r = _class()

    if of.global.CLIENT then
        r.uid = uid
    else
        if _new then
            r:init(uid, kwargs)
        else
            r.uid = uid
        end
    end

    __entities_store[r.uid] = r
    assert(get(uid) == r)

    -- caching
    for k, v in pairs(of.logent.classes._logent_classes) do
        if tostring(r) == k then
            if not __entities_store_by_class[k] then
               __entities_store_by_class[k] = {}
            end
            table.insert(__entities_store_by_class[k], r)
        end
    end

    -- done after setting the uid and placing in the global store,
    -- because c++ registration relies on both

    of.logging.log(of.logging.DEBUG, "Activating ..")

    if of.global.CLIENT then
        r:client_activate(kwargs)
    else
        r:activate(kwargs)
    end

    return r
end

--- Delete an entity of known uid.
-- @param uid Unique ID of the entity which we're deleting.
function del(uid)
    of.logging.log(of.logging.DEBUG, "Removing scripting logent: " .. tostring(uid))

    if not __entities_store[tonumber(uid)] then
        of.logging.log(of.logging.WARNING, "Cannot remove entity " .. tostring(uid) .. " as it does not exist.")
        return nil
    end

    __entities_store[tonumber(uid)]:emit("pre_deactivate")

    if of.global.CLIENT then
        __entities_store[tonumber(uid)]:client_deactivate()
    else
        __entities_store[tonumber(uid)]:deactivate()
    end

    -- caching
    local ent = __entities_store[tonumber(uid)]
    for k, v in pairs(of.logent.classes._logent_classes) do
        if tostring(ent) == k then
            __entities_store_by_class[k] = table.filterarray(
                __entities_store_by_class[k],
                function(a, b) return (b ~= ent) end
            )
        end
    end

    __entities_store[tonumber(uid)] = nil
end

--- Delete all entities in the store.
function del_all()
    for k, v in pairs(__entities_store) do
        del(k)
    end
end

curr_timestamp = 0
of.global.curr_timestamp = curr_timestamp

function start_frame()
    curr_timestamp = curr_timestamp + 1
    of.global.curr_timestamp = curr_timestamp
end

of.global.time = 0
of.global.curr_timedelta = 1.0
of.global.lastmillis = 0
of.global.queued_actions = {}

--- Manage action queue. This is performed every frame,
-- so its performance is important. It loops the entity
-- store and runs either client_act or act (depending
-- on if we're on server or client) for every entity
-- that has acting enabled, it also sets global time.
-- This is called from C.
-- @param sec The length of seconds to simulate.
-- @param lastmillis Number of miliseconds since last reset.
function manage_actions(sec, lastmillis)
    of.logging.log(of.logging.INFO, "manage_actions: queued ..")

    local curr_actions = table.copy(of.global.queued_actions) -- work on copy as these may add more
    of.global.queued_actions = {}

    for k,v in pairs(curr_actions) do v() end

    of.global.time = of.global.time + sec
    of.global.curr_timedelta = sec
    of.global.lastmillis = lastmillis

    of.logging.log(of.logging.INFO, "manage_actions: " .. tostring(sec))

    local ents = table.values(__entities_store)
    for i = 1, #ents do
        local ent = ents[i]
        local skip = false
        if ent.deactivated then skip = true end
        if not ent.should_act then skip = true end
        if not skip then
            if of.global.CLIENT then
                ent:client_act(sec)
            else
                ent:act(sec)
            end
        end
    end
end

--- Global dynamic render method. This is performed every frame,
-- so its performance is important. It loops the entity store
-- and performs render_dynamic for every entity that should
-- have this ran (characters, mapmodels, etc).
-- If we're in thirdperson mode, player won't be rendered,
-- because that's done in render_hud_models.
-- @param tp True if we're in thirdperson mode, false otherwise.
-- @see render_hud_models
function render_dynamic(tp)
    of.logging.log(of.logging.INFO, "render_dynamic")

    local ply = get_plyent()
    if not ply then return nil end

    local ents = table.values(__entities_store)
    for i = 1, #ents do
        local ent = ents[i]
        local skip = false
        if ent.deactivated or not ent.render_dynamic then skip = true end
        if not skip then
            if ent.use_render_dynamic_test then
                if not ent.render_dynamic_test then
                    rendering.setup_dynamic_test(ent)
                end
                if not ent:render_dynamic_test() then skip = true end
            end
        end
        if not skip then
            ent:render_dynamic(false, not tp and ent == ply)
        end
    end
end

--- Render HUD models. Called when we're in thirdperson mode.
-- Takes care of rendering player HUD model if player is not
-- in edit mode and has hud model name set.
-- @see render_dynamic
function render_hud_models()
    local ply = get_plyent()
    if ply.hud_modelname and ply.cs ~= 4 then -- 4 = of.character.CSTATE.EDITING
        ply:render_dynamic(true, true)
    end
end

if of.global.CLIENT then

--- Set player uid. Clientside only function. Creates player_logent method, which is
-- global and can be accessed by get_plyent afterwards.
-- @param uid The unique ID of player's logic entity.
-- @see get_plyent
function set_player_uid(uid)
    of.logging.log(of.logging.DEBUG, "Setting player uid to " .. tostring(uid))

    if uid then
        player_logent = get(uid)
        player_logent._controlled_here = true
        of.logging.log(of.logging.DEBUG, "Player _controlled_here:" .. tostring(player_logent._controlled_here))

        assert(not uid or player_logent)
    end
end

--- Get player logic entity. Clientside only.
-- @return Player logic entity.
-- @see set_player_uid
function get_plyent() return player_logent end

--- Set entity state data. Protocol ID gets translated to actual name.
-- This performs changes only locally, so makes sense only as response
-- to server command. This is clientside only function.
-- @param uid Unique ID of the entity.
-- @param kproid Protocol ID of state data.
-- @param val Value to set.
function set_statedata(uid, kproid, val)
    ent = get(uid)
    if ent then
        local key = of.msgsys.fromproid(tostring(ent), kproid)
        of.logging.log(of.logging.DEBUG, "set_statedata: " .. tostring(uid) .. ", " .. tostring(kproid) .. ", " .. tostring(key))
        ent:_set_statedata(key, val)
    end
end

--- Test if scenario has started. If some entity is still uninitialized
-- or player does not exist yet, it means scenario is not started.
-- This is clientside only function.
-- @return True if it has, false otherwise.
function test_scenario_started()
    of.logging.log(of.logging.INFO, "Testing whether the scenario started ..")

    if not get_plyent() then
        of.logging.log(of.logging.INFO, ".. no, player logent not created yet.")
        return false
    end

    of.logging.log(of.logging.INFO, ".. player entity created.")

    ents = table.values(__entities_store)
    for i = 1, #ents do
        if not ents[i].initialized then
            of.logging.log(of.logging.INFO, ".. no, entity " .. tostring(ents[i].uid) .. " is not initialized.")
            return false
        end
    end

    of.logging.log(of.logging.INFO, ".. yes, scenario is running.")
    return true
end

end

if of.global.SERVER then

--- Generate new unique ID. Used when adding entities. Serverside only function.
-- @return Newly generated unique ID.
function get_newuid()
    local r = 0
    uids = table.keys(__entities_store)
    for i = 1, #uids do
        r = math.max(r, uids[i])
    end
    r = r + 1
    of.logging.log(of.logging.DEBUG, "Generating new uid: " .. tostring(r))
    return r
end

--- Create new serverside entity. Optionally generates unique ID (if not forced)
-- @param cl Class to generate new entity of.
-- @param kwargs Parameters passed to entity constructor, specific to class.
-- @param fuid If set, unique ID of new entity is forced to it. Otherwise generated.
-- @param ruid If true, new entity's unique ID is returned, otherwise entity is returned.
-- @return Depending on last argument, either new entity or its unique ID are returned.
function new(cl, kwargs, fuid, ruid)
    fuid = fuid or get_newuid()
    of.logging.log(of.logging.DEBUG, "New logent: " .. tostring(fuid))

    local r = add(cl, fuid, kwargs, true)

    return ruid and r.uid or r
end

--- Create new serverside NPC. The change gets reflected to all clients.
-- @param cl Class of the NPC.
-- @return The new NPC entity.
function new_npc(cl)
    local npc = CAPI.npcadd(cl)
    npc._controlled_here = true
    return npc
end

--- Send all data of currently active serverside entities to client.
-- Includes both inmap entities like mapmodels and non-map entities
-- like players and non-sauers.
-- @param cn Client number belonging to client we're sending to.
function send_entities(cn)
    of.logging.log(of.logging.DEBUG, "Sending active logents to " .. tostring(cn))

    local numents = 0
    local ids = {}
    for k, v in pairs(__entities_store) do
        numents = numents + 1
        table.insert(ids, k) -- create the keys table immediately to not iterate twice later
    end
    table.sort(ids)

    of.msgsys.send(cn, CAPI.notify_numents, numents)
    for i = 1, #ids do
        __entities_store[ids[i]]:send_notification_complete(cn)
    end
end

--- Set serverside entity state data and then asking clients to update.
-- Protocol IDs get translated to normal names.
-- @param uid Unique ID of the entity.
-- @param kproid Protocol ID of state data.
-- @param val Value to set.
-- @param auid Unique ID of the actor (client that triggered the change) or -1 when it comes from server.
function set_statedata(uid, kproid, val, auid)
    local ent = get(uid)
    if ent then
        local key = of.msgsys.fromproid(tostring(ent), kproid)
        ent:_set_statedata(key, val, auid)
    end
end

--- Load entities from JSON table and notify clients to add them later.
-- Serverside only function.
-- @param sents JSON table of entities as a string, decoded later.
function load_entities(sents)
    of.logging.log(of.logging.DEBUG, "Loading entities .. " .. tostring(sents) .. ", " .. type(sents))

    local ents = of.json.decode(sents)
    for i = 1, #ents do
        of.logging.log(of.logging.DEBUG, "load_entities: " .. of.json.encode(ents[i]))
        local uid = ents[i][1]
        local cls = ents[i][2]
        local state_data = ents[i][3]
        of.logging.log(of.logging.DEBUG, "load_entities: " .. tostring(uid) .. ", " .. tostring(cls) .. ", " .. of.json.encode(state_data))

        if mapversion <= 30 and state_data.attr1 then
            if cls ~= "light" and cls ~= "flickering_light" and cls ~= "particle_effect" and cls ~= "envmap" then
                state_data.attr1 = (tonumber(state_data.attr1) + 180) % 360
            end
        end

        add(cls, uid, { state_data = of.json.encode(state_data) })
    end

    of.logging.log(of.logging.DEBUG, "Loading entities complete")
end

end

--- Create encoded JSON table (string) of all entities in store and return.
-- Used when saving entities on the disk to load them next time.
-- @return Encoded JSON table (string) of the entities.
function save_entities()
    local r = {}
    of.logging.log(of.logging.DEBUG, "Saving entities ..:")

    local vals = table.values(__entities_store)
    for i = 1, #vals do
        if vals[i]._persistent then
            of.logging.log(of.logging.DEBUG, "Saving entity " .. tostring(vals[i].uid))
            local uid = vals[i].uid
            local cls = tostring(vals[i])
            -- TODO: store as serialized here, to save some parse/unparsing
            local state_data = vals[i]:create_statedatadict()
            table.insert(r, of.json.encode({ uid, cls, state_data }))
        end
    end

    of.logging.log(of.logging.DEBUG, "Saving entities complete.")
    return "[\n" .. table.concat(r, ",\n") .. "\n]\n\n"
end

-- Caching per of.global.timestamp
function cache_by_global_timestamp(func)
    return function(...)
        if func.last_timestamp ~= of.global.curr_timestamp then
            func.last_cached_val = func(...)
            func.last_timestamp = global.curr_timestamp
        end
        return func.last_cached_val
    end
end

CAPI.gettargetpos = cache_by_global_timestamp(CAPI.gettargetpos)
CAPI.gettargetent = cache_by_global_timestamp(CAPI.gettargetent)

rendering = {}

--- Set up dynamic render test. This is meant to increase performance,
-- because it skips render_dynamic for all entities that are out of
-- sight of the player.
-- @param ent Entity to set up dynamic render test for.
function rendering.setup_dynamic_test(ent)
    local current = ent
    ent.render_dynamic_test = cache_by_time_delay(function()
        local plycenter = get_plyent().center
        if current.position:sub_new(plycenter):magnitude() > 256 then
            if not of.utils.haslineofsight(plycenter, current.position) then return false end
        end
        return true
    end, 1 / 3)
end
