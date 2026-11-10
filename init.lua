-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 8a7l

local worldpath = minetest.get_worldpath()
local log_dir = worldpath .. "/logs"

minetest.mkdir(log_dir)

local conn_log   = log_dir .. "/connections.log"
local chat_log   = log_dir .. "/chat.log"
local detect_log = log_dir .. "/detection.log"
local err_log    = log_dir .. "/errors.log"

-- Максимальний розмір файлу (10 МБ)
local MAX_LOG_SIZE = 10 * 1024 * 1024 
-- Інтервал перевірки (5 хвилин)
local CHECK_INTERVAL = 5 * 60 

local get_gametime = minetest.get_gametime
local get_players = minetest.get_connected_players
local get_info = minetest.get_player_information

----------------------------------------------------
-- 🔄 СИСТЕМА РОТАЦІЇ ЛОГІВ
----------------------------------------------------
local function rotate_log(filepath)
    local f = io.open(filepath, "r")
    if not f then return end -- Файлу ще немає
    
    -- Перевіряємо розмір
    local size = f:seek("end")
    f:close()
    
    if size > MAX_LOG_SIZE then
        local backup = filepath .. ".old"
        os.remove(backup) -- Видаляємо старий бекап, якщо є
        os.rename(filepath, backup) -- Перейменовуємо поточний у .old
        minetest.log("action", "[lean_logs] Rotated log: " .. filepath)
    end
end

local function check_logs()
    rotate_log(conn_log)
    rotate_log(chat_log)
    rotate_log(detect_log)
    rotate_log(err_log)
    minetest.after(CHECK_INTERVAL, check_logs)
end
-- Запускаємо перевірку раз на 5 хвилин
minetest.after(CHECK_INTERVAL, check_logs)

----------------------------------------------------
-- 🧠 Універсальний логер
----------------------------------------------------
local function log(file, text)
    local f = io.open(file, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. text .. "\n")
        f:close()
    else
        minetest.log("warning", "[lean_logs] Failed to write to " .. file .. ": " .. text)
    end
end

----------------------------------------------------
-- 🚨 ERROR LOGGER
----------------------------------------------------
local original_log = minetest.log
minetest.log = function(level, text)
    if text == nil and type(level) == "string" then text = level; level = "action" end
    if type(level) == "string" then
        local lvl = level:lower()
        if lvl == "error" or lvl == "warning" then
            log(err_log, "[" .. lvl:upper() .. "] " .. text)
        end
    end
    return original_log(level, text)
end

----------------------------------------------------
-- 🔵 JOIN / LEAVE / MULTIACCOUNT
----------------------------------------------------
local ip_map = {}

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local info = get_info(name)
    local ip = (info and info.address) or "unknown"
    log(conn_log, "JOIN: " .. name .. " | IP: " .. ip)

    if ip ~= "unknown" then
        ip_map[ip] = ip_map[ip] or {}
        local already_exists = false
        for _, existing_name in ipairs(ip_map[ip]) do
            if existing_name == name then already_exists = true; break end
        end
        if not already_exists then
            table.insert(ip_map[ip], name)
            if #ip_map[ip] > 1 then
                log(detect_log, "[INFO] MultiAccount IP: " .. ip .. " -> " .. table.concat(ip_map[ip], ", "))
            end
        end
    end
end)

minetest.register_on_leaveplayer(function(player, timed_out)
    local name = player:get_player_name()
    local reason = timed_out and " (timeout)" or ""
    log(conn_log, "LEAVE" .. reason .. ": " .. name)
end)

----------------------------------------------------
-- 💬 CHAT LOG
----------------------------------------------------
minetest.register_on_chat_message(function(name, message)
    log(chat_log, name .. ": " .. message)
end)

----------------------------------------------------
-- ⚔️ AUTOCLICK DETECTION
----------------------------------------------------
local punch_counts = {}

minetest.register_on_punchplayer(function(player, hitter)
    if not hitter or not hitter:is_player() then return end
    local name = hitter:get_player_name()
    
    punch_counts[name] = (punch_counts[name] or 0) + 1
    
    if punch_counts[name] == 16 then
        log(detect_log, "[SUSPICIOUS] AutoClick: " .. name .. " (>15 hits/sec)")
    end
end)

local function reset_punch_counts()
    for k in pairs(punch_counts) do punch_counts[k] = 0 end
    minetest.after(1, reset_punch_counts)
end
minetest.after(1, reset_punch_counts)

----------------------------------------------------
-- 🏃 SPEED / TELEPORT DETECTION
----------------------------------------------------
local last_pos = {}

local function check_speed()
    for _, player in ipairs(get_players()) do
        local name = player:get_player_name()
        local pos = player:get_pos()

        if last_pos[name] then
            local dx = pos.x - last_pos[name].x
            local dy = pos.y - last_pos[name].y
            local dz = pos.z - last_pos[name].z
            local dist_sq = (dx * dx) + (dy * dy) + (dz * dz)

            if dist_sq > 100 then
                local dist = math.sqrt(dist_sq)
                log(detect_log, string.format("[SUSPICIOUS] Speed/Teleport: %s dist=%.1f", name, dist))
            end
        end

        last_pos[name] = { x = pos.x, y = pos.y, z = pos.z }
    end
    
    minetest.after(1, check_speed)
end
minetest.after(1, check_speed)

----------------------------------------------------
-- 🧹 CLEANUP
----------------------------------------------------
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    last_pos[name] = nil
    punch_counts[name] = nil
end)