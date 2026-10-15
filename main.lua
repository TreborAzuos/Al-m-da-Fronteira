require "palette"
require "sprites"

local Color = {
    left_sky = Palette.hex(0x222034),
    right_sky = Palette.hex(0x306082),
    deep = Palette.hex(0x45283c),
    mountain = Palette.hex(0x3f3f74),
    mountain_light = Palette.hex(0x5b6ee1),
    frontier = Palette.hex(0x5fcde4),
    grass = Palette.hex(0x99e550),
    grass_dark = Palette.hex(0x6abe30),
    earth = Palette.hex(0x4b692f),
    orange = Palette.hex(0xdf7126),
    yellow = Palette.hex(0xfbf236),
    white = Palette.hex(0xffffff),
    red = Palette.hex(0xac3232),
    black = Palette.hex(0x000000),
    blue = Palette.hex(0x639bff),
    forest_dark = Palette.hex(0x203c35),
    forest_light = Palette.hex(0x8fce58)
}

local phase_one_platforms = {
    { x = 0, y = 240, w = 112 },
    { x = 160, y = 240, w = 80 },
    { x = 288, y = 240, w = 80 },
    { x = 416, y = 240, w = 64 },
    { x = 32, y = 200, w = 64 },
    { x = 112, y = 176, w = 64 },
    { x = 192, y = 152, w = 64 },
    { x = 272, y = 176, w = 64 },
    { x = 352, y = 200, w = 64 }
}

local phase_two_platforms = {
    { x = 0, y = 240, w = 208 },
    { x = 248, y = 240, w = 152 },
    { x = 440, y = 240, w = 150 },
    { x = 632, y = 240, w = 160 },
    { x = 832, y = 240, w = 160 },
    { x = 1032, y = 240, w = 168 },
    { x = 92, y = 202, w = 72 },
    { x = 274, y = 184, w = 72 },
    { x = 456, y = 194, w = 80 },
    { x = 680, y = 184, w = 112 },
    { x = 874, y = 196, w = 80 },
    { x = 1000, y = 188, w = 80 }
}

local spawn_x = 12
local spawn_y = 212
local player_hitbox = { x = 9, y = 9, w = 13, h = 19 }
local slime_hitbox = { x = 5, y = 12, w = 15, h = 12 }
local player = {}
local slimes = {}
local coins = {}
local fruit = {}
local platforms = phase_one_platforms
local phase = 1
local world_width = 480
local camera_x = 0
local portal_x = 438
local portal_y = 208
local lives = 3
local score = 0
local has_fruit = false
local intro_timer = 0
local screen = "title"
local notice = ""
local notice_timer = 0
local opening_timer = 0
local transition_target = "phase2"

local function print_pixel(text, x, y, color)
    local font = Sprites.art.font
    if color == Color.yellow then
        font = Sprites.art.font_yellow
    elseif color == Color.frontier then
        font = Sprites.art.font_frontier
    end

    for index = 1, #text do
        local character = string.byte(text, index)
        if character < 32 or character > 127 then character = 63 end
        ui.tile(font, character - 32, x + (index - 1) * 8, y)
    end
end

