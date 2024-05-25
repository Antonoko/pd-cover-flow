import 'CoreLibs/graphics'
import "CoreLibs/ui"
import "CoreLibs/timer"
import "CoreLibs/crank"
import "CoreLibs/sprites"
import "CoreLibs/animation"
import "CoreLibs/animator"
import "CoreLibs/easing"

local pd <const> = playdate
local gfx <const> = playdate.graphics
local screenWidth <const> = playdate.display.getWidth()
local screenHeight <const> = playdate.display.getHeight()

local cover_flip_range <const> = {
    range_in = 140,
    range_out = 260,
}

local FONT <const> = {
    SourceHanSansCN_M_16px = {
        font = gfx.font.new("font/SourceHanSansCN-M-16px")
    }
}

local cover = {}
local SFX = {
    selection = pd.sound.fileplayer.new("sound/selection"),
    selection_reverse = pd.sound.fileplayer.new("sound/selection-reverse"),
    denial = pd.sound.fileplayer.new("sound/denial"),
    key = pd.sound.fileplayer.new("sound/key"),
    slide_in = pd.sound.fileplayer.new("sound/slide_in"),
    slide_out = pd.sound.fileplayer.new("sound/slide_out"),
    click = pd.sound.fileplayer.new("sound/click"),
    crumple_paper_01 = pd.sound.fileplayer.new("sound/crumple_paper_01"),
}
local SFX_paper = {
    pd.sound.fileplayer.new("sound/paper1"),
    pd.sound.fileplayer.new("sound/paper2"),
    pd.sound.fileplayer.new("sound/paper3"),
    pd.sound.fileplayer.new("sound/paper4"),
    pd.sound.fileplayer.new("sound/paper5"),
    pd.sound.fileplayer.new("sound/paper6"),
    pd.sound.fileplayer.new("sound/paper7"),
    pd.sound.fileplayer.new("sound/paper8"),
    pd.sound.fileplayer.new("sound/paper9"),
    pd.sound.fileplayer.new("sound/paper10"),
    pd.sound.fileplayer.new("sound/paper11"),
    pd.sound.fileplayer.new("sound/paper12"),
    pd.sound.fileplayer.new("sound/paper13"),
    pd.sound.fileplayer.new("sound/paper14"),
}
local STAGE = {}
local stage_manager = "cover_flow_scroll"
local arrow_btn_skip_cnt_sensitivity = 100

local cover_flow_offset_y = -10
local cover_flow_offset_x = 0
local cover_padding = screenWidth/10
local cover_select_index = 1
local cover_select_index_lazy = 1
local cover_flip_animation_duration <const> = 200

