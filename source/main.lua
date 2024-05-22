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

local cover = {
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new()
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new()
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new()
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new()
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new()
    },
    {
        image = gfx.image.new('img/cover'),
        sprite = playdate.graphics.sprite.new()
    },
}
local cover_flow_offset_x = 0
local cover_padding = screenWidth/10

-----------------

function mapValue(old_value, old_min, old_max, new_min, new_max)
    return math.floor((old_value - old_min) * (new_max - new_min) / (old_max - old_min) + new_min)
end

function map_inoutcubic(input, in_min, in_max, out_min, out_max)
    function cubicBezierTransform(value, p0, p1, p2, p3)
        -- 根据贝塞尔曲线的公式计算变换后的值
        local t = value
        local x = (1 - t)^3 * p0.x + 3 * (1 - t)^2 * t * p1.x + 3 * (1 - t) * t^2 * p2.x + t^3 * p3.x
        local y = (1 - t)^3 * p0.y + 3 * (1 - t)^2 * t * p1.y + 3 * (1 - t) * t^2 * p2.y + t^3 * p3.y
    
        -- return {x = x, y = y}
        return y
    end

    local p0 = {x = 0, y = 0}
    local p1 = {x = 0, y = 0.6}
    local p2 = {x = 1, y = 1}
    local p3 = {x = 1, y = 0.4}

    local srcRange = {in_min, in_max}
    local dstRange = {out_min, out_max}
    local ratio = (input - srcRange[1]) / (srcRange[2] - srcRange[1])
    -- local t = cubicBezierTransform(ratio, 0.6, 0.4)
    local t = cubicBezierTransform(ratio, p0, p1, p2, p3)
    local mappedValue = (dstRange[2] - dstRange[1]) * t + dstRange[1]
    return mappedValue
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


function cover_flow_x_map_func(x)
    function _x_divide(x)
        return x/2
    end

    function _x_multi(x)
        return 1.5*x
    end

    function _x_1(x)
        return _x_divide(x)
    end

    function _x_2(x)
        return _x_multi(x) - (_x_multi(100) - _x_1(100))
    end

    function _x_3(x)
        return _x_divide(x) + (_x_2(300) - _x_divide(300))
    end

    if x <= 100 then
        return _x_1(x)
    elseif x > 100 and x < 300 then
        return _x_2(x)
    elseif x >= 300 then
        return _x_3(x)
    end
end

function cover_update_angle_render(x, sprite, image)
    if x < 100 or x >300 then
        return
    end
    local target_angle = mapValue(x, 100, 300, 70, -70)
    -- local target_angle = map_inoutcubic(x, 100, 300, 70, -70)
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
        v.sprite:moveTo(cover_flow_x_map_func(add_x+cover_flow_offset_x), screenHeight/2)
        v.sprite:add()
        add_x += cover_padding
    end
end


function cover_update()
    local add_x = 0
    for k,v in pairs(cover) do
        local target_x = cover_flow_x_map_func(add_x+cover_flow_offset_x)
        cover_update_angle_render(target_x, v.sprite, v.image)
        v.sprite:moveTo(target_x, screenHeight/2)
        -- print("in", cover_flow_offset_x, "out", cover_flow_x_map_func(add_x+cover_flow_offset_x))
        add_x += cover_padding
    end
end

-----------------
function debug_crank()
	-- local crankTicks = playdate.getCrankTicks(10)
    -- if crankTicks == 1 then
    --     tilt_angle_test += 5
    -- elseif crankTicks == -1 then
    --     tilt_angle_test -= 5
    -- end

    local change, acceleratedChange = playdate.getCrankChange()
    cover_flow_offset_x += change
    cover_update()
end

-----------------

test_x = 0
function init()
    playdate.display.setRefreshRate(30)

    gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0,0,screenWidth,screenHeight)
    cover_init()

end


function pd.update()
    gfx.sprite.update()
    pd.timer.updateTimers()
    debug_crank()

end

init()

-- function playdate.leftButtonDown() test_x -= 5 end
-- function playdate.rightButtonDown() test_x += 5 end
