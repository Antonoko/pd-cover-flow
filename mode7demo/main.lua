
import "CoreLibs/crank"

local gfx = playdate.graphics
playdate.display.setScale(1)

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


local tilt_angle_test = 0
function playdate.update()
	local crankTicks = playdate.getCrankTicks(10)
    if crankTicks == 1 then
        tilt_angle_test += 5
    elseif crankTicks == -1 then
        tilt_angle_test -= 5
    end

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 0, 400, 240)
	cover_render("right", tilt_angle_test, gfx.image.new("cover"), 0, 0)

end

function playdate.leftButtonDown() perspective_z -= 1 end
function playdate.rightButtonDown() perspective_z += 1 end
function playdate.upButtonDown() y -= 10 end
function playdate.downButtonDown() y += 10 end
