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
    blue = Palette.hex(0x639bff)
}

local platforms = {
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

local spawn_x = 12
local spawn_y = 212
local player_hitbox = { x = 9, y = 9, w = 13, h = 19 }
local slime_hitbox = { x = 5, y = 12, w = 15, h = 12 }
local portal_hitbox = { x = 438, y = 190, w = 30, h = 50 }
local player = {}
local slime = {}
local fragments = {}
local lives = 3
local collected = 0
local screen = "title"
local notice = ""
local notice_timer = 0

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

local function reset_run()
    player = {
        x = spawn_x,
        y = spawn_y,
        w = 32,
        h = 32,
        vx = 0,
        vy = 0,
        facing = 1,
        grounded = true,
        invulnerable = 60,
        attack_timer = 0
    }
    slime = { x = 310, y = 216, w = 24, h = 24, vx = 1.15, active = true }
    fragments = {
        { x = 58, y = 174, taken = false },
        { x = 216, y = 126, taken = false },
        { x = 374, y = 174, taken = false }
    }
    lives = 3
    collected = 0
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

local function slime_bounds()
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

local function update_playing(frame)
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

    player.x = ui.mid(0, player.x + player.vx, 480 - player_hitbox.x - player_hitbox.w)
    local previous_y = player.y
    player.vy = math.min(6, player.vy + 0.26)
    player.y = player.y + player.vy
    land_on_platforms(previous_y)

    if player.invulnerable > 0 then
        player.invulnerable = player.invulnerable - 1
    end

    if slime.active then
        slime.x = slime.x + slime.vx
        if slime.x < 292 or slime.x > 344 then
            slime.vx = -slime.vx
        end
    end

    local bounds = player_bounds()
    for _, fragment in ipairs(fragments) do
        if not fragment.taken and overlaps(bounds, {
            x = fragment.x + 3,
            y = fragment.y + 3,
            w = 10,
            h = 10
        }) then
            fragment.taken = true
            collected = collected + 1
        end
    end

    if ui.btnp(BTN_X) then
        if overlaps(bounds, portal_hitbox) then
            if collected == #fragments then
                screen = "won"
            elseif notice_timer <= 0 then
                notice = "AINDA FALTAM FRAGMENTOS"
                notice_timer = 75
            end
        else
            player.attack_timer = 9
            local attack = {
                x = player.facing > 0 and bounds.x + bounds.w or bounds.x - 22,
                y = bounds.y + 2,
                w = 22,
                h = 14
            }
            if slime.active and overlaps(attack, slime_bounds()) then
                slime.active = false
                notice = "SLIME AFASTADO"
                notice_timer = 60
            end
        end
    end

    if slime.active and overlaps(bounds, slime_bounds()) then
        lose_life()
    end

    if bounds.y > 270 then
        lose_life()
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

local function draw_background(frame)
    ui.rectfill(0, 0, 239, 239, Color.left_sky)
    ui.rectfill(240, 0, 479, 239, Color.right_sky)

    for index, star in ipairs(stars) do
        local color = (frame // (8 + index) + index) % 2 == 0 and Color.white or Color.frontier
        ui.rectfill(star.x, star.y, star.x + 2, star.y + 2, color)
    end

    ui.trisfill(0, 184, 95, 95, 190, 184, Color.mountain)
    ui.trisfill(180, 184, 285, 84, 390, 184, Color.mountain_light)
    ui.trisfill(325, 184, 415, 112, 480, 184, Color.mountain)
    ui.line(0, 218, 479, 218, Color.deep)

    ui.rectfill(237, 36, 243, 239, Color.deep)
    ui.rectfill(239, 36, 241, 239, Color.frontier)
    for y = 54, 222, 24 do
        ui.circfill(240, y, 3, Color.white)
    end

    print_pixel("LADO A", 16, 18, Color.white)
    print_pixel("LADO B", 416, 18, Color.white)
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
    local open = collected == #fragments
    local glow = open and Color.frontier or Color.red
    local pulse = frame % 20 < 10 and Color.white or glow
    ui.rectfill(438, 190, 467, 239, Color.deep)
    ui.rect(438, 190, 467, 239, glow)
    ui.rectfill(445, 197, 460, 239, open and Color.blue or Color.black)
    ui.line(445, 197, 460, 197, pulse)
    ui.circfill(452, 199, 5, pulse)
    if not open then
        ui.rectfill(449, 216, 456, 230, Color.orange)
        ui.rectfill(451, 212, 454, 217, Color.yellow)
    end
end

local function draw_hud()
    ui.rectfill(7, 7, 163, 29, Color.deep)
    print_pixel("FRAGMENTOS", 14, 14, Color.white)
    for index = 1, #fragments do
        ui.spr(Sprites.art.fragment, 102 + (index - 1) * 17, 10)
        if fragments[index].taken then
            ui.line(102 + (index - 1) * 17, 10, 116 + (index - 1) * 17, 24, Color.grass)
        end
    end

    ui.rectfill(355, 7, 472, 29, Color.deep)
    print_pixel("VIDAS", 363, 14, Color.white)
    for index = 1, lives do
        ui.circfill(414 + (index - 1) * 16, 17, 5, Color.red)
    end
end

local function draw_playing(frame)
    draw_background(frame)
    draw_platforms()
    draw_portal(frame)

    for _, fragment in ipairs(fragments) do
        if not fragment.taken then
            ui.spr(Sprites.art.fragment, fragment.x, fragment.y)
        end
    end

    if slime.active then
        local slime_frame = math.floor(frame / 12) % 4
        ui.tile(Sprites.art.slime, slime_frame + (slime.vx < 0 and 1024 or 0), math.floor(slime.x), slime.y)
    end
    if player.invulnerable == 0 or frame % 8 < 4 then
        local player_frame = math.floor(frame / 14) % 4
        ui.tile(Sprites.art.player, player_frame + (player.facing < 0 and 1024 or 0), math.floor(player.x), math.floor(player.y))
    end
    if player.attack_timer > 0 then
        local bounds = player_bounds()
        local slash_x = player.facing > 0 and bounds.x + bounds.w + 2 or bounds.x - 18
        ui.line(slash_x, bounds.y + 3, slash_x + 16, bounds.y + 12, Color.yellow)
        ui.line(slash_x + 4, bounds.y + 1, slash_x + 12, bounds.y + 15, Color.white)
    end

    draw_hud()
    ui.rectfill(112, 32, 368, 47, Color.deep)
    print_pixel("DPAD MOVER  B PULAR  X ACAO", 128, 36, Color.white)
    if notice_timer > 0 then
        ui.rectfill(124, 108, 356, 132, Color.deep)
        print_center(notice, 240, 116, Color.yellow)
    end
end

local function draw_title(frame)
    draw_background(frame)
    draw_platforms()
    draw_portal(frame)
    ui.rectfill(66, 66, 414, 157, Color.deep)
    ui.rect(66, 66, 414, 157, Color.frontier)
    print_center("ALEM DA FRONTEIRA", 240, 83, Color.white)
    print_center("REUNA OS 3 FRAGMENTOS", 240, 108, Color.yellow)
    print_center("E ABRA O PORTAL", 240, 126, Color.white)
    print_center("X: COMECAR", 240, 181, frame % 50 < 25 and Color.white or Color.frontier)
    ui.tile(Sprites.art.player, math.floor(frame / 14) % 4, 102, 205)
    ui.spr(Sprites.art.fragment, 348, 210)
end

local function draw_ending(frame, won)
    draw_background(frame)
    draw_platforms()
    draw_portal(frame)
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
    else
        local won = screen == "won"
        if ui.btnp(BTN_X) then reset_run() end
        draw_ending(frame, won)
    end
end
