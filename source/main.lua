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

local cover = {
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new(),
        name = "MyGO!!!!!\n迷迹波",
        lazy_x = 0,
        out_of_bound = false,
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new(),
        name = "迷迹asdasd波 - MyGO!!!!!",
        lazy_x = 0,
        out_of_bound = false,
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new(),
        name = "迷123迹波 - MyGO!!!!!",
        lazy_x = 0,
        out_of_bound = false,
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new(),
        name = "迷迹555波 - MyGO!!!!!",
        lazy_x = 0,
        out_of_bound = false,
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new(),
        name = "迷agsadgasg!!!",
        lazy_x = 0,
        out_of_bound = false,
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new(),
        name = "迷aaaaaO!!!!!",
        lazy_x = 0,
        out_of_bound = false,
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new(),
        name = "迷ggggGO!!!!!",
        lazy_x = 0,
        out_of_bound = false,
    },
}
local STAGE = {}
local stage_manager = "cover_flow_scroll"
local cover_flow_offset_y = -12
local cover_flow_offset_x = 0
local cover_padding = screenWidth/12
local cover_select_index = 1
local cover_select_index_lazy = 1

local cover_center_animator = gfx.animator.new(1000, -(#cover * cover_padding), screenWidth/2, playdate.easingFunctions.inOutCubic)
-- local cover_center_delaytimer = 

local cover_name_sprite = gfx.sprite.new()
local statebar_sprite = gfx.sprite.new(gfx.image.new("img/statebar"))
local battery_lazy = 0

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
	gfx.pushContext(target_image)
        cover_render(direction, target_angle, image, 0, 0)
	gfx.popContext()
    sprite:setImage(target_image)
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
    -- FIXME 当专辑sprite超出屏幕时移除
    for k,v in pairs(cover) do
        local target_x = cover_flow_x_map_func(add_x+cover_flow_offset_x)
        if v.lazy_x ~= target_x then
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
            cover_center_animator = gfx.animator.new(150, cover_flow_offset_x, target_x, playdate.easingFunctions.inOutCubic)
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
        if cover_select_index > 0 and cover_select_index <= #cover then
            update_cover_name(cover[cover_select_index].name)
        else
            update_cover_name("")
        end
        cover_select_index_lazy = cover_select_index
    end
    update_battery()
end


local flip_cover_to_none_init = false
local flip_cover_to_none_animator = gfx.animator.new(0, 0, 90, playdate.easingFunctions.outCubic)
function flip_cover_to_none()
    if flip_cover_to_none_init then
        flip_cover_to_none_animator = gfx.animator.new(200, 0, 90, playdate.easingFunctions.outCubic)
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

-----------------
STAGE["cover_flow_scroll"] = function()
    local change, acceleratedChange = playdate.getCrankChange()
    if math.abs(change) > 2 then
        cover_flow_offset_x += change
        cover_update()
        crank_move_update_routine()
        cover_back_to_center_init = true
    else
        playdate.timer.new(10, function(value)
            cover_back_to_center()
        end
        )
    end
    
    if pd.buttonJustPressed(pd.kButtonA) then
        flip_cover_to_none_init = true
    end

    flip_cover_to_none()
end

STAGE["cover_selected"] = function()

end

-----------------

test_x = 0
function init()
    playdate.display.setRefreshRate(30)

    gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0,0,screenWidth,screenHeight)

    statebar_sprite:setCenter(0,0)
    statebar_sprite:moveTo(0,0)
    statebar_sprite:add()
    update_battery()

    cover_name_sprite:moveTo(screenWidth/2, screenHeight-20)
    cover_name_sprite:setZIndex(200)
    cover_name_sprite:add()
    update_cover_name(cover[cover_select_index].name)

    cover_init()
    
end


function pd.update()
    gfx.sprite.update()
    pd.timer.updateTimers()
    
    STAGE[stage_manager]()



end

init()

-- function playdate.leftButtonDown() test_x -= 5 end
-- function playdate.rightButtonDown() test_x += 5 end
