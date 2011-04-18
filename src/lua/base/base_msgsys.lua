---
-- base_msgsys.lua, version 1<br/>
-- Message system for Lua<br/>
-- <br/>
-- @author q66 (quaker66@gmail.com)<br/>
-- license: MIT/X11<br/>
-- <br/>
-- @copyright 2011 CubeCreate project<br/>
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

local base = _G
local CAPI = require("CAPI")
local table = require("table")
local string = require("string")
local log = require("cc.logging")
local lent = require("cc.logent")

--- Message system interface for Lua. Used for communication between client and server,
-- takes care of name compressing and other things.
-- @class module
-- @name cc.msgsys
module("cc.msgsys")

-- -1 value represents all clients.
ALL_CLIENTS = -1

-- storage for ptocol names and IDs.
pntoids = {}
pidston = {}

--- Send a message, either client->server or server->client. Data after message function are passed to it.
-- @param a1 If this is logic entity or number, it's server->client message (number representing client number). On client, it's the message function.
-- @param a2 On server, it's a message function, on client, data begin here.
function send(...)
    log.log(log.DEBUG, "cc.msgsys.send")

    local server
    local cn

    local args = { ... }
    if base.type(args[1]) == "table" and args[1].is_a and args[1]:is_a(lent.logent) then
        -- server->client message, get clientnumber from entity
        server = true
        cn = args[1].cn
    elseif base.type(args[1]) == "number" then
        -- server->client message, given cn
        server = true
        cn = args[1]
    else
        server = false
    end

    if server then table.remove(args, 1) end

    local mt = args[1]
    table.remove(args, 1)

    if server then table.insert(args, 1, cn) end

    log.log(log.DEBUG, string.format("Lua msgsys: send(): %s with { %s }", base.tostring(mt), table.concat(table.map(args, function(x) return base.tostring(x) end), ", ")))
    mt(base.unpack(args))
end

--- Generate protocol data.
-- @param cln Client number.
-- @param svn State variable names (table)
function genprod(cln, svn)
    log.log(log.DEBUG, string.format("Generating protocol names for %s", cln))
    table.sort(svn) -- ensure there is the same order on both client and server

    local ntoids = {}
    local idston = {}
    for i = 1, #svn do
        ntoids[svn[i]] = base.tostring(i)
        idston[i] = svn[i]
    end

    pntoids[cln] = ntoids
    pidston[cln] = idston
end

--- Return protocol ID to corresponding state variable name.
-- @param cln Client number.
-- @param svn State variable name.
-- @return Corresponding protocol ID.
function toproid(cln, svn)
    log.log(log.DEBUG, string.format("Retrieving protocol ID for %s / %s", cln, svn))
    return pntoids[cln][svn]
end

--- Return state variable name to corresponding protocol ID.
-- @param cln Client number.
-- @param svn Protocol ID.
-- @return Corresponding state variable name.
function fromproid(cln, proid)
    log.log(log.DEBUG, string.format("Retrieving state variable name for %s / %i", cln, proid))
    return pidston[cln][proid]
end

--- Clear protocol data for client number.
-- @param cln Client number.
function delci(cln)
    pntoids[cln] = nil
    pidston[cln] = nil
end

--- Show message from server on clients.
-- @param cn Client number.
-- @param ti Message title.
-- @param tx Message text.
function showcm(cn, ti, tx)
    if cn.is_a and cn:is_a(lent.logent) then
        cn = cn.cn
    end
    send(cn, CAPI.personal_servmsg, -1, ti, tx)
end