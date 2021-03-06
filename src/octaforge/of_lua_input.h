/*
 * of_lua_input.h, version 1
 * Keyboard / mouse input control for Lua
 *
 * author: q66 <quaker66@gmail.com>
 * license: MIT/X11
 *
 * Copyright (c) 2011 q66
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

/* PROTOTYPES */
extern bool getkeydown();
extern bool getkeyup();
extern bool getmousedown();
extern bool getmouseup();

namespace lua_binds
{
    #define QUOT(arg) #arg
    #define MOUSECLICK(num) \
    LUA_BIND_CLIENT(mouse##num##click, { \
        bool down = (addreleaseaction("CAPI."QUOT(mouse##num##click)"()") != 0); \
        \
        logger::log(logger::INFO, "mouse click: %d (down: %d)\r\n", num, down); \
        if (!(e.hashandle() && ClientSystem::scenarioStarted())) return; \
        \
        /* A click forces us to check for clicking on entities */ \
        TargetingControl::determineMouseTarget(true); \
        vec pos = TargetingControl::targetPosition; \
        \
        int uid = -1; \
        if (TargetingControl::targetLogicEntity && !TargetingControl::targetLogicEntity->isNone()) \
            uid = TargetingControl::targetLogicEntity->getUniqueId(); \
        e.getg("client_click"); \
        if (!e.is<void*>(-1)) \
        { \
            e.pop(1); \
            if (TargetingControl::targetLogicEntity && !TargetingControl::targetLogicEntity->isNone()) \
            { \
                e.getref(TargetingControl::targetLogicEntity->luaRef).t_getraw("client_click"); \
                if (!engine.is<void*>(-1)) send_DoClick(num, (int)down, pos.x, pos.y, pos.z, uid); \
                else \
                { \
                    e.push_index(-2).push(num).push(down).push(pos); \
                    float x; \
                    float y; \
                    gui::getcursorpos(x, y); \
                    e.push(x).push(y).call(6, 1); \
                    bool ret = e.get<bool>(-1); \
                    e.pop(1); \
                    if (!ret) send_DoClick(num, (int)down, pos.x, pos.y, pos.z, uid); \
                } \
                return; \
            } \
            send_DoClick(num, (int)down, pos.x, pos.y, pos.z, uid); \
        } \
        else \
        { \
            e.push(num).push(down).push(pos); \
            if (TargetingControl::targetLogicEntity && !TargetingControl::targetLogicEntity->isNone()) \
                e.getref(TargetingControl::targetLogicEntity->luaRef); \
            else e.push(); \
            float x; \
            float y; \
            gui::getcursorpos(x, y); \
            e.push(x).push(y).call(6, 1); \
            bool ret = e.get<bool>(-1); \
            e.pop(1); \
            if (!ret) send_DoClick(num, (int)down, pos.x, pos.y, pos.z, uid); \
        } \
    })
    MOUSECLICK(1)
    MOUSECLICK(2)
    MOUSECLICK(3)

    bool k_turn_left, k_turn_right, k_look_up, k_look_down;

    #define SCRIPT_DIR(name, v, p, d, s, os) \
    LUA_BIND_CLIENT(name, { \
        if (ClientSystem::scenarioStarted()) \
        { \
            /* stop current actions */ \
            e.getref(ClientSystem::playerLogicEntity->luaRef); \
            e.t_getraw("action_system"); \
            e.t_getraw("clear").push_index(-2).call(1, 0).pop(2); \
            s = addreleaseaction("CAPI."#name"()")!=0; \
            e.getg(#v); \
            if (!e.is<void*>(-1)) e.getg("entity_store") \
                  .t_getraw("get_player_entity") \
                  .call(0, 1) \
                  .t_set(#p, s ? d : (os ? -(d) : 0)) \
                  .pop(3); \
            else e.push(s ? d : (os ? -(d) : 0)).push(s).call(2, 0); \
        } \
    })

    SCRIPT_DIR(turn_left,  do_yaw, yawing, -1, k_turn_left,  k_turn_right);
    SCRIPT_DIR(turn_right, do_yaw, yawing, +1, k_turn_right, k_turn_left);
    SCRIPT_DIR(look_down, do_pitch, pitching, -1, k_look_down, k_look_up);
    SCRIPT_DIR(look_up,   do_pitch, pitching, +1, k_look_up,   k_look_down);

    // Old player movements
    SCRIPT_DIR(backward, do_movement, move, -1, player->k_down,  player->k_up);
    SCRIPT_DIR(forward,  do_movement, move,  1, player->k_up,    player->k_down);
    SCRIPT_DIR(left,     do_strafe, strafe,  1, player->k_left,  player->k_right);
    SCRIPT_DIR(right,    do_strafe, strafe, -1, player->k_right, player->k_left);

    LUA_BIND_CLIENT(jump, {
        if (ClientSystem::scenarioStarted())
        {
            /* stop current actions */
            e.getref(ClientSystem::playerLogicEntity->luaRef);
            e.t_getraw("action_system");
            e.t_getraw("clear").push_index(-2).call(1, 0).pop(2);
            bool down = (addreleaseaction("CAPI.jump()") ? true : false);
            e.getg("do_jump");
            if (!e.is<void*>(-1))
            {
                if (down)
                    e.getg("entity_store")
                     .t_getraw("get_player_entity")
                     .call(0, 1)
                     .t_getraw("jump")
                     .push_index(-2)
                     .call(1, 0).pop(2);
            }
            else e.push(down).call(1, 0);
        }
    })

    LUA_BIND_CLIENT(set_targeted_entity, {
        if (TargetingControl::targetLogicEntity) delete TargetingControl::targetLogicEntity;
        TargetingControl::targetLogicEntity = LogicSystem::getLogicEntity(e.get<int>(1));
        e.push(TargetingControl::targetLogicEntity != NULL);
    })
}
