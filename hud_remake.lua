local surface = require("gamesense/surface")
local images = require("gamesense/images")
local csgo_weapons = require("gamesense/csgo_weapons")
local entityinfo = require("gamesense/entity")
local ffi = require("ffi")
local bit = require("bit")
local pan = panorama.open()

local function vmt_entry(instance, index, type)
    return ffi.cast(type, (ffi.cast("void***", instance)[0])[index])
end

local function vmt_bind(module, interface, index, typestring)
    local instance = client.create_interface(module, interface) or error("invalid interface")
    local success, typeof = pcall(ffi.typeof, typestring)
    if not success then
        error(typeof, 2)
    end
    local fnptr = vmt_entry(instance, index, typeof) or error("invalid vtable")
    return function(...)
        return fnptr(instance, ...)
    end
end

local native_Surface_DrawSetColor = vmt_bind("vguimatsurface.dll", "VGUI_Surface031", 15, "void(__thiscall*)(void*, int, int, int, int)")
local native_Surface_DrawFilledRectFade = vmt_bind("vguimatsurface.dll", "VGUI_Surface031", 123, "void(__thiscall*)(void*, int, int, int, int, unsigned int, unsigned int, bool)")

local function reverse_table(tbl) -- THANKS FINI <33333
    local new_tbl = {}
    for i = 1, #tbl do
        new_tbl[#tbl + 1 - i] = tbl[i]
    end
    return new_tbl
end

local function string_cut(s1, num)
    if string.len(tostring(s1)) > num then
        return num == 0 and s1 or string.sub(s1, 1, num - 3).. "..."
    end
    return s1
end

local function clamp(a, lowerNum, higher)
    if a > higher then
        return higher
    elseif a < lowerNum then
        return lowerNum
    else
        return a
    end
end

-- stole these beatlings from tony ty sir
local Lerp = function(delta, from, to) -- wtf why were these globals thats so exploitable!
    if (delta > 1) then
        return to
    end
    if (delta < 0) then
        return from
    end
    return from + (to - from) * delta
end

local ColorRange = function(value, ranges) -- ty tony for dis function u a homie
    if value <= ranges[1].start then
        return ranges[1].color
    end
    if value >= ranges[#ranges].start then
        return ranges[#ranges].color
    end

    local selected = #ranges
    for i = 1, #ranges - 1 do
        if value < ranges[i + 1].start then
            selected = i
            break
        end
    end
    local minColor = ranges[selected]
    local maxColor = ranges[selected + 1]
    local lerpValue = (value - minColor.start) / (maxColor.start - minColor.start)
    return {
        Lerp(lerpValue, minColor.color[1], maxColor.color[1]),
        Lerp(lerpValue, minColor.color[2], maxColor.color[2]),
        Lerp(lerpValue, minColor.color[3], maxColor.color[3]),
        Lerp(lerpValue, minColor.color[4], maxColor.color[4]),
    }
end

local opts = {
    enabled = ui.new_checkbox("VISUALS", "Effects", "INSANE HUD"),
    color = ui.new_color_picker("VISUALS", "Effects",  "INSANE HUD COLOR", 255, 255, 255, 255),
    outlines = ui.new_slider("VISUALS", "Effects", "Outlines on hud", 4, 100, 100, true, "%", 1, {[4] = "Off"}),
    hud_bottom =  ui.new_checkbox("VISUALS", "Effects", "Round info on bottom"),
    use_num =  ui.new_checkbox("VISUALS", "Effects", "Use numbers for teams"),
    icons =  ui.new_checkbox("VISUALS", "Effects", "Use icons for hp & ap"),
    stance =  ui.new_checkbox("VISUALS", "Effects", "Show stance"),
    stance_color =  ui.new_color_picker("VISUALS", "Effects", "Stance colorpicker", 255, 255, 255, 230),
    alt_chat =  ui.new_checkbox("VISUALS", "Effects", "Alternative chat method"),
    bad_label = ui.new_label("VISUALS", "Effects", "Bad color"),
    bad_color = ui.new_color_picker("VISUALS", "Effects", "Bad colorpicker", 252, 65, 100, 255),
    unselected_label = ui.new_label("VISUALS", "Effects", "Unselected weapon color"),
    unselected_color = ui.new_color_picker("VISUALS", "Effects", "Unselected weapon colorpicker", 127, 127, 127, 200),
    ct_label = ui.new_label("VISUALS", "Effects", "CT color"),
    ct_color = ui.new_color_picker("VISUALS", "Effects", "CT colorpicker", 56, 159, 252, 255),
    t_label = ui.new_label("VISUALS", "Effects", "T color"),
    t_color = ui.new_color_picker("VISUALS", "Effects", "T colorpicker", 255, 50, 50, 255),
    killfeed_label = ui.new_label("VISUALS", "Effects", "Kill feed color"),
    killfeed_color = ui.new_color_picker("VISUALS", "Effects", "kill feed colorpicker", 255, 50, 50, 255),

    kill_feed = ui.reference("MISC", "Miscellaneous", "Persistent kill feed"),
}

local fonts = {
    ui_big = surface.create_font("Tahoma Bold", 22, 200, 0x010),
    ui_small = surface.create_font("Tahoma Bold", 16, 200, 0x010),
    ui_smallest = surface.create_font("Tahoma Bold", 12, 200, 0x010),
    sb = surface.create_font("Arial Bold", 24, 200, 0x000),
}

local render = {
    images = {
        helm = images.get_panorama_image("icons/equipment/armor_helmet.svg"),
        armor = images.get_panorama_image("icons/equipment/armor.svg"),
        defuser = images.get_panorama_image("hud/deathnotice/icon-defuser.png"),
        bomb = images.get_panorama_image("icons/ui/bomb_c4.svg"),
        zues = images.get_panorama_image("icons/equipment/taser.svg"),
        health = images.get_panorama_image("icons/ui/health.svg"),
        armor_hud = images.get_panorama_image("icons/ui/armor.svg"),
        helm_hud = images.get_panorama_image("hud/healtharmor/icon-armor-helmet.png"),
        boom = images.get_panorama_image("icons/ui/bomb.svg"),
        skullington = images.get_panorama_image("hud/teamcounter/teamcounter_skull-ct.png"),
        --explosioin = icons/ui/bomb.svg

        -- these r for kill effects
        headshot = images.get_panorama_image("hud/deathnotice/icon-headshot.png"),
        noscope = images.get_panorama_image("hud/deathnotice/noscope.svg"),
        thrusmoke = images.get_panorama_image("hud/deathnotice/smoke_kill.svg"),
        thruwall = images.get_panorama_image("hud/deathnotice/penetrate.svg"),
        skull = images.get_panorama_image("hud/voicestatus/skull.png"),

        -- these are for the stance indicator shit
        -- standing = images.load(readfile("csgo/materials/stand.png")),
        -- crouching = images.load(readfile("csgo/materials/crouch.png")),

        --bots n stuff
        ct = images.get_panorama_image("icons/scoreboard/avatar-ct.png"),
        t = images.get_panorama_image("icons/scoreboard/avatar-terrorist.png"),
       

    }
}

render.filled_rect = function(x, y, w, h, clr)
    surface.draw_filled_rect(x, y, w, h, clr[1], clr[2], clr[3], clr[4])
end

render.draw_text = function(x, y, clr, font, text)
    surface.draw_text(x, y, clr[1], clr[2], clr[3], clr[4], font, text)
end

render.centered_text = function(x, y, clr, font, text)
    local t_w, _ = surface.get_text_size(font, text)
    surface.draw_text(x - math.floor(t_w/2), y, clr[1], clr[2], clr[3], clr[4], font, text)
end

render.gradient = function(x, y, w, h, color1, color2, horizontal)
    native_Surface_DrawSetColor(color1[1], color1[2], color1[3], color1[4])
    native_Surface_DrawFilledRectFade(x, y, x + w, y + h, 255, 0, horizontal)

    native_Surface_DrawSetColor(color2[1], color2[2], color2[3], color2[4])
    return native_Surface_DrawFilledRectFade(x, y, x + w, y + h, 0, 255, horizontal)
end 

render.two_way_gradient = function(x, y, w, h, color, p)
    local percent = math.floor(w * p)

    render.gradient(x, y, percent, h, {0, 0, 0, 0}, color, true)
    render.gradient(x + percent, y, w - percent, h, color, {0, 0, 0, 0}, true)
    
end

render.background = function(x, y, w, h, color, dir, per)
    local size_p = per == nil and .90 or per
    local percent = math.floor(w * size_p)

    if dir == 1 or dir == nil then
        render.gradient(x, y, w, h, {0, 0, 0, color[4]}, {0, 0, 0, 0}, true)
        --render.solid_gradient(x, y, w, h, {0, 0, 0, 250}, 1)

        surface.draw_filled_rect(x + 1, y + 1, 1, h - 2, color[1], color[2], color[3], color[4])
        render.gradient(x + 2, y + 1, percent, 1, {color[1], color[2], color[3], color[4]}, {color[1], color[2], color[3], 0}, true)
        render.gradient(x + 2, y + h - 2, percent, 1, {color[1], color[2], color[3], color[4]}, {color[1], color[2], color[3], 0}, true)
    elseif dir == 2 then
        render.gradient(x, y, w, h, {0, 0, 0, 0}, {0, 0, 0, color[4]}, true)

        surface.draw_filled_rect(x + w - 2, y + 1, 1, h - 2, color[1], color[2], color[3], color[4])

        render.gradient(x + (w - percent) - 2, y + 1, percent, 1, {color[1], color[2], color[3], 0}, {color[1], color[2], color[3], color[4]}, true)
        render.gradient(x + (w - percent) - 2, y + h - 2, percent, 1, {color[1], color[2], color[3], 0}, {color[1], color[2], color[3], color[4]}, true)
    end
end

render.bar = function(x, y, w, value, max, color, text, anim)
    local bad_clr = {ui.get(opts.bad_color)}
    local h = 30

    local bar_text = tostring(math.floor(value))
    local t_w, t_h = surface.get_text_size(fonts.ui_small, text)
    local t_w2, t_h2 = surface.get_text_size(fonts.ui_big, bar_text)

    render.draw_text(x, y + h - t_h + 4, {color[1], color[2], color[3], 250}, fonts.ui_small, text)

    local percent = value/max
    local rel_width = math.floor(w * percent)

    local bar_clr = color    

    if percent < 1 then
        local sub_width = w - rel_width

        render.gradient(x + t_w + 4 + rel_width, y + 20, sub_width, 10, {100, 100, 100, 0}, {100, 100, 100, 10}, false)
        surface.draw_filled_rect(x + t_w + 4 + rel_width, y + h, sub_width, 1, 100, 100, 100, 120)

        if anim ~= nil then
            if anim.time + 1 >= globals.realtime() and anim.value ~= 0 then

                local dmg_percent = anim.value/max
                local time_percent = 1 - clamp(globals.realtime() - anim.time, 0, 1)

                local anim_width = math.floor((w * dmg_percent) * time_percent)

                -- it looks alright just could look better, nate please ease this when you can and itll probs look a lot better
                -- render.gradient(x + t_w + 4 + rel_width, y + 20, anim_width, 10, {252, 65, 100, 0}, {252, 65, 100, 20}, false)
                -- surface.draw_filled_rect(x + t_w + 4 + rel_width, y + h, anim_width, 1, 252, 65, 100, 150)

                bar_clr = ColorRange(time_percent, { [1] = { start = 0, color = {color[1], color[2], color[3], 250} }, [2] = { start = 1, color = {bad_clr[1], bad_clr[2], bad_clr[3], 250} } } )
                
            end

        end
    end

    render.gradient(x + t_w + 4, y + 20, rel_width, 10, {bar_clr[1], bar_clr[2], bar_clr[3], 0}, {bar_clr[1], bar_clr[2], bar_clr[3], 20}, false)
    surface.draw_filled_rect(x + t_w + 4, y + h, rel_width, 1, bar_clr[1], bar_clr[2], bar_clr[3], 250)

    render.draw_text(x + t_w + 6 , y + h - t_h2, value == 0 and {100, 100, 100, 120} or {bar_clr[1], bar_clr[2], bar_clr[3], 250}, fonts.ui_big, bar_text)
end

render.icon_bar = function(x, y, w, value, max, color, icon, anim)
    local i_w, i_h = icon:measure(nil, 15)
    icon:draw(x, y + 30 - i_h, i_w, i_h, color[1], color[2], color[3], 250)

    render.bar(x + i_w, y, w, value, max, color, "", anim)
end

render.weapon_thingy = function(x, y, clr, wep_info)
    local text = wep_info.name

    local wep_w, wep_h = wep_info.icon:measure()
    local half_h = math.floor(wep_h/2)
    --print(wep_h)
    -- local txt_w, txt_h = surface.get_text_size(fonts.ui_small, text)

    -- local unselected_color = {ui.get(opts.unselected_color)}
    -- unselected_color[4] = unselected_color[4] * .8
    -- render.draw_text(x - txt_w, y - 2, unselected_color, fonts.ui_small, text)
    local y_adjust = wep_info.data.type == "grenade" and 4 or 0
    wep_info.icon:draw(x - wep_w, y - half_h - y_adjust, nil, nil, clr[1], clr[2], clr[3], 230)

    return wep_w --txt_w > wep_w and txt_w or wep_w
end

render.ammo_counter = function(x, y, w, clr, wep_info, local_player)
    
    local bad_clr = {ui.get(opts.bad_color)}

    local entityinfo_player = entityinfo.new(local_player)
    local ammo = wep_info.clip
    local max_ammo = wep_info.max_clip
    local reserve = wep_info.reserve
    local in_activity = 0
     
    local anim_layer = entityinfo_player:get_anim_overlay(1)
    local activity = entityinfo_player:get_sequence_activity(anim_layer.sequence)

    local h = 30
    local percent = ammo/max_ammo
     
    if activity == 967 and anim_layer.weight ~= 0 and anim_layer.weight ~= nil and anim_layer.cycle ~= nil then
      --[[reloading]]
        in_activity = 1
        percent = anim_layer.cycle
    end
    --commented out because too inacurate
    -- if activity == 972 and anim_layer.weight ~= 0 and anim_layer.weight ~= nil and anim_layer.cycle ~= nil then
    --   --[[drawing]]
    --     percent = anim_layer.cycle * percent
    --     in_activity = 2
    -- end
    local rel_width = math.floor(w * percent)
     


    if percent < 1 then
        local sub_width = w - rel_width

        render.gradient(x + 4 + rel_width, y + 20, sub_width, 10, {100, 100, 100, 0}, {100, 100, 100, 10}, false)
        surface.draw_filled_rect(x + 4 + rel_width, y + h, sub_width, 1, 100, 100, 100, 120)

    end

    local bar_clr = {clr[1], clr[2], clr[3], 250}
    if in_activity == 0 then
        bar_clr = ColorRange(percent, { [1] = { start = 0, color = {bad_clr[1], bad_clr[2], bad_clr[3], 250} }, [2] = { start = .5, color = {clr[1], clr[2], clr[3], 250} } } )
    end

    render.gradient(x + 4, y + 20, rel_width, 10, {bar_clr[1], bar_clr[2], bar_clr[3], 0}, {bar_clr[1], bar_clr[2], bar_clr[3], 20}, false)
    surface.draw_filled_rect(x + 4, y + h, rel_width, 1, bar_clr[1], bar_clr[2], bar_clr[3], 250)


    if in_activity == 1 then
        local str_percent = tostring(math.floor(percent * 100))

        local t_w, t_h = surface.get_text_size(fonts.ui_big, str_percent)
        render.draw_text(x + 6 , y + h - t_h, {bar_clr[1], bar_clr[2], bar_clr[3], 250}, fonts.ui_big, str_percent)

        local t_w2, t_h2 = surface.get_text_size(fonts.ui_small, "%")
        render.draw_text(x + 8 + t_w , y + h - t_h2, {clr[1], clr[2], clr[3], 250}, fonts.ui_small, "%")
    else
        local t_w, t_h = surface.get_text_size(fonts.ui_big, tostring(ammo))
        render.draw_text(x + 6 , y + h - t_h, {bar_clr[1], bar_clr[2], bar_clr[3], 250}, fonts.ui_big, tostring(ammo))

        local t_w2, t_h2 = surface.get_text_size(fonts.ui_small, tostring(reserve))
        render.draw_text(x + 8 + t_w , y + h - t_h2, reserve ~= 0 and {clr[1], clr[2], clr[3], 250} or {100, 100, 100, 120}, fonts.ui_small, "/".. tostring(reserve))
    end
end


local function rotate_points_around(points,ox,oy,r)
    local yx, yy = math.sin(r), math.cos(r) -- x axis
    local xx, xy = math.sin(r+math.pi/2), math.cos(r+math.pi/2) -- y axis
    
    local output = { }
    for i = 1, #points, 2 do
        local x, y = points[i], points[i+1]
        local x1 = x * xx
        local y1 = x * xy
        x1 = x1 + y * yx + ox
        y1 = y1 + y * yy + oy
        table.insert(output, x1)
        table.insert(output, y1)
    end
    return table.unpack(output)
end

render.shell = function(ox,oy,s,r,t) -- s is size

    local clr = {ui.get(opts.color)}

    t = t or 1
    t = math.max(0, t)
    local h = s*2 -- height of the casing
    local x, y, x1, y1, x2, y2, x3, y3 = rotate_points_around({-s, -h, -s, h, s, -h, s, h}, ox, oy, r)
    renderer.triangle(x,y,x1,y1,x2,y2,clr[1],clr[2],clr[3],t*255)
    renderer.triangle(x1,y1,x2,y2,x3,y3,clr[1],clr[2],clr[3],t*255)
end

local shells = {}
render.shells = function(pos_x, pos_y)
    for i = 1, -20 do
        local y = 2*((i*s)+1)^2+5
    end
    -- for i = 1, 5 do
    --     render.shell(pos_x + i*7,pos_y,2.9,-0.2,1)
    -- end
    for k, shell in next, shells do
        math.randomseed(shell.r)
        local vel = math.random(20+(shell.time*1000%10),70)/10+(shell.r1) --.1 for float
          local vel1 = math.random(100, 400)/1000+(shell.r1) -- just separate the double tap shells with r1
        local s = 20 -- anim speed
        local i = globals.realtime()-shell.time -- ofset
        local x = i*s * 20 * vel1
        local y = (vel1*((i*s)-vel)^2+5)-(vel1*(0-vel)^2+5) -- two to make each start from the same spot
        render.shell(pos_x-x, pos_y+y, 3, i*s-0.3, 1-i*2)
        if i > 2 then shells[k] = nil end
    end
    for k, v in next, shells do
        if shells[k] == nil then table.remove(shells, k) end
    end
end

local last_money_notice = 0
local money_notices = {}
render.money = function(x, y, money, color)
    
    color[4] = color[4] * clamp(last_money_notice + 7 - globals.realtime(), 0, 1)
    if ui.get(opts.outlines) ~= 4 then
        render.background(x, y, 150, 30, color, 1, (ui.get(opts.outlines)/100 ) * .9)
    else
        render.gradient(x, y, 150, 30, {0, 0, 0, 240 * clamp(last_money_notice + 7 - globals.realtime(), 0, 1)}, {0, 0, 0, 0}, true )
    end
    render.draw_text(x + 10, y + 3, color, fonts.ui_big, "$"..tostring(money))

    local y_pos = y + 29
    for k, v in pairs(reverse_table(money_notices)) do
        local clr = v.color
        clr[4] = clr[4] * clamp(v.time + 5 - globals.realtime(), 0, 1)
        render.draw_text(x + 2, y_pos, clr, fonts.ui_small, v.render)
        y_pos = y_pos+ 16
    end

    for k, v in pairs(money_notices) do
        if v.time + 6 < globals.realtime() then
            table.remove(money_notices, k)
        end
    end
end

local primaries = {
    smg = true,
    rifle = true,
    shotgun = true,
    sniperrifle = true,
    machinegun = true,
}

local function get_weapon_group(data)
    if primaries[data.type] ~= nil then
        return 1
    elseif data.type == "pistol" or data.name == "Desert Eagle" then
        return 2
    elseif data.type == "knife" or data.type == "taser" then
        return 3
    elseif data.type == "grenade" then
        return 4
    elseif data.type == "c4" then
        return 5
    else
        return 6
    end
end

local grenade_score = {
    ["HE Grenade"] = 5,
    ["Flashbang"] = 4,
    ["Smoke Grenade"] = 3,
    ["Decoy Grenade"] = 2,
    ["Molotov"] = 1,
    ["Incen Grenade"] = 1,
}

local function reorginize_weapons_by_slots(weapons)
    local return_tbl = {
        [1] = {},
        [2] = {},
        [3] = {},
        [4] = {},
        [5] = {},
        [6] = {}
    }

    for k, wep in pairs(weapons) do
        table.insert(return_tbl[get_weapon_group(wep.data)], wep)
    end

    if #return_tbl[4] > 1 then -- this is so they show up in the correct order
        table.sort(return_tbl[4], function(k1, k2) 
            return (grenade_score[k1.name] ~= nil and grenade_score[k1.name] or 0) > (grenade_score[k2.name] ~= nil and grenade_score[k2.name] or 0)
        end)
    end

    return return_tbl
end

local last_wep_group = 0
local group_switch_time = 0
render.weapons = function(x, y, weapons, cur_wep, clr, switch_time)
    local off_clr = {ui.get(opts.unselected_color)}
    
    local drawn = reorginize_weapons_by_slots(weapons)

    local cur_wep_group = get_weapon_group(cur_wep.data)

    local y_pos = y - 40
    for i = 6, 1, -1 do
        if #drawn[i] > 0 then
            if i == cur_wep_group then
                render.background(x - 200, y_pos, 200, 40, clr, 2, clamp((globals.realtime() - group_switch_time) * 4, 0, .9))
            else
                render.gradient(x - 200, y_pos, 200, 40, {0, 0, 0, 0}, {0, 0, 0, 250}, true )
            end

            render.draw_text(x - 12, y_pos + 2, i == cur_wep_group and clr or off_clr, fonts.ui_smallest, tostring(i))

            local x_pos = x - 20
            for k, wep in pairs(drawn[i]) do
                local icon = images.get_weapon_icon(wep.index)
                local i_w, i_h = icon:measure(nil, 30)

                local pos_y = i ~= 4 and y_pos + 20 - math.floor(i_h/2) or y_pos + 20 - math.floor(i_h/2) - 2
                if wep.name == cur_wep.name then
                    local color = ColorRange(clamp((globals.realtime() - switch_time) * 4, 0, 1), { [1] = { start = 0, color = {off_clr[1], off_clr[2], off_clr[3], off_clr[4]} }, [2] = { start = 1, color = {clr[1], clr[2], clr[3], clr[4]} } } )
                    icon:draw(x_pos - i_w, pos_y, i_w, i_h, color[1], color[2], color[3], color[4])
                else
                    icon:draw(x_pos - i_w, pos_y, i_w, i_h, off_clr[1], off_clr[2], off_clr[3], off_clr[4])
                end
                x_pos = x_pos - i_w - 6
            end

            if i == cur_wep_group then
                local text_size = {surface.get_text_size(fonts.ui_small, cur_wep.name)}
                local color = { -- idk why i have to do this shit if i just do color = clr then it copys the fucking pointer and modifies the original fucking table great coding fucking 3rd worlders
                    [1] = clr[1],
                    [2] = clr[2],
                    [3] = clr[3],
                    [4] = switch_time + 2 < globals.realtime() and clr[4] * clamp((switch_time + 3) - globals.realtime(), 0, 1) or clr[4] * clamp((globals.realtime() - switch_time) * 4, 0, 1)
                }
                if color[4] ~= 0 then
                    render.draw_text(x_pos - text_size[1], y_pos + 20 - text_size[2]/2, color, fonts.ui_small, cur_wep.name)
                end
            end

            y_pos = y_pos - 45
        end
    end

    if cur_wep_group ~= last_wep_group then
        group_switch_time = globals.realtime()
    end
    last_wep_group = cur_wep_group
end

local function get_player_team(player)
    local teamnum = entity.get_prop(player, "m_iTeamNum")
    if teamnum == 3 then
        return "CT"
    elseif teamnum == 2 then
        return "T"
    else
        return "SPEC"
    end
end

--[[
headshot = images.get_panorama_image("hud/deathnotice/icon-headshot.png"),
noscope = images.get_panorama_image("hud/deathnotice/noscope.svg"),
thrusmoke = images.get_panorama_image("hud/deathnotice/smoke_kill.svg"),
thruwall = images.get_panorama_image("hud/deathnotice/penetrate.svg"),
skull = images.get_panorama_image("hud/voicestatus/skull.png"),
]]
local kills_for_feed = {}
render.kill_feed = function(x, y)
    local clrs = {
        ["CT"] = {ui.get(opts.ct_color)},
        ["T"] = {ui.get(opts.t_color)},
        ["SPEC"] = {255, 255, 255, 255},
        ["killfeed"] = {ui.get(opts.killfeed_color)}
    }

    local y_pos = y
    for k, v in pairs(reverse_table(kills_for_feed)) do
        local fade_in = clamp((globals.realtime() - v.time) * 2, 0, 1)
        local global_alpha = 1

        if v.type == "Local kill" then
            if ui.get(opts.kill_feed) then
                global_alpha = 1
            else
                global_alpha = clamp(v.time + 40 - globals.realtime(), 0, 1)
            end
        elseif v.type == "Local death" then
            global_alpha = clamp(v.time + 30 - globals.realtime(), 0, 1)
        else
            global_alpha = clamp(v.time + 20 - globals.realtime(), 0, 1)
        end
        global_alpha = 250 * global_alpha

        for k1, v1 in pairs(clrs) do
            v1[4] = global_alpha
        end
        
        if global_alpha > 0 then

            local dead_w, _ = surface.get_text_size(fonts.ui_small, v.dead)
            local w_add = 8 + dead_w

            if v.headshot then
                local icon = render.images.headshot
                local i_w, i_h = icon:measure(nil, 22)
                w_add = w_add + i_w + 6
            end

            if v.thruwall then
                local icon = render.images.thruwall
                local i_w, i_h = icon:measure(nil, 22)
                w_add = w_add + i_w + 6
            end

            if v.thrusmoke then
                local icon = render.images.thrusmoke
                local i_w, i_h = icon:measure(nil, 22)
                w_add = w_add + i_w + 6
            end

            if v.weapon ~= "world" then
                local icon = images.get_weapon_icon(v.weapon)
                local weapon_w, weapon_h = icon:measure(nil, 22)
                w_add = w_add + weapon_w + 6
            else
                local weapon_w, weapon_h = render.images.skull:measure(nil, 22)
                w_add = w_add + weapon_w + 6
            end

            if v.noscope then
                local icon = render.images.noscope
                local i_w, i_h = icon:measure(nil, 22)
                w_add = w_add + i_w + 6
            end

            if v.assister ~= nil then
                local assist_w, _ = surface.get_text_size(fonts.ui_small, v.assister)
                w_add = w_add + 6 + assist_w

                local plus_w, _ = surface.get_text_size(fonts.ui_small, "+ ")
                w_add = w_add + plus_w
            end
            
            local killer_w, _ = surface.get_text_size(fonts.ui_small, v.killer)
            w_add = w_add + 6 + killer_w

            local total_w = (w_add + 40) * fade_in

            if v.type == "Local kill" then
                render.background(x - total_w, y_pos, total_w, 26, {clrs.killfeed[1], clrs.killfeed[2], clrs.killfeed[3], global_alpha * fade_in}, 2)
            elseif v.type == "Local death" then
                render.gradient(x - total_w, y_pos, total_w, 26, {140, 50, 50, 0}, {clrs.killfeed[1] * .6, clrs.killfeed[2] * .6, clrs.killfeed[3] * .6, global_alpha * fade_in}, true)
            else
                render.gradient(x - total_w, y_pos, total_w, 26, {0, 0, 0, 0}, {0, 0, 0, global_alpha * fade_in}, true)
            end


            -- ACTUAL SHIT


            local dead_w, _ = surface.get_text_size(fonts.ui_small, v.dead)
            local w_add = 8 + dead_w
            render.draw_text(x - w_add, y_pos + 5, clrs[v.dead_team], fonts.ui_small, v.dead)

            if v.headshot then
                local icon = render.images.headshot
                local i_w, i_h = icon:measure(nil, 22)
                w_add = w_add + i_w + 6
                icon:draw(x - w_add, y_pos + 2, i_w, i_h, 255, 255, 255, global_alpha)
            end

            if v.thruwall then
                local icon = render.images.thruwall
                local i_w, i_h = icon:measure(nil, 22)
                w_add = w_add + i_w + 6
                icon:draw(x - w_add, y_pos + 2, i_w, i_h, 255, 255, 255, global_alpha)
            end

            if v.thrusmoke then
                local icon = render.images.thrusmoke
                local i_w, i_h = icon:measure(nil, 22)
                w_add = w_add + i_w + 6
                icon:draw(x - w_add, y_pos + 2, i_w, i_h, 255, 255, 255, global_alpha)
            end

            if v.noscope then
                local icon = render.images.noscope
                local i_w, i_h = icon:measure(nil, 22)
                w_add = w_add + i_w + 6
                icon:draw(x - w_add, y_pos + 2, i_w, i_h, 255, 255, 255, global_alpha)
            end

            if v.weapon ~= "world" then
                local icon = images.get_weapon_icon(v.weapon)
                local weapon_w, weapon_h = icon:measure(nil, 22)
                w_add = w_add + weapon_w + 6
                icon:draw(x - w_add, y_pos + 2, weapon_w, weapon_h, 255, 255, 255, global_alpha)
            else
                local weapon_w, weapon_h = render.images.skull:measure(nil, 22)
                w_add = w_add + weapon_w + 6
                render.images.skull:draw(x - w_add, y_pos + 2, weapon_w, weapon_h, 255, 255, 255, global_alpha)
            end  

            if v.assister ~= nil then
                local assist_w, _ = surface.get_text_size(fonts.ui_small, v.assister)
                w_add = w_add + 6 + assist_w
                render.draw_text(x - w_add, y_pos + 5, clrs[v.assister_team], fonts.ui_small, v.assister)

                local plus_w, _ = surface.get_text_size(fonts.ui_small, "+ ")
                w_add = w_add + plus_w
                render.draw_text(x - w_add - 2, y_pos + 5, {255, 255, 255, global_alpha}, fonts.ui_small, "+ ")
            end
            
            local killer_w, _ = surface.get_text_size(fonts.ui_small, v.killer)
            w_add = w_add + 6 + killer_w
            render.draw_text(x - w_add, y_pos + 5, clrs[v.killer_team], fonts.ui_small, v.killer)


            y_pos = y_pos + (30 * (global_alpha/250))
        end
    end
end

local function get_c4_time(ent)
    local c4_time = entity.get_prop(ent, "m_flC4Blow") - globals.curtime()
    return c4_time ~= nil and c4_time or 0
end

local function ClockTime(seconds)
    if seconds < 0 then seconds = 0 end
    local mins = string.format("%02.f", math.floor(seconds / 60));
    local secs = string.format("%02.f", math.floor(seconds - 0 * 3600 - mins * 60));

    return string.format('%s:%s', mins, secs)
end

local function get_pfp(player, size)
    local steam_id = entity.get_steam64(player)
    local avatar = nil
    if steam_id ~= 0 then
        native_Surface_DrawSetColor(255, 255, 255, 255)
        avatar = images.get_steam_avatar(steam_id, size == nil and 15 or size)
    end
    if steam_id == 0 or avatar == nil then
        local team = get_player_team(player)
        if team == "T" then
            return render.images.t
        else
            return render.images.ct
        end
    end
    return avatar
end

local last_alive_ct = 0
local ct_color_time = 0
local last_alive_t = 0
local t_color_time = 0
render.score_and_time = function(x, y, players)
    local clrs = {
        ["CT"] = {ui.get(opts.ct_color)},
        ["T"] = {ui.get(opts.t_color)},
    }
    local bad_clr = {ui.get(opts.bad_color)}

    render.filled_rect(x - 25, y, 50, 20, {0, 0, 0, 200})
    local c4 = entity.get_all("CPlantedC4")[1]
    if c4 ~= nil then 
        local c4_time = get_c4_time(c4)
        if entity.get_prop(c4, "m_bBombDefused") == 1 then
            local c4_w, c4_h = render.images.bomb:measure(nil, 26)
            render.images.bomb:draw(x - math.floor(c4_w/2), y - 4, c4_w, c4_h, clrs.CT[1], clrs.CT[2], clrs.CT[3], clrs.CT[4]) -- if only table.unpack worked properly
        else
            if c4_time > -1 then
                local c4_w, c4_h = render.images.bomb:measure(nil, 26)
                render.images.bomb:draw(x - math.floor(c4_w/2), y - 4, c4_w, c4_h, 255, 255, 255, 240)
                if c4_time > 0 then
                    render.filled_rect(x - 25, y + 18, 50 * (c4_time/40), 2, clrs.T)
                end
            else
                local c4_w, c4_h = render.images.boom:measure(nil, 26)
                render.images.boom:draw(x - math.floor(c4_w/2), y - 4, c4_w, c4_h, clrs.T[1], clrs.T[2], clrs.T[3], clrs.T[4])
            end
        end
    else
        local time = ClockTime(entity.get_prop(entity.get_game_rules(), 'm_iRoundTime') - (globals.curtime() - entity.get_prop(entity.get_game_rules(), "m_fRoundStartTime")))
        local text_w, _ = surface.get_text_size(fonts.ui_small, time)
        render.draw_text(x - math.floor(text_w/2), y + 2, {255, 255, 255, 240}, fonts.ui_small, time)
    end

    local teams = json.parse(tostring(pan.GameStateAPI.GetScoreDataJSO()))


    -- ct score
    render.filled_rect(x - 25, y + 24, 23, 20, {0, 0, 0, 200})
    local ct_score = tostring(teams.teamdata.CT.score)
    local text_w, _ = surface.get_text_size(fonts.ui_small, ct_score)
    render.draw_text(x - math.floor(text_w/2) - 13, y + 26, clrs.CT, fonts.ui_small, ct_score)

    -- t score
    render.filled_rect(x + 2, y + 24, 23, 20, {0, 0, 0, 200})
    local t_score = tostring(teams.teamdata.TERRORIST.score)
    local text_w, _ = surface.get_text_size(fonts.ui_small, t_score)
    render.draw_text(x - math.floor(text_w/2) + 14, y + 26, clrs.T, fonts.ui_small, t_score)

    -- alive players

    if ui.get(opts.use_num) then
        local alive_ct = 0
        local alive_t = 0
        for k, v in pairs(players.CT) do
            if entity.is_alive(v) then
                alive_ct = alive_ct + 1
            end
        end
        for k, v in pairs(players.T) do
            if entity.is_alive(v) then
                alive_t = alive_t + 1
            end
        end

        -- CT alive players
        
        if last_alive_ct > alive_ct then
            ct_color_time = globals.realtime()
        end

        render.background(x - 78 , y - 1, 50, 45, clrs.CT, 2)
        local text_w, _ = surface.get_text_size(fonts.ui_big, tostring(alive_ct))
        local color = ColorRange(clamp((globals.realtime() - ct_color_time), 0, 1), { [1] = { start = 0, color = bad_clr }, [2] = { start = 1, color = clrs.CT } } )
        render.draw_text(x - math.floor(text_w/2) - 50, y + 10, color, fonts.ui_big, tostring(alive_ct))

        --T alive players

        if last_alive_t > alive_t then
            t_color_time = globals.realtime()
        end

        render.background(x + 28, y - 1, 50, 45, clrs.T, 1)
        local text_w, _ = surface.get_text_size(fonts.ui_big, tostring(alive_t))
        local color = ColorRange(clamp((globals.realtime() - t_color_time), 0, 1), { [1] = { start = 0, color = bad_clr }, [2] = { start = 1, color = clrs.T } } )
        render.draw_text(x - math.floor(text_w/2) + 50, y + 10, color, fonts.ui_big, tostring(alive_t))

        --extra bs

        last_alive_ct = alive_ct
        last_alive_t = alive_t
    else

        --CT players
        render.background(x - 228 , y - 1, 200, 45, clrs.CT, 2)
        local x_pos = x - 50
        local y_pos = y + 3
        for k, v in pairs(players.CT) do

            local esp_data = entity.get_esp_data(v)
            if esp_data.health ~= 0 then
                render.filled_rect(x_pos, y_pos, 17, 17, clrs.CT)
                local avatar = get_pfp(v)
                avatar:draw(x_pos + 1, y_pos + 1, 15, 15, 255, 255, 255, 255)

                if esp_data.health < 100 then
                    renderer.rectangle(x_pos + 1, y_pos + 15, 15 * (esp_data.health/100), 1, 255, 255, 255, 250)
                end
            else
                render.filled_rect(x_pos, y_pos, 17, 17, {clrs.CT[1], clrs.CT[2], clrs.CT[3], clrs.CT[4] * .1})
                render.images.skull:draw(x_pos + 1, y_pos + 1, 15, 15, bad_clr[1], bad_clr[2], bad_clr[3], bad_clr[4] * .8)
            end

            if y_pos > y + 20 then
                y_pos = y + 3
                x_pos = x_pos - 20
            else
                y_pos = y_pos + 20
            end
        end


        --T players
        render.background(x + 28, y - 1, 200, 45, clrs.T, 1)

        local x_pos = x + 33
        local y_pos = y + 3
        for k, v in pairs(players.T) do
            local esp_data = entity.get_esp_data(v)
            if esp_data.health ~= 0 then
                render.filled_rect(x_pos, y_pos, 17, 17, clrs.T)
                local avatar = get_pfp(v)
                avatar:draw(x_pos + 1, y_pos + 1, 15, 15, 255, 255, 255, 255)

                if esp_data.health < 100 then
                    renderer.rectangle(x_pos + 1, y_pos + 15, 15 * (esp_data.health/100), 1, 255, 255, 255, 250)
                end
            else
                render.filled_rect(x_pos, y_pos, 17, 17, {clrs.T[1], clrs.T[2], clrs.T[3], clrs.T[4] * .1})
                render.images.skull:draw(x_pos + 1, y_pos + 1, 15, 15, bad_clr[1], bad_clr[2], bad_clr[3], bad_clr[4] * .8)
            end

            if y_pos > y + 20 then
                y_pos = y + 3
                x_pos = x_pos + 20
            else
                y_pos = y_pos + 20
            end
        end
    end
end


render.spectate_hud = function(x, y, player)
    local clrs = {
        ["CT"] = {ui.get(opts.ct_color)},
        ["T"] = {ui.get(opts.t_color)},
    }

    local avatar = get_pfp(player, 73)
    local team = get_player_team(player)
    local clr = clrs[team]


    render.filled_rect(x - 200, y, 77, 77, {0, 0, 0, 255})
    render.filled_rect(x - 199, y + 1, 75, 75, clr)
    render.filled_rect(x - 198, y + 2, 73, 73, {0, 0, 0, 255})

    avatar:draw(x - 197, y + 3, 71, 71, 255, 255, 255, 255)
    render.background(x - 120, y + 20, 320, 77 - 20, clr, 1)

    render.draw_text( x - 110, y + 25, clr, fonts.ui_small, entity.get_player_name(player))

    local player_recources = entity.get_player_resource()
    local kills = entity.get_prop(player_recources, "m_iKills", player)
    local deaths = entity.get_prop(player_recources, "m_iDeaths", player)
    render.draw_text( x - 110, y + 40, {140, 140, 140, 230}, fonts.ui_small, "Kills: ".. tostring(kills))
    render.draw_text( x - 110, y + 55, {140, 140, 140, 230}, fonts.ui_small, "Deaths: ".. tostring(deaths))

    --render.draw_text( x - 20, y + 40, {140, 140, 140, 230}, fonts.ui_small, "Ping: 0")
end

local round_won_shit = {
    team = "T",
    msg = "big juicy ballsss",
    mvp = entity.get_local_player(),
    reason = "dick too big bruh",
    time = 0,
    show = false,
}

render.round_won = function(x, y, alpha)
    local clrs = {
        ["CT"] = {ui.get(opts.ct_color)},
        ["T"] = {ui.get(opts.t_color)},
    }

    local main_clr = clrs[round_won_shit.team == 3 and "CT" or "T"]
    main_clr[4] = main_clr[4] * alpha


    local w = 500 * alpha
    render.two_way_gradient(x - math.floor(w/2), y, w, 65, {0,0,0,230 * alpha}, .5)
    local p_w = math.floor(w * .9)

    render.two_way_gradient(x - p_w/2, y + 1, p_w, 1, main_clr, .5)
    render.two_way_gradient(x - p_w/2, y + 63, p_w, 1, main_clr, .5)

    render.centered_text( x , y + 3, main_clr, fonts.ui_big, round_won_shit.team == 2 and "Terrorists Won!" or "Counter Terrorists Won!")
    render.centered_text( x , y + 23, {200, 200, 200, 230 * alpha}, fonts.ui_small, round_won_shit.msg)

    local avatar = get_pfp(round_won_shit.mvp, 16)
    local mvp_text = tostring(entity.get_player_name(round_won_shit.mvp)).. " Got MVP"
    local t_w = surface.get_text_size(fonts.ui_small, mvp_text)
    t_w = t_w + 20
    avatar:draw(x - math.floor(t_w/2), y + 42, 16, 16, 255, 255, 255, 255 * alpha)
    render.draw_text( x - math.floor(t_w/2) + 20, y + 42, main_clr, fonts.ui_small, mvp_text)
end


local chat = {
}

render.chat = function(x, y)
    local clrs = {
        ["CT"] = {ui.get(opts.ct_color)},
        ["T"] = {ui.get(opts.t_color)},
        ["SPEC"] = {140, 140, 140, 255},
    }

    local slots = 0
    local y_pos = 20
    --render.filled_rect(x, y - 50, 50, 50, {0, 0, 0, 255})
    for k, msg in pairs(reverse_table(chat)) do
        if msg.time + 20 > globals.realtime() and slots <= 10 then
            local alpha = msg.time + 1 > globals.realtime() and clamp( (globals.realtime() - msg.time) * 4, 0, 1) or clamp( msg.time + 19 - globals.realtime(), 0, 1)

            render.gradient(x, y - (y_pos), 400, 20, {0, 0, 0, 255 * alpha}, {0, 0, 0, 0}, true)
            --render.two_way_gradient(x, y - (y_pos), 400, 20, {0, 0, 0, 255 * alpha}, .1)
            local name_text = string.format("%s%s%s:", msg.alive ~= true and "*DEAD* " or "", msg.teamonly and "(Team Chat) " or "", msg.name )--""

            local t_w, _ = surface.get_text_size(fonts.ui_small, name_text)
            local text_color = clrs[msg.team]
            render.draw_text(x + 5, y - y_pos + 2, {text_color[1], text_color[2], text_color[3], text_color[4] * alpha}, fonts.ui_small, name_text)
            render.draw_text(x + 10 + t_w, y - y_pos + 2, {230, 230, 230, 255 * alpha}, fonts.ui_small, msg.msg)
            y_pos = y_pos + (20)
            slots = slots + 1
        end 

    end
end

local vector = require"vector"

local function rotate_around(angle, center, point) -- yea this is pasted get over it
    local angle = angle - math.pi/2
    local s = math.sin(angle)
    local c = math.cos(angle)
    
    point.x = point.x-center.x
    point.y = point.y-center.y
    
    local xn, yn = point.x * c - point.y * s, point.x * s + point.y * c
    
    return xn+center.x, yn+center.y
end

local function draw_oof_arrow(angle, size, dist, r, g, b, a)
    local width, height = client.screen_size()
    local view_x, view_y = client.camera_angles()
    angle = math.rad(270 - angle + view_y)
    local point = vector(math.floor(width/2+math.cos(angle)*dist), math.floor(height/2+math.sin(angle)*dist))
    local center = point
    local point1, point2 = vector(point.x-1 * size*3, point.y-2 * size), vector(point.x+1 * size*3, point.y-2 * size)
    local point3 = vector(point.x, point.y - 1.5 * size)
    
    -- get points around triangle
    local x, y = rotate_around(angle, center, point1)
    local x1, y1 = rotate_around(angle, center, point2)
    local x2, y2 = rotate_around(angle, center, point3)
    renderer.triangle(point.x, point.y, x, y, x2, y2, r, g, b, a)
    renderer.triangle(point.x, point.y, x2, y2, x1, y1, r, g, b, a)
    --renderer.circle(point3.x, point3.y, 255, 255, 255, 255, 10, 0, 100)
    
end


local function get_angle_to(x,y,z)
    local origin = vector(client.eye_position())
    local point
    if y and z then
        point = vector(x,y,z)
    else
        point = x
    end
    local yaw, angle = origin:to(point):angles()
    
    return angle
end

local hurt_events = { }
render.hurt_indicator = function()
    local local_player = entity.get_local_player()
    
    local w, h = client.screen_size()
    local bad_clr = {ui.get(opts.bad_color)}

    for i = 1, #hurt_events do
        local hurt_event = hurt_events[i]
        if not hurt_event then break end
        local t = (hurt_event.t - globals.realtime() + 1.5)
        local e = hurt_event.e
        local p = hurt_event.p
        if t > 0 then -- until 1 sectond passes
            if e.weapon ~= "hegrenade" and e.weapon ~= "inferno" then
                for y = 1, 10 do
                    draw_oof_arrow(get_angle_to(p), y, 150, bad_clr[1], bad_clr[2], bad_clr[3], math.min(t*t*255,255)/10)
                end
            else
                for y = 1, 10 do -- depth
                    for i = 1, 4 do
                        local deg = 360/4*i+360/100*0.5
                        local a = math.min(t*t*150,150)/y/2
                        renderer.circle_outline(w/2, h/2, bad_clr[1], bad_clr[2], bad_clr[3], a, 152, deg, 0.24, 20*y/5)
                    end
                end
            end
        else
            table.remove(hurt_events, i)
        end
    end
end


 
client.set_event_callback("player_chat", function(chat_msg) 
    if ui.get(opts.alt_chat) then return end
    table.insert(chat, {
        time = globals.realtime(),
        teamonly = chat_msg.teamonly,
        team = get_player_team(chat_msg.entity),
        alive = entity.is_alive(chat_msg.entity),
        name = string_cut(chat_msg.name, 23),
        msg = chat_msg.text,
    })

end)


client.set_event_callback("player_say", function(e)
    if not ui.get(opts.alt_chat) then return end
    local ent = client.userid_to_entindex(e.userid)
    table.insert(chat, {
        alive = entity.is_alive(ent),
        msg = e.text,
        name = string_cut(entity.get_player_name(ent), 23),
        team = get_player_team(ent),
        time = globals.realtime(),
        teamonly = false,
    })
end)

client.set_event_callback("round_end", function(e)
    round_won_shit.team = e.winner
    round_won_shit.msg = surface.localize_string(e.message)
    round_won_shit.time = globals.realtime()
    round_won_shit.show = true
end)

client.set_event_callback("round_mvp", function(e)
    round_won_shit.mvp = client.userid_to_entindex(e.userid) 
    round_won_shit.reason = e.reason
end)

local kills_this_round = {}
local last_kill = {}
client.set_event_callback("player_death", function(e)
    --[[
    short   userid  user ID who died
    short   attacker    user ID who killed
    short   assister    user ID who assisted in the kill
    bool    assistedflash   assister helped with a flash
    string  weapon  weapon name killer used
    string  weapon_itemid   inventory item id of weapon killer used
    string  weapon_fauxitemid   faux item id of weapon killer used
    string  weapon_originalowner_xuid   
    bool    headshot    signals a headshot
    short   dominated   did killer dominate victim with this kill
    short   revenge     did killer get revenge on victim with this kill
    short   wipe    To do: check if indicates on a squad wipeout in Danger Zone
    short   penetrated  number of objects shot penetrated before killing target
    bool    noreplay    if replay data is unavailable, this will be present and set to false
    bool    noscope     kill happened without a scope, used for death notice icon
    bool    thrusmoke   hitscan weapon went through smoke grenade
    bool    attackerblind   attacker was blind from flashbang
    float   distance    distance to victim in meters
    ]]

    local lp = entity.get_local_player()
    local dead = client.userid_to_entindex(e.userid)
    local attacker = client.userid_to_entindex(e.attacker)
    local assister = client.userid_to_entindex(e.assister)
    local assister_name = tostring(entity.get_player_name(assister))

    if kills_this_round[attacker] == nil then
        kills_this_round[attacker] = 0
    end
    kills_this_round[attacker] = kills_this_round[attacker] + 1
    last_kill[attacker] = globals.realtime()

    if e.assister == 0 then
        assister_name = nil
    end
    
    table.insert(kills_for_feed, {
        type = lp == dead and "Local death" or lp == attacker and "Local kill" or lp == assister and "Local kill" or "Other",
        headshot = e.headshot,
        noscope = e.noscope,
        thrusmoke = e.thrusmoke,
        thruwall = e.penetrated > 0,

        assister = string_cut(assister_name, 10),
        assister_team = get_player_team(assister),
        assisted_flash = e.assistedflash,
        dead = string_cut(tostring(entity.get_player_name(dead)), 15),
        dead_team = get_player_team(dead),
        killer = string_cut(tostring(entity.get_player_name(attacker)), 15),
        killer_team = get_player_team(attacker),
        weapon = e.weapon,

        time = globals.realtime(),
    })
end)

client.set_event_callback("level_init", function()
    round_won_shit.show = false
    kills_for_feed = {}
    kills_this_round = {}
    last_kill = {}
end)

client.set_event_callback("round_start", function()
    round_won_shit.show = false
    kills_for_feed = {}
    kills_this_round = {}
    last_kill = {}
end)

local anims = {
    dmg_hp = 0,
    dmg_ap = 0,
    dmg_time = 0,
}

client.set_event_callback("player_hurt", function(e)
    local hurt = client.userid_to_entindex(e.userid)
    local attacker = client.userid_to_entindex(e.attacker)

    if hurt == entity.get_local_player() then
        anims.dmg_hp = e.dmg_health
        anims.dmg_ap = e.dmg_armor
        anims.dmg_time = globals.realtime()
    end

    if hurt == entity.get_local_player() then
        table.insert(hurt_events, {
            e = e; t = globals.realtime();
            p = vector(entity.get_origin(client.userid_to_entindex(e.attacker)));
        })
    end
end)

local name_overrides = {
    ["R8 Revolver"] = "R8",
    ["Desert Eagle"] = "Deagle",
    ["High Explosive Grenade"] = "HE Grenade",
    ["Incendiary Grenade"] = "Incen Grenade",
}

local function get_weapon_info(ent)
    local index = entity.get_prop(ent, "m_iItemDefinitionIndex")
    -- if csgo_weapons[index] == nil then return nil end
    local data =  {
        ent = ent,
        index = index,
        name = name_overrides[csgo_weapons[index].name] ~= nil and name_overrides[csgo_weapons[index].name] or csgo_weapons[index].name,
        clip = entity.get_prop(ent, "m_iClip1"),
        max_clip = csgo_weapons[index].primary_clip_size,
        reserve = entity.get_prop(ent, 'm_iPrimaryReserveAmmoCount'),
        max_reserve = csgo_weapons[index].primary_reserve_ammo_max,
        icon = images.get_weapon_icon(csgo_weapons[index]),
        data = csgo_weapons[index]
    }
    return data
end

local function get_weapons(lp)
    local results = {}
    for i=0, 64 do
        if entity.get_prop(lp, "m_hMyWeapons", i) then
            local ent = entity.get_prop(lp, "m_hMyWeapons", i)
            local data = get_weapon_info(ent)
            table.insert(results, data)
        end
    end
    return results
end

local function wep_has_value(weapons, ind, value)
    for k, v in pairs(weapons) do
        if v[ind] ~= nil then
            if v[ind] == value then
                return v
            end
        end
    end
    return nil
end

local function get_players()
    local players = {
        ["CT"] = {},
        ["T"] = {},
        ["SPEC"] = {}
    }

    local player_recources = entity.get_player_resource()
    local local_team = get_player_team(entity.get_local_player())
    for player = 1, globals.maxplayers() do
        if entity.get_prop(player_recources, 'm_bConnected', player) == 1 then -- i only have to do it like this because if theyre dormant for some reason m_iTeam doesnt update
            if get_player_team(player) == "SPEC" then
                table.insert(players["SPEC"], player)
            else
                if entity.is_enemy(player) then
                    table.insert(players[local_team == "CT" and "T" or local_team == "T" and "CT"], player)
                else
                    table.insert(players[local_team], player)
                end
            end
        end
    end

    return players
end

local previous_ammo = 0
local previous_wep = ""
local previous_money = 0
local weapon_switched_time = 0
local previous_name = ""
client.set_event_callback("paint", function()
    if not ui.get(opts.enabled) then 
        cvar.cl_draw_only_deathnotices:set_int(0) 
        cvar.cl_drawhud_force_deathnotices:set_int(0)
        return 
    end
    cvar.cl_draw_only_deathnotices:set_int(1) 
    cvar.cl_drawhud_force_deathnotices:set_int(-1)

    -- cvar.cl_draw_only_deathnotices:set_int(0) 
    -- cvar.cl_drawhud_force_deathnotices:set_int(0)

    --panorama.loadstring("$.Msg($.GetContextPanel())", "#CSGOHudFreezePanel")()

    --json.parse(tostring(pan.GameStateAPI.GetScoreDataJSO()))

    local lp = entity.get_local_player()
    if not entity.is_alive(entity.get_local_player()) then
        if entity.get_prop(entity.get_local_player(), "m_iObserverMode") ~= 6 then
            lp = entity.get_prop(entity.get_local_player(), "m_hObserverTarget")
        else
            lp = nil
        end
    end
    local players = get_players()
    -- hud here
    
    local clr = {ui.get(opts.color)}
    local s_w, s_h = client.screen_size()

    -- ROUND WON THINGY
    if round_won_shit.show then
        render.round_won(math.floor(s_w/2), 100, clamp( (globals.realtime() - round_won_shit.time) * 2, 0, 1))
    end

    -- KILL FEED
    render.kill_feed(s_w - 15, 75)

    -- TIME AND SCORE AND SUCH
    render.score_and_time(math.floor(s_w/2), ui.get(opts.hud_bottom) and s_h - 53 or 10, players)

   
    render.chat(10, s_h - 100)
    
    if entity.is_alive(entity.get_local_player()) then
        render.hurt_indicator()
    end

    if lp ~= nil and entity.is_alive(lp) then
        local name = entity.get_player_name(lp)

        local health = entity.get_prop(lp, "m_iHealth")
        local armor = entity.get_prop(lp, "m_ArmorValue")
        local weapons = get_weapons(lp)
        local money = entity.get_prop(lp, "m_iAccount")

        local helm = entity.get_prop(lp, "m_bHasHelmet")
        local defuser = entity.get_prop(lp, "m_bHasDefuser")

        --SPECTATOR HUD
        if not entity.is_alive(entity.get_local_player()) and entity.get_prop(entity.get_local_player(), "m_iObserverMode") ~= 6 then
            render.spectate_hud(math.floor(s_w/2), math.floor(s_h * .7), lp)
        end

        -- BOTTOM LEFT OF HUD
        if ui.get(opts.outlines) ~= 4 then
            render.background(10, s_h - 50, 500, 40, clr, 1, (ui.get(opts.outlines)/100 ) * .9)
        else
            render.gradient(10, s_h - 50, 500, 40, {0, 0, 0, 240}, {0, 0, 0, 0}, true)
        end

        if ui.get(opts.icons) then
            render.icon_bar(19, s_h - 50, 100, health, 100, clr, render.images.health, {value = anims.dmg_hp, time = anims.dmg_time})
            render.icon_bar(148, s_h - 50, 100, armor, 100, clr, render.images.armor_hud, {value = anims.dmg_ap, time = anims.dmg_time})
        else
            render.bar(19, s_h - 50, 100, health, 100, clr, "HP", {value = anims.dmg_hp, time = anims.dmg_time})
            render.bar(148, s_h - 50, 100, armor, 100, clr, "AP", {value = anims.dmg_ap, time = anims.dmg_time})
        end

        if ui.get(opts.stance) then
            local stance_clr = {ui.get(opts.stance_color)}

            --render.images.standing:draw(12, s_h - 110, nil, 70, stance_clr[1], stance_clr[2], stance_clr[3], stance_clr[4] )
        end

        local y_pos = 277
        -- dont rlly like how it looks so i commented it out
        -- if armor > 0 then
        --     if helm == 1 then 
        --         render.images.helm:draw(y_pos - 1, s_h - 40, nil, 20, clr[1], clr[2], clr[3], 230)
        --         y_pos = y_pos + 30
        --     else
        --         render.images.armor:draw(y_pos, s_h - 40, nil, 20, clr[1], clr[2], clr[3], 230)
        --         y_pos = y_pos + 17
        --     end
        -- end
        
        local has_bomb = wep_has_value(weapons, "name", "C4 Explosive")
        if has_bomb ~= nil then
            render.images.bomb:draw(y_pos + 1, s_h - 43, nil, 25, clr[1], clr[2], clr[3], 230)
            y_pos = y_pos + 23
        end

        if defuser == 1 then
            render.images.defuser:draw(y_pos, s_h - 40, nil, 20, clr[1], clr[2], clr[3], 230)
            y_pos = y_pos + 17
        end

        -- BOTTOM RIGHT OF HUD
        if ui.get(opts.outlines) ~= 4 then
            render.background(s_w - 510, s_h - 50, 500, 40, clr, 2, (ui.get(opts.outlines)/100 ) * .9)
        else
            render.gradient(s_w - 510, s_h - 50, 500, 40, {0, 0, 0, 0}, {0, 0, 0, 240}, true)
        end

        local wep_ent = entity.get_player_weapon(lp)

        if wep_ent ~= nil then 
            local held_wep = get_weapon_info(wep_ent)

            local icon_width = render.weapon_thingy(s_w - 20, s_h - 30, clr, held_wep)
            local y_pos = icon_width + 20
            render.weapons(s_w - 10, s_h - 55, weapons, held_wep, clr, weapon_switched_time)
            

            if held_wep.clip ~= -1 then
                render.ammo_counter(s_w - 20 - icon_width - 81, s_h - 50, 71, clr, held_wep, lp)
                y_pos = y_pos + 81
                if held_wep.name == previous_wep and previous_name == name then
                    if held_wep.clip < previous_ammo then
                        local difference = previous_ammo - held_wep.clip

                        for i = 1, difference do
                            table.insert(shells, {
                                time = globals.realtime();
                                r = math.random(10000) + i;
                                r1 = i/difference;
                            })
                        end
                    end
                end
            end
            render.shells(s_w - 20 - icon_width - 75,  s_h - 37)

            if kills_this_round[lp] ~= nil and kills_this_round[lp] ~= 0 and last_kill[lp] ~= nil then
                --print(kills_this_round[lp])
                local skull_size = {render.images.headshot:measure(nil, 25 + (10 * clamp( ((last_kill[lp] + .25) - globals.realtime()) * 4, 0, 1))) }
                render.images.headshot:draw(s_w - y_pos - 40 - (skull_size[1]/2), s_h - 30 - (skull_size[2]/2), skull_size[1], skull_size[2], clr[1], clr[2], clr[3], clr[4])
                render.draw_text(s_w - y_pos - 30, s_h - 38, clr, fonts.ui_small, tostring(kills_this_round[lp]))
            end

            if held_wep.name ~= previous_wep then
                weapon_switched_time = globals.realtime()
            end

            previous_ammo = held_wep.clip
            previous_wep = held_wep.name
        end

        -- MONEY
        render.money(10, math.floor(s_h * .35), money, clr)
        if name == previous_name then
            if previous_money < money then
                table.insert(money_notices, {render = "+ $".. tostring(money - previous_money), time = globals.realtime(), color = {150, 200, 60, 200}})
                last_money_notice = globals.realtime()
            end
            if money < previous_money then
                table.insert(money_notices, {render = " - $".. tostring(previous_money - money), time = globals.realtime(), color = {255, 50, 50, 200}})
                last_money_notice = globals.realtime()
            end
        else
            last_money_notice = globals.realtime()
        end

        previous_name = name
        previous_money = money
    end

    
end)

