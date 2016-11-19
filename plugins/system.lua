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
    local block = {};
    result["results"]  = block;    
    local obj = {};
	local stdout = juci.shell("cat /tmp/wget-fw.log | tail -4");
	for line in stdout:gmatch("[^\r\n]+") do
		local size= line:match("([%d]*%%)")
        if(size == "100%")then
            local file = io.open("/tmp/version.json", "rb");
            local versionjson = file:read("*a");  
            local json = json.decode(versionjson); 
            local fw_md5sum = juci.shell("md5sum /tmp/firmware.bin | awk '{printf $1}'");
            if(fw_md5sum == json.result.md5sum)then
                obj["progress"] = string.sub(size,0,string.len(size) -1);
                obj["status"] = "ok"; 
            else
                obj["progress"] = string.sub(size,0,string.len(size) -1);
                obj["status"] = "error";  
            end
        else
             obj["progress"] = string.sub(size,0,string.len(size) -1);
             obj["status"] = "downloading";  
        end
        break;
	end	
	
    local is_error = juci.shell("cat /tmp/wget-fw.log | tail -2");
    for line in is_error:gmatch("[^\r\n]+") do
        if(string.find(line,"ERROR"))then
            obj["status"] = "error";
            if(obj["progress"] == nil)then
                obj["progress"] = "";
            end
            break;
        end
    end
    
    table.insert(block, obj);    
    return result;
end


local function get_current_version_number()
    local file = io.open("/etc/openwrt_release", "rb");
    for line in file:lines() do  
        if(string.find(line,"DISTRIB_REVISION="))then
            local current_version = string.gsub(string.sub(line,20,string.len(line)-1),"%p","")
            return current_version;
        end
    end  
    return nil;
end
local function get_current_version_str()
    local file = io.open("/etc/openwrt_release", "rb");
    for line in file:lines() do  
        if(string.find(line,"DISTRIB_REVISION="))then
            return string.sub(line,19,string.len(line)-1);
        end
    end  
    return nil;
end



local function system_check()
	local result = {};
    local block = {};
    local obj = {};
    local tmp_obj = {};
    result["results"]  = block;
    local file = io.open("/tmp/version.json", "rb");
    if(file == nil) then
        os.execute("wget -O /tmp/version.json -o /tmp/wget-version.log https://s3-us-west-2.amazonaws.com/respeaker.io/firmware/version.json")
        os.execute("sleep 3");
    end
    
    local is_error = juci.shell("cat /tmp/wget-version.log | tail -2");
    for line in is_error:gmatch("[^\r\n]+") do
        if(string.find(line,"ERROR"))then
            obj["current_version"] = get_current_version_str();
            obj["latest_version"] = "";
            obj["status"] = "error";
            table.insert(block, tmp_obj);
            table.insert(block, obj);
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
            
            local latest_version = string.sub(json.result.latest_version,2,string.len(json.result.latest_version));
            local latest_version_num = string.gsub(latest_version,"%p","")
            --print(latest_version_num) 
            local version_skip = juci.shell("uci get system.@system[0].version_skip");
            local version_skip_num = string.sub(version_skip,0,string.len(version_skip));
	        --print(version_skip)            

            if(latest_version_num - get_current_version_number() > tonumber(version_skip_num))then
                obj["status"] = "ok";
                table.insert(block, json.result);   
            else
                obj["latest_version"] = json.result.latest_version;
                obj["status"] = "skiped";              
            end           
            file:close();
            break; 
        else
            obj["latest_version"] = "";
            obj["status"] = "checking";                
        end
    end	

    if(obj["status"] ~= "ok")then
        table.insert(block, tmp_obj);
    end
    
    fw_file = io.open("/tmp/firmware.bin", "rb");
    if(fw_file ~= nil)then
        obj["status"] = "downloading"; 
        fw_file:close();
    end
    
    obj["current_version"]= get_current_version_str();
    table.insert(block, obj);
    
    if(obj["status"] ~= "checking")then
        os.execute("rm /tmp/wget-version.log")
        os.execute("rm /tmp/version.json")
    end    

	return result;
end



local function system_upgrade() 
	local result = {};
    os.execute("uci set system.@system[0].version_skip=0");	
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
