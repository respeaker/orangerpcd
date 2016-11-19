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
        local stdout = juci.shell("uci get system.@system[0].version_skip");                                                
        result["results"] = string.sub(stdout,0,string.len(stdout)-1)                                                                    
        return result;  	
end
local function system_set_skip(msg)
--	local msg = json.decode(msgs)
        local result = {};      
        local stdout = juci.shell("uci set system.@system[0].version_skip=%s",msg.value);
        result["results"] = "done"    
        return result;
end

local function system_download(msg)
	local result = {};
        os.execute("wget  -O /tmp/firmware.bin -o /tmp/wget-fw.log  -b  https://s3-us-west-2.amazonaws.com/respeaker.io/firmware/ramips-openwrt-latest-LinkIt7688-squashfs-sysupgrade.bin");
	result["results"] = "done"
	return result;
end


local function system_progress()
	local result = {};
    local is_error = juci.shell("cat /tmp/wget-fw.log | tail -2");
    for line in is_error:gmatch("[^\r\n]+") do
        if(string.find(line,"ERROR"))then
            result["results"] ="download failed";
            return result;
        end
    end
    
	local stdout = juci.shell("cat /tmp/wget-fw.log | tail -4");
	for line in stdout:gmatch("[^\r\n]+") do
		local size= line:match("([%d]*%%)")
        if(size == "100%")then
            local file = io.open("/tmp/version.json", "rb");
            local versionjson = file:read("*a");  
            local json = json.decode(versionjson); 
            local fw_md5sum = juci.shell("md5sum /tmp/firmware.bin | awk '{printf $1}'");
            if(fw_md5sum == json.result.md5sum)then
                result["results"] ="download success";
            else
                result["results"] ="download failed";
            end
        else
            result["results"] = string.sub(size,0,string.len(size) -1);
        end
		return result;
	end			
end


local function get_current_version()
    local file = io.open("/etc/openwrt_release", "rb");
    for line in file:lines() do  
        if(string.find(line,"DISTRIB_REVISION="))then
            local current_version = string.gsub(string.sub(line,20,string.len(line)-1),"%p","")
            return current_version;
        end
    end  
    return nil;
end


local function system_check()
	local result = {};
    local file = io.open("/tmp/version.json", "rb");
    if(file == nil) then
        os.execute("wget -O /tmp/version.json -o /tmp/wget-version.log https://s3-us-west-2.amazonaws.com/respeaker.io/firmware/version.json")
        os.execute("sleep 3")
    end
    
    local is_error = juci.shell("cat /tmp/wget-version.log | tail -2");
    for line in is_error:gmatch("[^\r\n]+") do
        if(string.find(line,"ERROR"))then
            result["results"] ="check failed";
            return result;
        end
    end
    
    local stdout = juci.shell("cat /tmp/wget-version.log | tail -4");
    for line in stdout:gmatch("[^\r\n]+") do
        local size= line:match("([%d]*%%)")
        if( size == "100%")then
            local file = io.open("/tmp/version.json", "rb");
            local versionjson = file:read("*a");  
            local json = json.decode(versionjson); 
            
            local tmp_version = string.sub(json.result.version,2,string.len(json.result.version));
            local last_version = string.gsub(tmp_version,"%p","")
            --print(last_version) 
            local tmp_version_skip = juci.shell("uci get system.@system[0].version_skip");
            local version_skip = string.sub(tmp_version_skip,0,string.len(tmp_version_skip));
	        --print(version_skip)            

            if(last_version - get_current_version() > tonumber(version_skip))then
                result["results"] = json.result;
                file:close();
                return result;              
            else
                result["results"] = "no update";
                file:close();
                return result;                
            end
        else
            file:close();
            result["results"] = "checking";
            return result;                
        end
    end	
	return result;
end



local function system_upgrade() 
	local result = {};
	os.execute("sysupgrade /tmp/firmware.bin &");		
	result["results"] = "done"
	return result;
end

return {
	board = system_board,
	info = system_info,
	getskip = system_get_skip,
	setskip = system_set_skip,
	download = system_download,
	progress = system_progress,	
	check = system_check,
	upgrade = system_upgrade
};