local cover_center_animator = gfx.animator.new(1500, -(#cover * cover_padding), screenWidth/2, playdate.easingFunctions.outCubic)
-- local cover_center_delaytimer = 

local cover_name_sprite = gfx.sprite.new()
local statebar_sprite = gfx.sprite.new(gfx.image.new("img/statebar"))
local battery_lazy = 0
local arrow_btn_skip_cnt_sensitivity = 100
local song_select_index = 1

local flip_songlist_animator = gfx.animator.new(0, 0, 90, playdate.easingFunctions.outCubic)
local is_flip_songlist_animator_to_gridview_control = false

-----------------

function mapValue(old_value, old_min, old_max, new_min, new_max)
    return ((old_value - old_min) * (new_max - new_min) / (old_max - old_min) + new_min)
end

function map_inoutcubic(input, old_min, old_max, new_min, new_max)
    -- Cube function
    function cube(n)
        return n * n * n
    end

    -- Triple function
    function triple(n)
        return 3 * n * n
    end

    -- Cubic bezier function
    function calc_bezier(p0, p1, p2, p3, t)
        local it = 1.0 - t
        return cube(it) * p0 + 3 * triple(it) * t * p1 + 3 * t * t * it * p2 + cube(t) * p3
    end

    -- Main cubic bezier function
    function cubic_bezier(x)
        -- Define your cubic-bezier parameters here
        local p0 = 0
        local p1 = .14
        local p2 = .7
        local p3 = 1

        -- Clamp x value between 0 and 1
        x = math.min(math.max(x, 0), 1)

        return calc_bezier(p0, p1, p2, p3, x)
    end

    local temp_map = mapValue(input, old_min, old_max, 0, 1)
    local res = mapValue(cubic_bezier(temp_map), 0, 1, new_min, new_max)
    -- print("input", input, "temp_map", temp_map, "res", res)
    return res
end

function load_json()
    local json_data = json.decodeFile("cover_list.json")
    for k, v in pairs(json_data["cover_list"]) do
        print("loading",k)
        local insert_data = {
            image = gfx.image.new("img/cover/"..v.image),
            sprite = playdate.graphics.sprite.new(),
            name = v.name.."\n"..v.artist,
            lazy_x = 0,
            out_of_bound = false,
            song = v.song
        }
        assert(insert_data.image)
        table.insert(cover, insert_data)
    end
end


function x_map_func_three_stage(x, point_start, point1, point2, point_end)
    --x_map_func_three_stage(10, {x=0,y=0}, {x=100,y=50}, {x=300,y=350}, {x=400,y=400})
    -- print("p0", point_start.x..","..point_start.y, "p1", point1.x..","..point1.y, "p2", point2.x..","..point2.y, "p4",point_end.x..","..point_end.y)

    function _f_1(x)
        return ((point1.y-point_start.y)/(point1.x-point_start.x))*(x-point_start.x) + point_start.y
    end

    function _f_2(x)
        return ((point2.y-point1.y)/(point2.x-point1.x))*(x-point1.x) + point1.y
    end
 
    function _f_3(x)
        return ((point_end.y-point2.y)/(point_end.x-point2.x))*(x-point2.x) + point2.y
    end

    if x <= point1.x then
        return _f_1(x)
    elseif x > point1.x and x <= point2.x then
        return _f_2(x)
    elseif x > point2.x then
        return _f_3(x)
    end
end

function cover_flow_x_map_func(x)
    return x_map_func_three_stage(x, {x=0,y=0}, {x=100,y=50}, {x=300,y=350}, {x=400,y=400})
end

function cover_flip_angle_map_func(x, x_start, x_end, angle_start, angle_end)
    return x_map_func_three_stage(x,
                                {x=x_start,y=angle_start},
                                {
                                    x=x_start+(x_end-x_start)*(2/6),
                                    y=angle_start+(angle_end-angle_start)*(1.6/4)
                                },
                                {
                                    x=x_start+(x_end-x_start)*(4/6),
                                    y=angle_start+(angle_end-angle_start)*(2.4/4)
                                },
                                {x=x_end,y=angle_end})
end

-----------------

function cover_render(anchor, tilt_angle, cover_image, draw_x, draw_y)
	-- cover_render("left", 45, gfx.image.new("cover"), 0, 0)
	-- anchor: left, right
	-- cover_image: gfx.image
	local cover_width, cover_height = cover_image:getSize()
	local image_scale = 1
	local x = cover_width/2
	local y = 0
	local perspective_z = 200
	local center_x = 0.5
	local center_y = 0
	local angle = 0 * (math.pi/180) -- z rotation

	if anchor == "left" then
		y = cover_height
		center_y = 1
    elseif anchor == "right" then
        y = 0
        center_y = 0
    elseif anchor == "center" then
        y = cover_height/2
        center_y = .5
	end
	
	if angle < 0 then angle += 2 * math.pi end
	if angle > 2 * math.pi then angle -= 2 * math.pi end

	local c = math.cos(angle)
	local s = math.sin(angle)
	
	local imgae_cache = gfx.image.new(cover_width, cover_height, gfx.kColorClear)
	gfx.pushContext(imgae_cache)
		cover_image:drawSampled(0, 0, cover_width, cover_height,  -- x, y, width, height
								center_x, center_y, -- center x, y
								c / image_scale, s / image_scale, -- dxx, dyx
								-s / image_scale, c / image_scale, -- dxy, dyy
								x/cover_width, y/cover_height, -- dx, dy
								perspective_z, -- z
								tilt_angle, -- tilt angle
								false); -- tile
	gfx.popContext()
	imgae_cache:drawRotated(cover_width/2+draw_x, cover_height/2+draw_y, 90)

end


function cover_update_angle_render(x, sprite, image)
    if x < cover_flip_range.range_in or x > cover_flip_range.range_out then
        return
    end
    -- local target_angle = mapValue(x, 140, 260, 65, -65)
    local target_angle = cover_flip_angle_map_func(x, cover_flip_range.range_in, cover_flip_range.range_out, 65, -65)
    local cover_width, cover_height = image:getSize()
    local target_image = gfx.image.new(cover_width, cover_height, gfx.kColorClear)
    local direction
    if target_angle > 0 then
        direction = "left"
    else
        direction = "right"
    end
    add_stroke_on_image(image)
	gfx.pushContext(target_image)
        cover_render(direction, target_angle, image, 0, 0)
	gfx.popContext()
    sprite:setImage(target_image)
end


function add_stroke_on_image(image)
    local width, height = image:getSize()
    gfx.pushContext(image)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(0,0,width,height)
    gfx.popContext()
end


function cover_init()
    local add_x = 0
    for k,v in pairs(cover) do
        v.sprite:setImage(v.img)
        v.sprite:setCenter(.5, .5)
        v.sprite:moveTo(cover_flow_x_map_func(add_x+cover_flow_offset_x), screenHeight/2 +cover_flow_offset_y)
        v.sprite:add()
        add_x += cover_padding
    end
end

function cover_update()
    local add_x = 0
    local remove_margin = 50
    for k,v in pairs(cover) do
        local target_x = cover_flow_x_map_func(add_x+cover_flow_offset_x)
        if v.lazy_x ~= target_x then
            -- out of screen bound: remove sprite
            if target_x > screenWidth + remove_margin or target_x < -remove_margin then
                v.sprite:remove()
                goto skip_to_next
            else
                v.sprite:add()
            end

            -- out of flip bound: set to fliped state
            if target_x < cover_flip_range.range_in then
                if v.out_of_bound == false then
                    cover_update_angle_render(cover_flip_range.range_in, v.sprite, v.image)
                    v.out_of_bound = true
                end
            elseif target_x > cover_flip_range.range_out then
                if v.out_of_bound == false then
                    cover_update_angle_render(cover_flip_range.range_out, v.sprite, v.image)
                    v.out_of_bound = true
                end
            else
                v.out_of_bound = false
            end

            cover_update_angle_render(target_x, v.sprite, v.image)
            v.sprite:moveTo(target_x, screenHeight/2+cover_flow_offset_y)
            if k == cover_select_index then
                v.sprite:setZIndex(100)
            else
                v.sprite:setZIndex(k)
            end

            cover[k].lazy_x = target_x
        end

        ::skip_to_next::
        add_x += cover_padding
    end
end


local cover_back_to_center_init = false
function cover_back_to_center()
    if cover_back_to_center_init then
        local target_x = -((get_cover_index()-1) * cover_padding) + screenWidth/2
        if cover_flow_offset_x ~= target_x then
            cover_center_animator = gfx.animator.new(150, cover_flow_offset_x, target_x, playdate.easingFunctions.outCubic)
        end
        -- print("get_cover_index", get_cover_index(), "cover_flow_offset_x", cover_flow_offset_x, "target_x", target_x )
        cover_back_to_center_init = false
    else
        if not cover_center_animator:ended() then
            cover_flow_offset_x = cover_center_animator:currentValue()
            cover_update()
        end
    end
end


function get_cover_index()
    local res = -(cover_flow_offset_x - (screenWidth/2))/cover_padding
    if res - math.floor( res ) > .5 then
        res = math.ceil( res ) +1
    else
        res = math.floor( res ) +1
    end
    if res < 1 then
        res = 1
    elseif res > #cover then
        res = #cover
    end
    return res
end


function update_cover_name(cover_name)
    local image = gfx.image.new(screenWidth, 40)
	gfx.pushContext(image)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.setFont(FONT["SourceHanSansCN_M_16px"].font)
        gfx.drawTextAligned(cover_name, screenWidth/2, 0, kTextAlignment.center)
	gfx.popContext()
    cover_name_sprite:setImage(image)
end


function update_battery()
    if pd.getBatteryPercentage() ~= battery_lazy then
        local image = gfx.image.new("img/statebar")
        gfx.pushContext(image)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(370+math.floor(20*(pd.getBatteryPercentage()/100)), 3, 20-math.floor(20*(pd.getBatteryPercentage()/100)), 8)
        gfx.popContext()
        statebar_sprite:setImage(image)
        battery_lazy = pd.getBatteryPercentage()
    end
end


function crank_move_update_routine()
    -- update when crank moved
    -- update cover name
    cover_select_index = get_cover_index()
    if cover_select_index ~= cover_select_index_lazy then
        if cover_select_index > cover_select_index_lazy then
            SFX.selection:play()
        else
            SFX.selection_reverse:play()
        end
        if cover_select_index > 0 and cover_select_index <= #cover then
            -- SFX_paper[math.random(#SFX_paper)]:play()
            update_cover_name(cover[cover_select_index].name)
        else
            update_cover_name("")
        end
        cover_select_index_lazy = cover_select_index
    end
    update_battery()
end


local draw_song_list_init = false
local draw_song_list_size, draw_song_list_gridview
local draw_song_list_gridviewSprite = gfx.sprite.new()
local draw_song_list_gridviewImage = gfx.image.new(1,1)
function draw_song_list()
    if draw_song_list_init then

        gfx.setFont(FONT["SourceHanSansCN_M_16px"].font)
        draw_song_list_size = gfx.getTextSize("我")
        draw_song_list_gridview = pd.ui.gridview.new(0, draw_song_list_size*1.5+6)
        draw_song_list_gridview:setNumberOfRows(#cover[cover_select_index].song)
        draw_song_list_gridview:setCellPadding(0,0,0,0)

        draw_song_list_gridviewSprite = gfx.sprite.new()
        draw_song_list_gridviewSprite:setCenter(0.5,1)
        draw_song_list_gridviewSprite:setZIndex(300)
        draw_song_list_gridviewSprite:moveTo(screenWidth/2, screenHeight)
        draw_song_list_gridviewSprite:add()

        draw_song_list_init = false
    end

    function draw_song_list_gridview:drawCell(section, row, column, selected, x, y, width, height)
        gfx.setFont(FONT["SourceHanSansCN_M_16px"].font)
        if selected then
            --FIXME indicator
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x, y, width, height)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            gfx.drawTextAligned(cover[cover_select_index].song[row], x+6, y+7, kTextAlignment.left)

            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(width-24, y, 24, height)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            gfx.image.new("img/arrow_right"):draw(width-22, y+5)
        else
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            gfx.drawTextAligned(cover[cover_select_index].song[row], x+6, y+7, kTextAlignment.left)
        end
    end

    function _scroll_select_file_gridview(direction)
        if direction == "next" then
            SFX.selection:play()
            draw_song_list_gridview:selectNextRow(true)
        elseif direction == "previous" then
            SFX.selection_reverse:play()
            draw_song_list_gridview:selectPreviousRow(true)
        end
        -- SFX.selection.sound:play()
    end

    local crankTicks = pd.getCrankTicks(10)
    if crankTicks == 1 then
        _scroll_select_file_gridview("next")
    elseif crankTicks == -1 then
        _scroll_select_file_gridview("previous")
    end

    if pd.buttonIsPressed(pd.kButtonDown) then
        arrow_btn_skip_cnt_sensitivity += 1
        if arrow_btn_skip_cnt_sensitivity > 4 then
            arrow_btn_skip_cnt_sensitivity = 0
            _scroll_select_file_gridview("next")
        end
    elseif pd.buttonIsPressed(pd.kButtonUp) then
        arrow_btn_skip_cnt_sensitivity += 1
        if arrow_btn_skip_cnt_sensitivity > 4 then
            arrow_btn_skip_cnt_sensitivity = 0
            _scroll_select_file_gridview("previous")
        end
    end
    if pd.buttonJustReleased(pd.kButtonDown) or pd.buttonJustReleased(pd.kButtonUp) then
        arrow_btn_skip_cnt_sensitivity = 100
    end

    _, song_select_index, _ = draw_song_list_gridview:getSelection()
    
    ----------------------draw
    if draw_song_list_gridview.needsDisplay then
        local pos = {
            x=screenWidth*(3/5),
            y=215,
        }
        draw_song_list_gridviewImage = gfx.image.new(pos.x,pos.y,gfx.kColorWhite)
        gfx.pushContext(draw_song_list_gridviewImage)
            gfx.setPattern(gfx.image.new("img/densechecker-tense"))
            gfx.fillRect(0,0,pos.x,46)

            gfx.setColor(gfx.kColorBlack)
            gfx.drawRect(0,0,pos.x,pos.y+2)

            gfx.setFont(FONT["SourceHanSansCN_M_16px"].font)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            gfx.drawTextAligned(cover[cover_select_index].name, 7, 7, kTextAlignment.left)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            gfx.drawTextAligned(cover[cover_select_index].name, 6, 6, kTextAlignment.left)

            draw_song_list_gridview:drawInRect(0, 46, pos.x, pos.y-46)
        gfx.popContext()
        
        if is_flip_songlist_animator_to_gridview_control then
            draw_song_list_gridviewSprite:setImage(draw_song_list_gridviewImage)
        end
    end

end


local flip_cover_to_none_init = false
local flip_cover_to_none_animator = gfx.animator.new(0, 0, 90, playdate.easingFunctions.outCubic)
function flip_cover_to_none(playback)
    if flip_cover_to_none_init then
        if playback then
            flip_cover_to_none_animator = gfx.animator.new(cover_flip_animation_duration, 90, 0, playdate.easingFunctions.inOutCubic, cover_flip_animation_duration)
        else
            flip_cover_to_none_animator = gfx.animator.new(cover_flip_animation_duration, 0, 90, playdate.easingFunctions.inOutCubic)
        end
        flip_cover_to_none_init = false
    else
        if not flip_cover_to_none_animator:ended() then
            local cover_image = cover[cover_select_index].image
            local cover_width, cover_height = cover_image:getSize()
            local imgae_cache = gfx.image.new(cover_width, cover_height, gfx.kColorClear)
            gfx.pushContext(imgae_cache)
                if flip_cover_to_none_animator:currentValue() < 90 then
                    cover_render("center", flip_cover_to_none_animator:currentValue(), cover_image, 0, 0)
                end
            gfx.popContext()
            cover[cover_select_index].sprite:setImage(imgae_cache)
        end
    end
end


local flip_songlist_init = false
function flip_songlist(playback)
    if flip_songlist_init then
        if playback then
            flip_songlist_animator = gfx.animator.new(cover_flip_animation_duration, 0, -90, playdate.easingFunctions.inOutCubic)      
        else
            flip_songlist_animator = gfx.animator.new(cover_flip_animation_duration, -90, 0, playdate.easingFunctions.inOutCubic, cover_flip_animation_duration)
        end
        flip_songlist_init = false
    else
        if not flip_songlist_animator:ended() then
            is_flip_songlist_animator_to_gridview_control = false
            local gridimg_width, gridimg_height = draw_song_list_gridviewImage:getSize()
            local gridviewImage_rotate = gfx.image.new((gridimg_height+100), gridimg_width, gfx.kColorClear)  --render buffer for rotation
            gfx.pushContext(gridviewImage_rotate)
                draw_song_list_gridviewImage:drawRotated((gridimg_height+100)/2, gridimg_width/2, -90)
            gfx.popContext()

            local gridviewImage_transform = gfx.image.new(gridimg_width, (gridimg_height+100), gfx.kColorClear)
            gfx.pushContext(gridviewImage_transform)
                -- gfx.setColor(gfx.kColorBlack)
                -- gfx.fillRect(0,0,1000,1000)
                if flip_songlist_animator:currentValue() > -90 then
                    cover_render("center", flip_songlist_animator:currentValue(), gridviewImage_rotate, -37, 89)  --magic num offset :(
                end
            gfx.popContext()
            draw_song_list_gridviewSprite:setImage(gridviewImage_transform)
        else
            is_flip_songlist_animator_to_gridview_control = true
        end
    end
end

local flip_songlist_to_none_init = false
function flip_songlist_to_none()
    if flip_songlist_to_none_init then
        flip_songlist_init = true
        flip_songlist_to_none_init = false
    else
        flip_songlist(true)
    end
end


local dpad_accelerate = .5
local dpad_spec = {
    min = 15,
    max = 30
}
local dpad_speed = dpad_spec.min
function dpad_control_cover_flow()
    -- if dpad_speed>dpad_spec.max then
    --     dpad_speed = dpad_spec.max
    -- end
    -- if pd.buttonIsPressed(pd.kButtonRight) then
    --     if cover_flow_offset_x < screenWidth then
    --         dpad_speed += dpad_accelerate
    --         return -dpad_speed
    --     end
    -- elseif pd.buttonIsPressed(pd.kButtonLeft) then
    --     if cover_flow_offset_x > -(#cover * cover_padding) then
    --         dpad_speed += dpad_accelerate
    --         return dpad_speed
    --     end
    -- end
    -- if pd.buttonJustReleased(pd.kButtonRight) or pd.buttonJustReleased(pd.kButtonLeft) then
    --     dpad_speed = dpad_spec.min
    -- end

    local res = 0
    if pd.buttonIsPressed(pd.kButtonRight) then
        arrow_btn_skip_cnt_sensitivity += 1
        if arrow_btn_skip_cnt_sensitivity > 6 then
            arrow_btn_skip_cnt_sensitivity = 0
            res = -cover_padding * (10/5)
        end
    elseif pd.buttonIsPressed(pd.kButtonLeft) then
        arrow_btn_skip_cnt_sensitivity += 1
        if arrow_btn_skip_cnt_sensitivity > 6 then
            arrow_btn_skip_cnt_sensitivity = 0
            res = cover_padding * (10/5)
        end
    end
    if pd.buttonJustReleased(pd.kButtonRight) or pd.buttonJustReleased(pd.kButtonLeft) then
        arrow_btn_skip_cnt_sensitivity = 100
    end

    return res
end


-----------------
STAGE["cover_flow_scroll"] = function()
    local change, acceleratedChange = playdate.getCrankChange()
    if math.abs(change) < 2 then
        change = -dpad_control_cover_flow()
    end
    if math.abs(change) > 2 then
        cover_flow_offset_x += -change/3
        cover_update()
        crank_move_update_routine()
        cover_back_to_center_init = true
    else
        playdate.timer.new(5, function(value)
            cover_back_to_center()
        end
        )
    end
    
    flip_songlist_to_none()
    flip_cover_to_none(true)

    if pd.buttonJustPressed(pd.kButtonA) then
        stage_manager = "cover_selected"
        is_flip_songlist_animator_to_gridview_control = false
        flip_cover_to_none_init = true
        flip_songlist_init = true
        draw_song_list_init = true
        SFX.click:play()
        SFX_paper[math.random(#SFX_paper)]:play()
    end

end

STAGE["cover_selected"] = function()
    flip_cover_to_none(false)
    
    draw_song_list()
    flip_songlist(false)

    if pd.buttonJustPressed(pd.kButtonB) then
        stage_manager = "cover_flow_scroll"
        is_flip_songlist_animator_to_gridview_control = false
        flip_cover_to_none_init = true
        flip_songlist_to_none_init = true
        SFX.slide_out:play()
    end

end

-----------------

test_x = 0
function init()
    playdate.display.setRefreshRate(30)

    gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0,0,screenWidth,screenHeight)

    load_json()
    cover_center_animator = gfx.animator.new(1500, -(#cover * cover_padding), screenWidth/2, playdate.easingFunctions.outCubic)

    statebar_sprite:setCenter(0,0)
    statebar_sprite:moveTo(0,0)
    statebar_sprite:add()
    update_battery()

    cover_name_sprite:moveTo(screenWidth/2, screenHeight-20)
    cover_name_sprite:setZIndex(200)
    cover_name_sprite:add()

    cover_init()
    SFX.crumple_paper_01:play()
end


function pd.update()
    gfx.sprite.update()
    pd.timer.updateTimers()
    
    STAGE[stage_manager]()

    playdate.timer.performAfterDelay(800, function(value)
        update_cover_name(cover[cover_select_index].name)
    end
    )

    -- print(cover_flow_offset_x)

end

init()