local function print_center(text, center_x, y, color)
    print_pixel(text, center_x - #text * 4, y, color)
end

local function make_player(x, y)
    return {
        x = x,
        y = y,
        w = 32,
        h = 32,
        vx = 0,
        vy = 0,
        facing = 1,
        grounded = true,
        invulnerable = 60,
        attack_timer = 0
    }
end

local function reset_run()
    phase = 1
    platforms = phase_one_platforms
    world_width = 480
    portal_x = 438
    portal_y = 208
    camera_x = 0
    player = make_player(spawn_x, spawn_y)
    slimes = {
        { x = 310, y = 216, w = 24, h = 24, vx = 1.15, min_x = 292, max_x = 344, active = true }
    }
    coins = {
        { x = 58, y = 174, taken = false },
        { x = 216, y = 126, taken = false },
        { x = 374, y = 174, taken = false }
    }
    fruit = { x = 0, y = 0, available = false }
    lives = 3
    score = 0
    has_fruit = false
    notice = ""
    notice_timer = 0
    intro_timer = 180
    opening_timer = 0
    screen = "playing"
end

local function start_phase_two()
    phase = 2
    platforms = phase_two_platforms
    world_width = 1200
    portal_x = 1110
    portal_y = 208
    spawn_x = 12
    spawn_y = 212
    player = make_player(spawn_x, spawn_y)
    slimes = {
        { x = 328, y = 216, w = 24, h = 24, vx = 1.25, min_x = 296, max_x = 368, active = true },
        { x = 714, y = 160, w = 24, h = 24, vx = -0.9, min_x = 690, max_x = 756, active = true }
    }
    coins = {
        { x = 142, y = 174, taken = false },
        { x = 314, y = 150, taken = false },
        { x = 486, y = 158, taken = false },
        { x = 716, y = 144, taken = false },
        { x = 900, y = 154, taken = false },
        { x = 1040, y = 130, taken = false }
    }
    fruit = { x = 0, y = 0, available = false }
    has_fruit = false
    camera_x = 0
    intro_timer = 150
    notice = ""
    notice_timer = 0
    screen = "playing"
end

local function overlaps(a, b)
    return a.x < b.x + b.w and a.x + a.w > b.x
        and a.y < b.y + b.h and a.y + a.h > b.y
end

local function player_bounds()
    return {
        x = player.x + player_hitbox.x,
        y = player.y + player_hitbox.y,
        w = player_hitbox.w,
        h = player_hitbox.h
    }
end

local function slime_bounds(slime)
    return {
        x = slime.x + slime_hitbox.x,
        y = slime.y + slime_hitbox.y,
        w = slime_hitbox.w,
        h = slime_hitbox.h
    }
end

local function land_on_platforms(previous_y)
    player.grounded = false
    if player.vy < 0 then return end

    local bounds = player_bounds()
    local previous_bottom = previous_y + player_hitbox.y + player_hitbox.h
    local current_bottom = bounds.y + bounds.h

    for _, platform in ipairs(platforms) do
        local over_platform = bounds.x + bounds.w > platform.x
            and bounds.x < platform.x + platform.w
        local crossed_top = previous_bottom <= platform.y
            and current_bottom >= platform.y

        if over_platform and crossed_top then
            player.y = platform.y - player_hitbox.y - player_hitbox.h
            player.vy = 0
            player.grounded = true
            bounds.y = platform.y - player_hitbox.h
            current_bottom = platform.y
        end
    end
end

local function lose_life()
    if player.invulnerable > 0 then return end
    lives = lives - 1
    if lives <= 0 then
        screen = "lost"
        return
    end

    player.x = spawn_x
    player.y = spawn_y
    player.vx = 0
    player.vy = 0
    player.invulnerable = 90
end

local function begin_transition(target)
    screen = "transition"
    transition_target = target
    opening_timer = 90
end

local function attack_slimes(bounds)
    local attack = {
        x = player.facing > 0 and bounds.x + bounds.w - 1 or bounds.x - 25,
        y = bounds.y + 1,
        w = 26,
        h = 22
    }
    local hit_any = false

    for _, slime in ipairs(slimes) do
        if slime.active and overlaps(attack, slime_bounds(slime)) then
            slime.active = false
            score = score + 50
            hit_any = true
            if not has_fruit and not fruit.available then
                fruit.x = slime.x + 4
                fruit.y = slime.y + 4
                fruit.available = true
                notice = "SLIME SOLTOU FRUTA"
                notice_timer = 75
            end
        end
    end

    if hit_any and not fruit.available and not has_fruit then
        notice = "SLIME AFASTADO"
        notice_timer = 60
    end
end

local function update_playing(frame)
    if intro_timer > 0 then
        intro_timer = intro_timer - 1
        return
    end

    player.vx = 0
    if ui.btn(LEFT) then
        player.vx = -2.1
        player.facing = -1
    elseif ui.btn(RIGHT) then
        player.vx = 2.1
        player.facing = 1
    end

    if player.grounded and ui.btnp(BTN_Z) then
        player.vy = -5.4
        player.grounded = false
    end

    player.x = ui.mid(0, player.x + player.vx, world_width - player_hitbox.x - player_hitbox.w)
    local previous_y = player.y
    player.vy = math.min(6, player.vy + 0.26)
    player.y = player.y + player.vy
    land_on_platforms(previous_y)

    if player.invulnerable > 0 then
        player.invulnerable = player.invulnerable - 1
    end

    for _, slime in ipairs(slimes) do
        if slime.active then
            slime.x = slime.x + slime.vx
            if slime.x < slime.min_x or slime.x > slime.max_x then
                slime.vx = -slime.vx
                slime.x = ui.mid(slime.min_x, slime.x, slime.max_x)
            end
        end
    end

    local bounds = player_bounds()
    for _, coin in ipairs(coins) do
        if not coin.taken and overlaps(bounds, {
            x = coin.x + 3,
            y = coin.y + 3,
            w = 10,
            h = 10
        }) then
            coin.taken = true
            score = score + 10
        end
    end

    if fruit.available and overlaps(bounds, {
        x = fruit.x + 2,
        y = fruit.y + 2,
        w = 12,
        h = 12
    }) then
        fruit.available = false
        has_fruit = true
        notice = "FRUTA CHAVE OBTIDA"
        notice_timer = 90
    end

    if ui.btnp(BTN_X) then
        if overlaps(bounds, { x = portal_x - 1, y = portal_y - 18, w = 34, h = 50 }) then
            if has_fruit then
                begin_transition(phase == 1 and "phase2" or "won")
            elseif notice_timer <= 0 then
                notice = "FRUTA E A CHAVE"
                notice_timer = 75
            end
        else
            player.attack_timer = 12
            attack_slimes(bounds)
        end
    end

    for _, slime in ipairs(slimes) do
        if slime.active and overlaps(bounds, slime_bounds(slime)) then
            lose_life()
        end
    end

    if bounds.y > 270 then
        lose_life()
    end

    if phase == 2 then
        camera_x = ui.mid(0, player.x - 166, world_width - 480)
    else
        camera_x = 0
    end

    if player.attack_timer > 0 then
        player.attack_timer = player.attack_timer - 1
    end

    if notice_timer > 0 then
        notice_timer = notice_timer - 1
    end
end

local stars = {
    { x = 28, y = 32 }, { x = 88, y = 59 }, { x = 148, y = 27 },
    { x = 203, y = 48 }, { x = 274, y = 35 }, { x = 327, y = 61 },
    { x = 389, y = 30 }, { x = 451, y = 54 }
}

local function draw_forest_layer(sprite, start_x, y, spacing, parallax, phase_offset)
    local scroll = math.floor(camera_x * parallax)
    local first = math.floor((scroll - start_x) / spacing)
    local last = math.floor((scroll + 480 - start_x) / spacing)
    for index = first, last do
        local x = start_x + index * spacing - scroll
        ui.spr(sprite, x, y + ((index + phase_offset) % 2) * 5)
    end
end

local function draw_background(frame)
    ui.rectfill(0, 0, 479, 239, Color.left_sky)
    ui.rectfill(0, 146, 479, 239, Color.forest_dark)

    for index, star in ipairs(stars) do
        local color = (frame // (8 + index) + index) % 2 == 0 and Color.white or Color.frontier
        ui.rectfill(star.x, star.y, star.x + 2, star.y + 2, color)
    end

    ui.trisfill(0, 194, 100, 112, 198, 194, Color.mountain)
    ui.trisfill(180, 194, 290, 88, 405, 194, Color.mountain_light)
    ui.trisfill(330, 194, 415, 112, 480, 194, Color.mountain)
    draw_forest_layer(Sprites.art.forest_canopy_a, -24, 116, 88, 0.20, 0)
    draw_forest_layer(Sprites.art.forest_canopy_b, 22, 144, 72, 0.34, 1)
    draw_forest_layer(Sprites.art.forest_canopy_c, 0, 174, 64, 0.48, 0)
    ui.line(0, 218, 479, 218, Color.deep)
end

local function draw_platforms()
    for _, platform in ipairs(platforms) do
        for x = platform.x, platform.x + platform.w - 16, 16 do
            ui.spr(Sprites.art.ground, x, platform.y)
        end
        ui.rectfill(platform.x, platform.y + 14, platform.x + platform.w - 1, platform.y + 18, Color.earth)
        ui.line(platform.x, platform.y + 15, platform.x + platform.w - 1, platform.y + 15, Color.grass_dark)
    end
end

local function draw_portal(frame)
    local glow = has_fruit and Color.frontier or Color.forest_light
    local pulse = frame % 20 < 10 and Color.white or glow
    ui.spr(Sprites.art.forest_gate, portal_x, portal_y)
    ui.rect(portal_x + 2, portal_y + 2, portal_x + 29, portal_y + 30, glow)
    ui.circ(portal_x + 16, portal_y + 17, 10 + (frame % 3), pulse)
    if not has_fruit then
        ui.circfill(portal_x + 16, portal_y + 16, 3, Color.yellow)
    else
        ui.circfill(portal_x + 16, portal_y + 16, 3, pulse)
    end
end

local function draw_hud()
    ui.camera(0, 0)
    ui.rectfill(7, 7, 178, 29, Color.deep)
    print_pixel("FASE " .. tostring(phase), 14, 14, Color.frontier)
    print_pixel("PTS", 68, 14, Color.white)
    ui.spr(Sprites.art.fragment, 92, 10)
    print_pixel(string.format("%03d", score), 111, 14, Color.yellow)

    ui.rectfill(355, 7, 472, 29, Color.deep)
    print_pixel("VIDAS", 363, 14, Color.white)
    for index = 1, lives do
        ui.circfill(414 + (index - 1) * 16, 17, 5, Color.red)
    end
end

local function draw_attack(frame)
    local attack_frame = math.min(3, math.floor((12 - player.attack_timer) / 4) + 1)
    local sprite = Sprites.art["sword_" .. tostring(attack_frame)]
    local bounds = player_bounds()
    local sx = player.facing > 0 and bounds.x + bounds.w - 4 or bounds.x - 25
    ui.spr(sprite, sx, bounds.y - 2, player.facing < 0)
end

local function draw_playing(frame)
    draw_background(frame)
    ui.camera(camera_x, 0)
    draw_platforms()
    draw_portal(frame)

    for _, coin in ipairs(coins) do
        if not coin.taken then
            ui.spr(Sprites.art.fragment, coin.x, coin.y)
        end
    end

    if fruit.available then
        ui.spr(Sprites.art.fruit, math.floor(fruit.x), math.floor(fruit.y))
    end

    for _, slime in ipairs(slimes) do
        if slime.active then
            local slime_frame = math.floor(frame / 12) % 4
            ui.tile(Sprites.art.slime, slime_frame + (slime.vx < 0 and 1024 or 0), math.floor(slime.x), slime.y)
        end
    end

    if player.invulnerable == 0 or frame % 8 < 4 then
        local player_frame = math.floor(frame / 14) % 4
        ui.tile(Sprites.art.player, player_frame + (player.facing < 0 and 1024 or 0), math.floor(player.x), math.floor(player.y))
    end
    if player.attack_timer > 0 then
        draw_attack(frame)
    end

    ui.camera(0, 0)
    draw_hud()
    ui.rectfill(111, 32, 369, 47, Color.deep)
    print_pixel("DPAD MOVER  B PULAR  X ATAQUE", 126, 36, Color.white)
    if intro_timer > 0 then
        ui.rectfill(48, 68, 432, 160, Color.deep)
        ui.rect(48, 68, 432, 160, Color.frontier)
        if phase == 1 then
            print_center("VENCA OS DESAFIOS", 240, 78, Color.white)
            print_center("ATRAVESSE AS FRONTEIRAS", 240, 98, Color.yellow)
            print_center("FRUTA E A CHAVE DA FRONTEIRA", 240, 118, Color.white)
            print_center("MOEDAS VALEM PONTOS", 240, 138, Color.yellow)
        else
            print_center("FASE 2: FLORESTA DISTANTE", 240, 78, Color.white)
            print_center("SIGA PELAS PLATAFORMAS", 240, 98, Color.yellow)
            print_center("UM SLIME GUARDA O ALTO", 240, 118, Color.white)
            print_center("ACHE A FRUTA E O PORTAL", 240, 138, Color.yellow)
        end
    end
    if notice_timer > 0 then
        ui.rectfill(124, 108, 356, 132, Color.deep)
        print_center(notice, 240, 116, Color.yellow)
    end
end

local function draw_portal_opening(frame)
    local progress = (90 - opening_timer) / 90
    local radius = 8 + progress * 43
    local center_x = portal_x + 16 - camera_x
    local center_y = portal_y + 16
    local color = frame % 8 < 4 and Color.frontier or Color.yellow
    ui.circ(center_x, center_y, radius, color)
    ui.circ(center_x, center_y, radius * 0.65, Color.white)
    ui.circ(center_x, center_y, radius * 0.35, Color.frontier)
    for index = 0, 7 do
        local angle_step = (frame + index * 8) % 32
        local x = center_x + math.floor((angle_step - 16) * progress)
        local y = center_y - math.floor(24 * progress) + (index % 2) * math.floor(48 * progress)
        ui.circfill(x, y, 2, index % 2 == 0 and Color.white or Color.yellow)
    end
    ui.clip(0, 0, 480, 270)
    ui.fillp({ 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA })
    ui.rectfill(0, 0, 479, 269, Color.deep)
    ui.fillp()
    print_center(transition_target == "phase2" and "FRONTEIRA SE ABRINDO" or "ULTIMA FRONTEIRA", 240, 220, Color.white)
end

local function draw_title(frame)
    draw_background(frame)
    ui.camera(0, 0)
    draw_platforms()
    draw_portal(frame)
    ui.rectfill(66, 66, 414, 164, Color.deep)
    ui.rect(66, 66, 414, 164, Color.frontier)
    print_center("ALEM DA FRONTEIRA", 240, 83, Color.white)
    print_center("VENCA OS DESAFIOS", 240, 108, Color.yellow)
    print_center("FRUTA E CHAVE DA FRONTEIRA", 240, 126, Color.white)
    print_center("MOEDAS VALEM PONTOS", 240, 144, Color.yellow)
    print_center("X: COMECAR", 240, 181, frame % 50 < 25 and Color.white or Color.frontier)
    ui.tile(Sprites.art.player, math.floor(frame / 14) % 4, 102, 205)
    ui.spr(Sprites.art.fruit, 348, 210)
end

local function draw_ending(frame, won)
    draw_background(frame)
    ui.camera(0, 0)
    draw_platforms()
    if phase == 2 then
        ui.spr(Sprites.art.forest_gate, 420, 205)
    else
        draw_portal(frame)
    end
    ui.rectfill(88, 84, 392, 174, Color.deep)
    ui.rect(88, 84, 392, 174, won and Color.frontier or Color.red)
    if won then
        print_center("FRONTEIRA ABERTA!", 240, 105, Color.white)
        print_center("OS DOIS LADOS ESTAO LIVRES", 240, 131, Color.yellow)
    else
        print_center("A FRONTEIRA RESISTIU", 240, 105, Color.white)
        print_center("TENTE DE NOVO", 240, 131, Color.yellow)
    end
    print_center("X: JOGAR NOVAMENTE", 240, 190, frame % 50 < 25 and Color.white or Color.frontier)
end

function loop(frame)
    for index = 1, #Palette do
        ui.palset(index - 1, Palette[index])
    end

    ui.clip(0, 0, 480, 270)
    ui.camera(0, 0)
    ui.cls(Color.left_sky)

    if screen == "title" then
        if ui.btnp(BTN_X) then reset_run() end
        draw_title(frame)
    elseif screen == "playing" then
        update_playing(frame)
        draw_playing(frame)
    elseif screen == "transition" then
        opening_timer = opening_timer - 1
        if opening_timer <= 0 then
            if transition_target == "phase2" then
                start_phase_two()
            else
                screen = "won"
            end
        end
        draw_playing(frame)
        draw_portal_opening(frame)
    else
        local won = screen == "won"
        if ui.btnp(BTN_X) then reset_run() end
        draw_ending(frame, won)
    end
end
