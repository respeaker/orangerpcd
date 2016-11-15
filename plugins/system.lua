#!/usr/bin/lua

-- JUCI Lua Backend Server API
-- Copyright (c) 2016 Baozhu Zuo <zuobaozhu@gmail.com>. All rights reserved. 
-- This module is distributed under GNU GPLv3 with additional permission for signed images.
-- See LICENSE file for more details. 

local ubus = require("orange/ubus"); 
local juci = require("orange/core");


local function system_board(msg)
        return ubus.call("system", "board", msg);
end

local function system_info(msg)                   
        return ubus.call("system", "info", msg);   
end 

local function system_get_skip()
        local result = {};                                                                                    
        local stdout = juci.shell("uci get system.@system[0].linkit_firstboot");                                                
        result["results"] = string.sub(stdout,0,string.len(stdout)-1)                                                                    
        return result;  	
end
local function system_set_skip(msg)
--	local msg = json.decode(msgs)
        local result = {};      
        local stdout = juci.shell("uci set system.@system[0].linkit_firstboot=%s",msg.value);
        result["results"] = "done"    
        return result;
end

return {
	board = system_board,
	info = system_info,
	getskip = system_get_skip,
	setskip = system_set_skip
};

