local switch = false
local ctlStatus = false
local rotation = false
local carRotation = false
local exceptAICarFlag = false
local useFreeCamera = false
local carID = 0
local counter = 0
local angleType = 1
local preangleType = 0
local tky_camera
local cameraSetting
local cameraInfo = mat4x4()
local prePos = {}
for i = 0, 10 do
  prePos[i] = vec3(0,0,0)
end
local defaultExposure = ac.getCar(carID).exposureOutside

--------
-- Simple camera script, using velocity to rotate camera.
--------

--require "sdk/ac_chaser_camera/lib"

-- Options for two different cameras (all distances are in meters):
local maximumCameraAngle = { 54, 68 }  -- degress

-- This thing will smooth car velocity to reduce wobbling with replays or in online:
local carVelocity = smoothing(vec3(), 40)

-- Alternative for ac.getCarVelocity(), possibly smoother:
local calculateVelocityHere = true
local lastCarPos = vec3()

-- Extra thing for looking around:
local lookDirection = smoothing(0, 10)

local globalDT
local rndCamAngles = false
math.randomseed(os.time())
local prevCarDistance = 0

local staticCarPos = vec3(0,0,0)
local staticCarDir = vec3(0,0,0)
local staticCarUp = vec3(0,0,0)
local firstPass = true
local rndList = {}




-- if csp 0.1.80 preview 218 or higher, turn on "useFreeCamera"
if ac.getPatchVersionCode() > 2363 then
  useFreeCamera = true
  
end

local titles ={
  "go around the car", --1
  "bird view",  --2
  "drone view",  --3
  "static position view",  --4
  "road surface view",  --5
  "front view",  --6
  "rear view",  --7
  "wheel and tyre",  --8
  "helicopter view", --9
  "cockpit",  -- 10
  "drivers face",  --11
  "passenger",  --12
  "passenger cam",  --13
  "middle",  --14
  "revolver",  --15
  "backseat",  --16
  "rear axle",  --17
  "front axle",  --18
  "front clip",  --19
  "rear quarter",  --20
  "front wheel look back",  --21
  "front wheel look forward",  --22
  "rear wheel look back",  --23
  "dash cam", --24
  "InitialD Front Cabin Rear", --25
  "InitialD Rear Cabin Front", --26
  "InitialD Side Front Back", --27
  "InitialD Side Back Front", --28
  "Rear Window", --29
  "InitialD Front Pan Left", --30
  "InitialD Front Pan Right", --31
  "InitialD Rear Pan Right", --32
  "InitialD Rear Pan Left", --33
  "InitialD Rear Drop Pan Zoom", --34
  "InitialD Front Drop Pan Zoom", --35
  "InitialD Drive Away", --36
  "test"
}
titles[0] = ""

local carList = {}
function carListUpdate(exceptAICarFlag)
  carList = {}
  for i = 0 , ac.getSim().carsCount - 1  do
    if not (exceptAICarFlag and (ac.getCar(i).isAIControlled or ac.getTyresName(i) == "")) then 
      carList[i] = i .. " " .. ac.getCarName(i)
    end
  end
  print("carList Update")
end

-- Camera Setting SAVE/LOAD
function saveCameraConfig(filename, cameraSetting)
  local data
  data = stringify(cameraSetting)
  io.save(filename, data)
end

function loadCameraConfig(filename)
  local data,err,table, title, array
  local result = true
  if io.fileExists(filename) then
    io.loadAsync(filename, function(err, data)
      if data ~= nil then
        table = stringify.parse(data)
        if table[titles[1]]["exp"] ~= nil and table[titles[1]]["fov"] ~= nil and table[titles[1]]["dof"] ~= nil and table[titles[1]]["time"] ~= nil and table[titles[1]]["shake"] ~= nil then
          cameraSetting = table
          if cameraSetting["roll"] == nil then
            cameraSetting["roll"] = 0
          end

        else
          ui.toast(ui.Icons.Attention, "This is not a camera configuration file.")
          table = nil
          result = false
        end
      else
          ui.toast(ui.Icons.Attention, err)
          table = nil
          result = false
      end
    end) 
  end
  return result
end

-- Preset Setting SAVE/LOAD
local presetCamera = {}

function savePreset(filename)
  local data
  data = stringify(presetCamera)
  io.save(filename, data)  
end

function loadPreset(filename)
  local data,err,table
  if io.fileExists(filename) then
    io.loadAsync(filename, function(err, data)
      table = stringify.parse(data)
      if table[1]["angle"] ~=nil and table[1]["active"] ~=nil then
        presetCamera = table
      else
        ui.toast(ui.Icons.Attention, "This is not a preset configuration file.") 
      end        
    end) 
  end
end

-- NumPadKey Setting SAVE/LOAD
local numPadKey ={}
for i = 1, 10 do
  numPadKey[i] = i
end

function saveNumPadKey(filename)
  local data
  data = stringify(numPadKey)
  io.save(filename, data)  
end

function loadNumPadKey(filename)
  local data,err,table, i
  local check = true
  if io.fileExists(filename) then
    io.loadAsync(filename, function(err, data)
      table = stringify.parse(data)
      for i = 1 , 10 do
        if type(table[i]) ~= "number"  then
          check = false
        end
      end
      if check then
        numPadKey = table
      else
        ui.toast(ui.Icons.Attention, "This is not a numpad configuration file.") 
      end        
    end) 
  end
end



-- function for calc  car angle
function calcCarDirection()
local i, carDir
  for i = 0, 9  do
    prePos[i].x = prePos[i+1].x
    prePos[i].y = prePos[i+1].y
    prePos[i].z = prePos[i+1].z
  end
  prePos[10].x = ac.getCar(carID).position.x
  prePos[10].y = ac.getCar(carID).position.y
  prePos[10].z = ac.getCar(carID).position.z
  carDir = (prePos[10]+prePos[9]+prePos[8])/3 - prePos[0]
  carDir = carDir / math.sqrt(carDir.x^2 + carDir.y^2 + carDir.z^2 )
  if carDir == vec3(0,0,0) or ac.getCar(carID).speedKmh < 1 or ac.getSim().isPaused then
    carDir = ac.getCar(carID).look
  end
  return carDir
end






function calcVerticalGap(position,sp)
  local verticalGap = physics.raycastTrack(position, vec3(0,1,0),3) 
  local verticalGap2 = physics.raycastTrack(position, vec3(0,-1,0),3)
  if verticalGap > 0 and verticalGap < 5 then
    position.y = position.y + verticalGap + 0.5
  elseif verticalGap2 < 0 then
    position.y = sp.y + 3
  end
  return position
end

function shake(position,shakePower)
  if ac.getCar(carID).isCameraOnBoard then
    position.x = position.x + shakePower * math.random() / 150 * ac.getCar(carID).rpm /8000
    position.y = position.y + shakePower * math.random() / 150 * ac.getCar(carID).rpm /8000
    position.z = position.z + shakePower * math.random() / 150 * ac.getCar(carID).rpm /8000
  else
    position.x = position.x + shakePower * math.random() * (15 - math.clamp(ac.getCar(carID).distanceToCamera,0,15)) * ac.getCar(carID).speedKmh / 50000
    position.y = position.y + shakePower * math.random() * (15 - math.clamp(ac.getCar(carID).distanceToCamera,0,15)) * ac.getCar(carID).speedKmh / 50000
    position.z = position.z + shakePower * math.random() * (15 - math.clamp(ac.getCar(carID).distanceToCamera,0,15)) * ac.getCar(carID).speedKmh / 50000
  end
  return position
end


---- calc camera position and angle
-- Point the camera at the car.
function directionToCar(sp, cp, shakePower)
  return shake(sp - cp + vec3(0,1,0),shakePower)
end

-- go around the car
function aroundCar(sp, carDir, counter, time)
  local lx,ly,lz
  local r = ac.getCar(carID).aabbSize.z + 0.3
  lx = r * math.sin(counter/5)
  ly = 1
  lz = r * math.cos(counter/5)
 
  return vec3(sp.x + lx, sp.y + ly, sp.z + lz)
end

-- cockpit view
function positionCockpit(sp, carDir, counter, time)
  local lx,ly,lz
  lx = sp.x + ac.getCar(carID).driverEyesPosition.z*ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
  ly = sp.y + ac.getCar(carID).driverEyesPosition.y
  lz = sp.z + ac.getCar(carID).driverEyesPosition.z*ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x

  return vec3(lx, ly, lz)
end

function directionCockpit(sp, cp, shakePower)
  local q
  if ac.getCar(carID).look.z > 0 then
    q = math.acos(ac.getCar(carID).look.x)
  else
    q = -1 * math.acos(ac.getCar(carID).look.x)
  end
  if ac.getCar(carID).driverEyesPosition.x > 0 then
    q = q - math.pi * 60/180
  else
    q = q + math.pi * 60/180
  end
  return shake(vec3(math.cos(q), -0.1, math.sin(q)),shakePower)
end

-- passenger cam view
function positionPassengerCam(sp, carDir, counter, time)
  local lx,ly,lz
  lx = sp.x + ac.getCar(carID).driverEyesPosition.z*ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
  ly = sp.y + ac.getCar(carID).driverEyesPosition.y
  lz = sp.z + ac.getCar(carID).driverEyesPosition.z*ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x

  return vec3(lx, ly, lz)
end

function directionPassengerCam(sp, cp, shakePower)
  local q
  if ac.getCar(carID).look.z > 0 then
    q = math.acos(ac.getCar(carID).look.x)
	----q = -1 * ac.getCar(carID).look.x
  else
    q = -1 * math.acos(ac.getCar(carID).look.x)
	----q = ac.getCar(carID).look.x
  end
  if ac.getCar(carID).driverEyesPosition.x > 0 then
    --q = q - math.pi * 60/180
	q = q - math.pi * 0/180
  else
    --q = q + math.pi * 60/180
	q = q + math.pi * 0/180
  end
  return shake(vec3(math.cos(q), -0.1, math.sin(q)),shakePower)
end



-- passenger neck follow view
function positionPassenger(sp, carDir, counter, time)
  local lx,ly,lz
  lx = sp.x + ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
  lz = sp.z +ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x 
  ly = sp.y + ac.getCar(carID).driverEyesPosition.y

    
  return vec3(lx, ly, lz)
end

function directionPassenger(sp, cp, shakePower)
  local q
  if ac.getCar(carID).look.z > 0 then
    --q = math.acos(ac.getCar(carID).look.x)
	q = sp.x + ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
	
	p =1 * sp.z +ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x
  else
    --q = -1 * math.acos(ac.getCar(carID).look.x)
	q = -1 * sp.x + ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
	
	p = -1 * sp.z +ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x
  end
  if ac.getCar(carID).driverEyesPosition.x > 0 then
   
	q = 1 * q - math.pi * 0/180
	
  else
   
	q = 1 * q + math.pi * 0/180
  end
 
  return shake(calcCarDirection(),shakePower)   -- working
 
end




--z (front back)
--x (left right)
--y (up down)

-- middle view
function positionMiddle(sp, carDir, counter, time)
  local lx,ly,lz
  --lx = sp.x + ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
  lx = sp.x  
  ly = sp.y + ac.getCar(carID).driverEyesPosition.y
  --lz = sp.z --+ ac.getCar(carID).driverEyesPosition.z -- - 0.45 --+ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x
  --lz = sp.z +ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x
  lz = sp.z 
  
  return vec3(lx, ly, lz)
end

function directionMiddle(sp, cp, shakePower)
  local q
  if ac.getCar(carID).look.z > 0 then
    --q = math.acos(ac.getCar(carID).look.x)
	q = sp.x + ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
	
	p =1 * sp.z +ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x
  else
    --q = -1 * math.acos(ac.getCar(carID).look.x)
	q = -1 * sp.x + ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
	
	p = -1 * sp.z +ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x
  end
  if ac.getCar(carID).driverEyesPosition.x > 0 then
   
	q = 1 * q - math.pi * 0/180
	
  else
   
	q = 1 * q + math.pi * 0/180
  end
  --return shake(vec3(math.cos(q), -0.1, math.sin(q)),shakePower)
  --return shake(vec3(math.cos(-q), -0.1, math.sin(q)),shakePower)
  return shake(vec3(math.acos(q),   -0.1,   math.sin(q)),shakePower)
  --return shake(vec3(math.cos(q),   -0.1,   p),shakePower)
 
end



-- backseat view
function positionBackseat(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 1
	  local height = 1.1 
	  

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	   ac.setCameraPosition ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(0, height, 0) )

	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(0, height, 0) )
end

function directionBackseat(sp, cp, shakePower)
-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()
	
	
	  local pitchAngle = -7.5   
		
	
	  -- Find camera look
	  local cameraLookPosOffset = carDir + carUp * (1 - math.abs(0 ))
	  local cameraLook = (carPos + cameraLookPosOffset - ac.getCameraPosition()):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight))

	  -- Set camera look:
	  
	  return cameraLook
	 
 
end


-- rear axle view
function positionRearAxle(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 2.5
	  local height = 0.1 
	   

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	   ac.setCameraPosition ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(0, height, 0) )

	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(0, height, 0) )
end


function directionRearAxle(sp, cp, shakePower)
-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()
	
	
	  local pitchAngle = 7.5   
		
	
	  -- Find camera look
	  local cameraLookPosOffset = carDir + carUp * (1 - math.abs(0 ))
	  local cameraLook = (carPos + cameraLookPosOffset - ac.getCameraPosition()):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight))

	  -- Set camera look:
	  
	  return cameraLook
	 
 
end


-- front axle view
function positionFrontAxle(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = -2.8
	  local height = 0.12
	   

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	   ac.setCameraPosition ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(0, height, 0) )

	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(0, height, 0) )
end


function directionFrontAxle(sp, cp, shakePower)
-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()
	
	
	  local pitchAngle = -10 
		
	
	  -- Find camera look
	  local cameraLookPosOffset = carDir + carUp * (1 - math.abs(1 )) 
	  local cameraLook = (carPos + cameraLookPosOffset - ac.getCameraPosition()):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight))

	  -- Set camera look:
	  
	  return cameraLook
	 
 
end

-- front clip (fender to fender) view
function positionFrontClip(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = -2.8
	  local height = 0.25
	  local xAxis = 2   -- 0 is dead centre  

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	--   ac.setCameraPosition ( carPos 
	--	+ (carRight * sin - carDir * cos) * distance
	--	+ vec3(0, height, 0) )

	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(xAxis, height, 0) )
end


function directionFrontClip(sp, cp, shakePower)
-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()
	
	
	  local pitchAngle = -10 
		
	
	  -- Find camera look
	  local cameraLookPosOffset = carDir + carUp * (1 - math.abs(1 )) 
	  local cameraLook = (carPos + cameraLookPosOffset - ac.getCameraPosition()):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight))

	  -- Set camera look:
	  
	  return cameraLook
	 
 
end


function positionRearQuarter(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 1
	  local height = 1.1
	  local xAxisRadial = 0  -- (if you use this the camera will shift around oscillate, applies in radial fashion)
	  local xAxis = 2   -- 0 is dead centre 

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()



	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)



	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:


	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * cos) * xAxis
		)

end

function directionRearQuarter(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = -7.5  --0   -- in degrees  180 forward, 0 backward (at front of car)
	
	

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset???


	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(0 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - ac.getCameraPosition()):normalize()



	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight))

	  -- Set camera look:
	
	  
	  return cameraLook
	
end



function positionFrontWheelLookBack(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = -2
	  local height = 0.5
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 1.5   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)

	  -- Up direction for camera (could be used for horizon lock):
	--  local cameraUp = (carUp + vec3(0, 3, 0)):normalize()   -- not needed




	  -- Set camera position:

	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		)

end

function directionFrontWheelLookBack(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 0 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front of car)

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset???

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - ac.getCameraPosition()):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))

	  -- Set camera look:
	
	  
	  return cameraLook
	
end




function positionFrontWheelLookForward(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 0
	  local height = 0.5
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 1.5   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()

		
	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)

	  -- Up direction for camera (could be used for horizon lock):
	--  local cameraUp = (carUp + vec3(0, 3, 0)):normalize()   -- not needed


	  -- Set camera position:
	 

	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		)

end

function directionFrontWheelLookForward(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 0 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front of car)
	
	

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


	-- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)

	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad( -25)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		local cameraPos = carPos + (carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:		  
	  return cameraLook
	
end



function positionRearWheelLookBack(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 0.25
	  local height = 0.5
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 1.30   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()

		--carPos = ac.getCar(carID).position + vec3(5,0,0)   -- same result as using xAxis
		

	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)



	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)

	  -- Up direction for camera (could be used for horizon lock):
	--  local cameraUp = (carUp + vec3(0, 3, 0)):normalize()   -- not needed


	  -- Set camera position:
	 	

	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		)

end

function directionRearWheelLookBack(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 180 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	


cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)




	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad( -25)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		local cameraPos = carPos + (carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()

ac.debug ('ac.getCameraPosition', ac.getCameraPosition() )

	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end


-- Dash cam view
function positionDash(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 0
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()

	
	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)

	  -- Set camera position:
	 

	return ( carPos 
		+ (carRight * sin - carDir * cos) * distance
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos		
		)

end

function directionDash(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = -27 --180 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle
	
  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + (carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(0.5 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end



-- InitialD Front to Cabin to Back View
function positionIDFrontCabinRear(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 0  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()

	

	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	
	--distance = distance  - ac.getCar(carID).aabbSize.z * <SPEED_SCALE> * (1- <distance from car>*counter/time)
	local distanceOffset = ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)

	
	if (ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)) > 4 then
		--don't update distance any more, just hold position
		
		if prevCarDistance == 0 then -- this is the very first time using the view
			prevCarDistance = distance  - distanceOffset * 0.96   -- specific offset; not too much/little offset
		end
		
		distance = prevCarDistance

	else -- we are still moving towards center of car
		prevCarDistance = distance
		distance = distance  - distanceOffset
		
	end
	

	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDFrontCabinRear(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = -27 --180 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	
	--ac.debug('lookDirection', lookDirection)
	--ac.debug('cameraLookPosOffset', cameraLookPosOffset)

cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


--ac.debug('carVelocityDir', carVelocityDir)

	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + (carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(0.5 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()

--ac.debug ('ac.getCameraPosition', ac.getCameraPosition() )

	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end




-- InitialD Rear to Cabin to Front View
function positionIDRearCabinFront(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 0  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()

	

	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	
	--distance = distance  - ac.getCar(carID).aabbSize.z * <SPEED_SCALE> * (1- <distance from car>*counter/time)
	-- multiply by -1 to move the camera forward
	local distanceOffset = -1 * ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)

	
	if (ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)) > 4 then
		--don't update distance any more, just hold position
		
		if prevCarDistance == 0 then -- this is the very first time using the view
			prevCarDistance = distance   - distanceOffset  * 0.96   -- specific offset; not too much/little offset
		end
		
		distance = prevCarDistance

	else -- we are still moving towards center of car
		prevCarDistance = distance
		distance = distance  - distanceOffset
		
	end
	

	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDRearCabinFront(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = -27 --180 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	
	--ac.debug('lookDirection', lookDirection)
	--ac.debug('cameraLookPosOffset', cameraLookPosOffset)

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + (carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(0.5 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end




-- InitialD Side Front to Back view
function positionIDSideFrontBack(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 0  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	

		--distance = distance  - ac.getCar(carID).aabbSize.z * 1 * (1- 5*counter/time)
		--distance = distance  - ac.getCar(carID).aabbSize.z * <SPEED_SCALE> * (1- <distance from car>*counter/time)
	-- make it go forwards via x -1
	local distanceOffset = 1 * ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)

	
	

		prevCarDistance = distance	
		distance = distance  - distanceOffset	

	
	
	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDSideFrontBack(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 0    -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		--local cameraPos = carPos + ( carRight * cos - 0*carDir * cos) * 1  -- (last value 1 is distance)
    local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end




-- InitialD Side Back to Front view
function positionIDSideBackFront(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 0  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	

		--distance = distance  - ac.getCar(carID).aabbSize.z * 1 * (1- 5*counter/time)
		--distance = distance  - ac.getCar(carID).aabbSize.z * <SPEED_SCALE> * (1- <distance from car>*counter/time)
	-- make it go forwards via x -1
	local distanceOffset = -1 * ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)

	
	

		prevCarDistance = distance	
		distance = distance  - distanceOffset	

	
	
	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDSideBackFront(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 0    -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		--local cameraPos = carPos + ( carRight * cos - 0*carDir * cos) * 1  -- (last value 1 is distance)
    local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end



-- Rear Window View
function positionRearWindow(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 0.25  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0 --3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()




	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	 
	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionRearWindow(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 180 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)


	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end



-- InitialD Front Pan Left
function positionIDFrontPanLeft(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = -1.25  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0 --3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:


		--distance = distance  - ac.getCar(carID).aabbSize.z * 1 * (1- 5*counter/time)
		--distance = distance  - ac.getCar(carID).aabbSize.z * <SPEED_SCALE> * (1- <distance from car>*counter/time)
	-- make it go forwards via x -1
	--local distanceOffset = 1 * ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)
	local distanceOffset = ac.getCar(carID).aabbSize.z/2 * (1- 2.5*counter/time)
	
	
	-- hold the camera still when movement animation is over

	xAxis = xAxis - distanceOffset
	

	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDFrontPanLeft(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 180 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end



-- InitialD Front Pan Right
function positionIDFrontPanRight(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = -1.25  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0 --3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:


		--distance = distance  - ac.getCar(carID).aabbSize.z * 1 * (1- 5*counter/time)
		--distance = distance  - ac.getCar(carID).aabbSize.z * <SPEED_SCALE> * (1- <distance from car>*counter/time)
	-- make it go forwards via x -1
	--local distanceOffset = 1 * ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)
	local distanceOffset = ac.getCar(carID).aabbSize.z/2 * (1- 2.5*counter/time)
	
	
	-- hold the camera still when movement animation is over

	xAxis = xAxis + distanceOffset
	

	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDFrontPanRight(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 180 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end


-- InitialD Rear Pan Right
function positionIDRearPanRight(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 3  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0 --3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()

	

	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	
	local distanceOffset = ac.getCar(carID).aabbSize.z/2 * (1- 2.5*counter/time)
	

	xAxis = xAxis - distanceOffset
	

	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDRearPanRight(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 0 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)



	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()



	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end



-- InitialD Rear Pan Left
function positionIDRearPanLeft(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 3  -- don't change this here for this view
	  local height = 1
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0 --3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()

	

	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:
	
	local distanceOffset = ac.getCar(carID).aabbSize.z/2 * (1- 2.5*counter/time)
	

	xAxis = xAxis + distanceOffset
	

	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDRearPanLeft(sp, cp, shakePower)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 0 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)



	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()



	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end





-- InitialD Rear Drop Pan Zoom
function positionIDRearDropPanZoom(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 5  -- don't change this here for this view
	  local height = 1.5
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis =1.75 --3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)



	  -- Set camera position:


	-- make it go forwards via x -1

	local distanceOffset = ac.getCar(carID).aabbSize.z/6 * (1- 2.5*counter/time)
	
	-- Drop Pan Zoom
	xAxis = xAxis - distanceOffset/4
	distance = distance - distanceOffset/2
	height = height + distanceOffset/1.8
	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDRearDropPanZoom(sp, cp, shakePower, counter, time)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	

	local pitchAngle = 0 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	pitchAngle = pitchAngle - ac.getCar(carID).aabbSize.z * (1- 3*counter/time)



	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end




-- InitialD Front Drop Pan Zoom
function positionIDFrontDropPanZoom(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = -4.25  -- don't change this here for this view
	  local height = 1.5
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 1 --3  --  -0.3   -- 0 centre, offsets camera x axis

	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  local carRight = math.cross(carDir, carUp):normalize()


	  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)



	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)


	  -- Set camera position:

	local distanceOffset = ac.getCar(carID).aabbSize.z/6 * (1- 2.5*counter/time)
	

	-- drop pan zoom
	xAxis = xAxis - distanceOffset/4
	distance = distance + distanceOffset/2
	height = height + distanceOffset/1.8
	
	
	return ( carPos 
		+ (carRight * sin - carDir * cos) * ( distance    )
		+ vec3(xAxisRadial, height, 0) 
		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
		)

end

function directionIDFrontDropPanZoom(sp, cp, shakePower, counter, time)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 180 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	pitchAngle = pitchAngle + ac.getCar(carID).aabbSize.z * (1- 3*counter/time)


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end



-- InitialD Drive Away
function positionIDDriveAway(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 12  -- don't change this here for this view
	  local height = 0.25
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0 --3  --  -0.3   -- 0 centre, offsets camera x axis

	-- We only want to capture this once and keep it static
	if firstPass == true then
	
	
	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()

	  staticCarPos = carPos

	  firstPass=false

	end  -- if firstPass == true	  
	

	  -- Set camera position:

	local distanceOffset = math.abs(ac.getCar(carID).aabbSize.z/6 * (1- 2.5*counter/time))
	

	height = height + distanceOffset *1.5

	
	return ( staticCarPos + vec3(0,height,3))
	

end

function directionIDDriveAway(sp, cp, shakePower, counter, time)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 0 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	
	--ac.debug('lookDirection', lookDirection)
	--ac.debug('cameraLookPosOffset', cameraLookPosOffset)

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()


	pitchAngle = pitchAngle + ac.getCar(carID).aabbSize.z * (1- 3*counter/time)


	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end






----------------------------------------------------
----------------------------------------------------
--              TEST FUNC
----------------------------------------------------
----------------------------------------------------



function positionTest(sp, carDir, counter, time)
	-- Will be called each frame:
	-- Note: `dt` is time passed since last frame, `cameraIndex` is 1 or 2, depending on which camera is
	-- chosen.				

	  smoothing.setDT(globalDT)

	  -- Get AC camera parameters with some corrections to be somewhat compatible:
	 
	  local distance = 12  -- don't change this here for this view
	  local height = 0.25
	  local xAxisRadial = 0   -- 0 is dead centre
	  local xAxis = 0 --3  --  -0.3   -- 0 centre, offsets camera x axis

	-- We only want to capture this once and keep it static
	if firstPass == true then
	
--	ac.debug('000 counter', counter)
	  -- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
--	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
--	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	  staticCarPos = carPos
--	  staticCarDir = carDir
--	  staticCarUp = carUp
	  
--	  ac.debug('001 sCarPos', staticCarPos)
--	  ac.debug('001 sCarDir', staticCarDir)
--	  ac.debug('001 sCarUp', staticCarUp)
	  
	  firstPass=false
--	else	-- firstPass is false
--		carPos = staticCarPos
--		carDir = staticCarDir
--		carUp = staticCarUp
end  -- if firstPass == true	  
	  
	-- local carPos = ac.getCar(carID).position --  ac.getCarPosition() 
	--  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	--  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	
	
--	ac.debug('002 sCarPos', staticCarPos)
--	  ac.debug('002 sCarDir', staticCarDir)
--	  ac.debug('002 sCarUp', staticCarUp)
--	ac.debug('003 counter', counter)
	
--	  local carRight = math.cross(carDir, carUp):normalize()
	
		
		
		



	  -- Normalize car velocity:
--	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)




	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
--	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
--	  cameraIndex = 1  -- have to set it to 1 or 2
--	  local cameraAngle = -velocityX * math.rad(maximumCameraAngle[cameraIndex])


	  -- Sine and cosine for camera angle
--	  local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)

	  -- Up direction for camera (could be used for horizon lock):
	--  local cameraUp = (carUp + vec3(0, 3, 0)):normalize()   -- not needed

	--ac.debug('carPos 2nd', carPos)
	--ac.debug('carRight', carRight)


	  -- Set camera position:
	 


		--distance = distance  - ac.getCar(carID).aabbSize.z * 1 * (1- 5*counter/time)
		--distance = distance  - ac.getCar(carID).aabbSize.z * <SPEED_SCALE> * (1- <distance from car>*counter/time)
	-- make it go forwards via x -1
	--local distanceOffset = 1 * ac.getCar(carID).aabbSize.z * 1 * (1- 2*counter/time)
	local distanceOffset = math.abs(ac.getCar(carID).aabbSize.z/6 * (1- 2.5*counter/time))
	
	
	-- hold the camera still when movement animation is over

--		prevCarDistance = distance	
--		distance = distance  + distanceOffset	

--	xAxis = xAxis - distanceOffset/4
--	distance = distance - distanceOffset * 10
	height = height + distanceOffset *1.5
	
--	ac.debug('004 height', height)
--	ac.debug('distance', distance)
--	ac.debug('counterovertime', ac.getCar(carID).aabbSize.z * 2*counter/time)



	
	return ( staticCarPos + vec3(0,height,3))
	
--	carPos  
--		+ (carRight * sin - carDir * cos) * ( distance    )
--		+ vec3(xAxisRadial, height, 0)  
--		+ (carRight * cos - carDir * sin) * xAxis  --orig cos cos
		
--		)

end

function directionTest(sp, cp, shakePower, counter, time)
	
	
	-- Get car position and vectors:
	  local carPos = ac.getCar(carID).position --  ac.getCarPosition()
	  local carDir = ac.getCar(carID).look  --ac.getCarDirection()
	  local carUp = ac.getCar(carID).up  --ac.getCarUp()
	local carRight = math.cross(carDir, carUp):normalize()
	
	
	local pitchAngle = 0 -- -47.5  --0   -- pitch (angle up/down) in degrees  180 forward, 0 backward (at front or back of car??)
	
	
	--ac.debug('lookDirection', lookDirection)
	--ac.debug('cameraLookPosOffset', cameraLookPosOffset)

	cameraLookPosOffset = vec3(0,0,0)  -- controls direction offset??? don't use it, causes camera to sudden change angle


  -- Normalize car velocity:
	  local carVelocityDir = math.normalize(ac.getCar(carID).velocity + carDir * 0.01)


--ac.debug('carVelocityDir', carVelocityDir)

	  -- Get rotation coefficient, from -1 to 1, based on X-component of local velocity (that’s what dot is for)
	  -- and taking absolute speed into account as well:
	  local velocityX = math.clamp(math.dot(carRight, carVelocityDir) * math.pow(#ac.getCar(carID).velocity, 0.5) / 10, -1, 1)

	  -- Camera angle for given coefficient:
	  cameraIndex = 1  -- have to set it to 1 or 2
	  local cameraAngle = -velocityX * math.rad(54)    -- (maximumCameraAngle[cameraIndex])   use to change xaxis???
	-- Sine and cosine for camera angle
		local sin, cos = math.sin(cameraAngle), math.cos(cameraAngle)
	-- Set camera position:
		-- adjust cos sin combination to rotate camera 90degrees
		local cameraPos = carPos + ( carRight * sin - carDir * cos) * 1  -- (last value 1 is distance)
    --local cameraPos =  carPos +carRight 

	  -- Find camera look
	  local cameraLookPosOffset = carDir * cameraLookPosOffset + carUp * (1 - math.abs(1 ))  -- abs value also controls something (lookDirection.val)
	  local cameraLook = (carPos + cameraLookPosOffset - cameraPos ):normalize()

--ac.debug ('ac.getCameraPosition', ac.getCameraPosition() )

--	ac.debug('000 pitchAngle', pitchAngle)
	ac.debug('000 counter', counter)
	ac.debug('000 time', time)
	ac.debug('000 formula stuff', ac.getCar(carID).aabbSize.z/2 * (1- 2.5*counter/time) )
	pitchAngle = pitchAngle + ac.getCar(carID).aabbSize.z * (1- 3*counter/time)

ac.debug('001 pitchAngle', pitchAngle)

	  -- Use for `pitchAngle`:
	  cameraLook:rotate(quat.fromAngleAxis(math.radians(pitchAngle), carRight ))
	

	  -- Set camera look:	
	  
	  return cameraLook
	
end



----------------------------------------------------
----------------------------------------------------
--              TEST FUNC
----------------------------------------------------
----------------------------------------------------







-- revolver view
function positionRevolver(sp, carDir, counter, time)
  local lx,ly,lz
  
  lx = sp.x  
  ly = sp.y + ac.getCar(carID).driverEyesPosition.y
  lz = sp.z - 3.5
  
  return vec3(lx, ly, lz)
end

function directionRevolver(sp, cp, shakePower)
  local q
  if ac.getCar(carID).look.z > 0 then
    --q = math.acos(ac.getCar(carID).look.x)
	q = sp.x + ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
	
	p =1 * sp.z +ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x
  else
    --q = -1 * math.acos(ac.getCar(carID).look.x)
	q = -1 * sp.x + ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.x - ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.z
	
	p = -1 * sp.z +ac.getCar(carID).driverEyesPosition.z *ac.getCar(carID).look.z + ac.getCar(carID).driverEyesPosition.x * ac.getCar(carID).look.x
  end
  if ac.getCar(carID).driverEyesPosition.x > 0 then
   	q = 1 * q - math.pi * 0/180	
  else
   	q = 1 * q + math.pi * 0/180
  end
  
  return shake(vec3(math.acos(q),   -0.1,   math.sin(q)),shakePower)
 
end



-- front view position
function positionFrontView(sp, carDir, counter, time)
  local lx,ly,lz
  lx = sp.x + ac.getCar(carID).aabbSize.z * 2 * (1-counter/time) * carDir.x
  ly = sp.y + ac.getCar(carID).driverEyesPosition.y + 0.5
  lz = sp.z + ac.getCar(carID).aabbSize.z * 2 * (1-counter/time) * carDir.z
  return vec3(lx, ly, lz)
end

-- rear view potision
function positionRearView(sp, carDir, counter, time)
  local lx,ly,lz
  lx = sp.x - ac.getCar(carID).aabbSize.z*carDir.x + ac.getCar(carID).aabbSize.x/2 * carDir.z
  ly = sp.y + ac.getCar(carID).aabbSize.y/2
  lz = sp.z -ac.getCar(carID).aabbSize.z*carDir.z - ac.getCar(carID).aabbSize.x/2 * carDir.x

  return vec3(lx, ly, lz)
end

-- helicopter view potision
function positionHelicopter(sp, carDir, counter, time)
  local lx,ly,lz
  local distance = 50
  lx = sp.x
  ly = sp.y + distance
  lz = sp.z
  return vec3(lx, ly, lz)
end

-- road surface view
function positionRoadSurface(sp, carDir, counter, time)
  local lx,ly,lz
  lx = sp.x + 20 * (1-2*counter/time) * carDir.x
  ly = sp.y + 0.5
  lz = sp.z + 20 * (1-2*counter/time) * carDir.z

  return calcVerticalGap(vec3(lx, ly, lz), sp)
end

-- static position view
function positionStatic(sp, carDir, counter, time)
    local cameraPos
    local rand = math.random()
    local verticalGap = 0
    local cameraDir = vec3(0,0,0)
    local cameraDis = 0
    local holizonGap = 0  
  
    cameraPos = vec3(
      sp.x + carDir.x * 1 * ac.getCar(carID).speedKmh * 1000/3600 - 2 * carDir.z * (ac.getCar(carID).steer/30 + rand), 
      sp.y + carDir.y * 1 * ac.getCar(carID).speedKmh * 1000/3600 + 3 * rand ,
      sp.z + carDir.z * 1 * ac.getCar(carID).speedKmh * 1000/3600 + 2 * carDir.x * (ac.getCar(carID).steer/30 + rand))
  
    cameraDir = vec3(sp.x - cameraPos.x, sp.y - cameraPos.y, sp.z-cameraPos.z)
    cameraDis = math.sqrt((sp.x-cameraPos.x)^2 + (sp.y-cameraPos.y)^2 + (sp.z-cameraPos.z)^2)
  
    holizonGap = physics.raycastTrack(cameraPos, cameraDir, cameraDis) 
    if holizonGap < cameraDis then
      cameraPos = vec3(
        sp.x + 20  * carDir.x - 2 * carDir.z * rand,
        sp.y + 20  * carDir.y + 1 * rand,
        sp.z + 20  * carDir.z + 2 * carDir.x * rand)
    end
  
    return calcVerticalGap(cameraPos, sp)    
  end

function directionStatic(sp, cp, shakePower)
  return shake(vec3(
    sp.x - cp.x, 
    sp.y + ac.getCar(carID).driverEyesPosition.y - cp.y, 
    sp.z - cp.z)
    ,shakePower)
end

-- drivers face view
function positionDriverFace(sp, carDir, counter, time)
  local lx,ly,lz
  if ac.getPatchVersionCode() > 2144 and ac.getCar(carID).isLeftHandDrive then
    lx = sp.x + (ac.getCar(carID).driverEyesPosition.z + 2 * (1.1-counter/time)) * ac.getCar(carID).look.x + ac.getCar(carID).side.x * ac.getCar(carID).aabbSize.x /2
    ly = sp.y + ac.getCar(carID).driverEyesPosition.y
    lz = sp.z + (ac.getCar(carID).driverEyesPosition.z + 2 * (1.1-counter/time)) * ac.getCar(carID).look.z + ac.getCar(carID).side.z * ac.getCar(carID).aabbSize.x /2
    else
    lx = sp.x + (ac.getCar(carID).driverEyesPosition.z + 2 * (1.1-counter/time)) * ac.getCar(carID).look.x - ac.getCar(carID).side.x * ac.getCar(carID).aabbSize.x /2
    ly = sp.y + ac.getCar(carID).driverEyesPosition.y
    lz = sp.z + (ac.getCar(carID).driverEyesPosition.z + 2 * (1.1-counter/time)) * ac.getCar(carID).look.z - ac.getCar(carID).side.z * ac.getCar(carID).aabbSize.x /2
    end



  return vec3(lx, ly, lz)
end

function directionDriverFace(sp, cp, shakePower)
  return shake(vec3(sp.x - cp.x , 0, sp.z - cp.z),shakePower)
end

-- Wheel & Tyre
function positionWheel(sp, carDir, counter, time)
  return vec3(
    ac.getCar(carID).wheels[1].position.x - 2 * ac.getCar(carID).look.z,
    ac.getCar(carID).wheels[1].position.y,
    ac.getCar(carID).wheels[1].position.z + 3 * ac.getCar(carID).look.x)
end
function directionWheel(sp, cp, shakePower)
  return shake(ac.getCar(carID).side + vec3(0,0,0), shakePower)
end

-- bird view
function positionBird(sp, carDir, counter, time)
  local lx,ly,lz
    local r = math.abs(30 * 2 * (0.5-counter/time)^2) + 3
  lx = r * math.cos(counter/time * math.pi)
  ly = math.abs(4 * 2 * (0.5-counter/time)^2) +2
  lz = r * math.sin(counter/time * math.pi)
  return vec3(sp.x + lx, sp.y + ly, sp.z + lz)
end

--drone view
local xG = 0
function positionDrone(sp, carDir, counter, time)
  local lx,ly,lz
  if math.abs(ac.getCar(carID).acceleration.x) > 0.1 then
    xG = xG - ac.getCar(carID).acceleration.x /50
  else
    xG = xG * 0.99
  end
  lx = sp.x - (ac.getCar(carID).aabbSize.z + 3) * carDir.x + (xG + math.sin(math.pi * counter/3)) * carDir.z 
  ly = sp.y  + ac.getCar(carID).aabbSize.y + 1 - math.cos(math.pi * counter/3) / 10
  lz = sp.z - (ac.getCar(carID).aabbSize.z + 3) * carDir.z - (xG + math.sin(math.pi * counter/3)) * carDir.x 
  
  return vec3(lx,ly,lz)
end

function directionDrone(sp, cp, shakePower)
  return shake(sp - cp + vec3(0,1,0),shakePower)
end

function rollDrone()
  return math.clamp (xG/math.abs(xG) * xG ^2 /10, -math.pi /4, math.pi /4)
end

function rollDroneFreeCamera(carDir)
  return vec3(-carDir.x,1,-carDir.z)
end

-- control position and direction 

function calcPosition(title, sp, carDir, counter, time)
  local position
  if title == "go around the car" then position = aroundCar(sp, carDir, counter, time) end
  if title == "cockpit" then position = positionCockpit(sp, carDir, counter, time) end
  if title == "front view" then position = positionFrontView(sp, carDir, counter, time) end
  if title == "rear view" then position = positionRearView(sp, carDir, counter, time) end
  if title == "helicopter view" then position = positionHelicopter(sp, carDir, counter, time) end
  if title == "road surface view" then position = positionRoadSurface(sp, carDir, counter, time) end
  if title == "static position view" then position = positionStatic(sp, carDir, counter, time) end
  if title == "drivers face" then position = positionDriverFace(sp, carDir, counter, time) end
  if title == "wheel and tyre" then position = positionWheel(sp, carDir, counter, time) end
  if title == "bird view" then position = positionBird(sp, carDir, counter, time) end
  if title == "drone view" then position = positionDrone(sp, carDir, counter, time) end
  if title == "passenger" then position = positionPassenger(sp, carDir, counter, time) end
  if title == "passenger cam" then position = positionPassengerCam(sp, carDir, counter, time) end
  if title == "middle" then position = positionMiddle(sp, carDir, counter, time) end
  if title == "revolver" then position = positionRevolver(sp, carDir, counter, time) end
  if title == "backseat" then position = positionBackseat(sp, carDir, counter, time) end
  if title == "rear axle" then position = positionRearAxle(sp, carDir, counter, time) end
  if title == "front axle" then position = positionFrontAxle(sp, carDir, counter, time) end
  if title == "front clip" then position = positionFrontClip(sp, carDir, counter, time) end
  if title == "rear quarter" then position = positionRearQuarter(sp, carDir, counter, time) end
  if title == "front wheel look back" then position = positionFrontWheelLookBack(sp, carDir, counter, time) end
  if title == "front wheel look forward" then position = positionFrontWheelLookForward(sp, carDir, counter, time) end
  if title == "rear wheel look back" then position = positionRearWheelLookBack(sp, carDir, counter, time) end
  if title == "dash cam" then position = positionDash(sp, carDir, counter, time) end
  if title == "InitialD Front Cabin Rear" then position = positionIDFrontCabinRear(sp, carDir, counter, time) end
  if title == "InitialD Rear Cabin Front" then position = positionIDRearCabinFront(sp, carDir, counter, time) end
  if title == "InitialD Side Front Back" then position = positionIDSideFrontBack(sp, carDir, counter, time) end
  if title == "InitialD Side Back Front" then position = positionIDSideBackFront(sp, carDir, counter, time) end 
  if title == "Rear Window" then position = positionRearWindow(sp, carDir, counter, time) end
  if title == "InitialD Front Pan Left" then position = positionIDFrontPanLeft(sp, carDir, counter, time) end
  if title == "InitialD Front Pan Right" then position = positionIDFrontPanRight(sp, carDir, counter, time) end
  if title == "InitialD Rear Pan Right" then position = positionIDRearPanRight(sp, carDir, counter, time) end
  if title == "InitialD Rear Pan Left" then position = positionIDRearPanLeft(sp, carDir, counter, time) end  
  if title == "InitialD Rear Drop Pan Zoom" then position = positionIDRearDropPanZoom(sp, carDir, counter, time) end	
  if title == "InitialD Front Drop Pan Zoom" then position = positionIDFrontDropPanZoom(sp, carDir, counter, time) end
  if title == "InitialD Drive Away" then position = positionIDDriveAway(sp, carDir, counter, time) end
  
  if title == "test" then position = positionTest(sp, carDir, counter, time) end
  return position
end

function calcDirection(title, sp, cp, shakePower, counter, time)
  local direction
  if title == "go around the car" then direction = directionToCar(sp, cp, shakePower) end
  if title == "cockpit" then direction = directionCockpit(sp, cp, shakePower) end
  if title == "front view" then direction = directionToCar(sp, cp, shakePower) end
  if title == "rear view" then direction = directionToCar(sp, cp, shakePower) end
  if title == "helicopter view" then direction = directionToCar(sp, cp, shakePower) end
  if title == "road surface view" then direction = directionToCar(sp, cp, shakePower) end
  if title == "static position view" then direction = directionToCar(sp, cp, shakePower) end
  if title == "drivers face" then direction = directionDriverFace(sp, cp, shakePower) end
  if title == "wheel and tyre" then direction = directionWheel(sp, cp, shakePower) end
  if title == "bird view" then direction = directionToCar(sp, cp, shakePower) end
  if title == "drone view" then direction = directionDrone(sp, cp, shakePower) end
  if title == "passenger" then direction = directionPassenger(sp, cp, shakePower) end
  if title == "passenger cam" then direction = directionPassengerCam(sp, cp, shakePower) end
  if title == "middle" then direction = directionMiddle(sp, cp, shakePower) end
  if title == "revolver" then direction = directionRevolver(sp, cp, shakePower) end
  if title == "backseat" then direction = directionBackseat(sp, cp, shakePower) end
  if title == "rear axle" then direction = directionRearAxle(sp, cp, shakePower) end
  if title == "front axle" then direction = directionFrontAxle(sp, cp, shakePower) end
  if title == "front clip" then direction = directionFrontClip(sp, cp, shakePower) end
  if title == "rear quarter" then direction = directionRearQuarter(sp, cp, shakePower) end
  if title == "front wheel look back" then direction = directionFrontWheelLookBack(sp, cp, shakePower) end
  if title == "front wheel look forward" then direction = directionFrontWheelLookForward(sp, cp, shakePower) end
  if title == "rear wheel look back" then direction = directionRearWheelLookBack(sp, cp, shakePower) end
  if title == "dash cam" then direction = directionDash(sp, cp, shakePower) end
  if title == "InitialD Front Cabin Rear" then direction = directionIDFrontCabinRear(sp, cp, shakePower) end
  if title == "InitialD Rear Cabin Front" then direction = directionIDRearCabinFront(sp, cp, shakePower) end
  if title == "InitialD Side Front Back" then direction = directionIDSideFrontBack(sp, cp, shakePower) end 
  if title == "InitialD Side Back Front" then direction = directionIDSideBackFront(sp, cp, shakePower) end 
  if title == "Rear Window" then direction = directionRearWindow(sp, cp, shakePower) end
  if title == "InitialD Front Pan Left" then direction = directionIDFrontPanLeft(sp, cp, shakePower) end   
  if title == "InitialD Front Pan Right" then direction = directionIDFrontPanRight(sp, cp, shakePower) end   
  if title == "InitialD Rear Pan Right" then direction = directionIDRearPanRight(sp, cp, shakePower) end
  if title == "InitialD Rear Pan Left" then direction = directionIDRearPanLeft(sp, cp, shakePower) end  
  if title == "InitialD Rear Drop Pan Zoom" then direction = directionIDRearDropPanZoom(sp, cp, shakePower, counter, time) end
  if title == "InitialD Front Drop Pan Zoom" then direction = directionIDFrontDropPanZoom(sp, cp, shakePower, counter, time) end
  if title == "InitialD Drive Away" then direction = directionToCar(sp, cp, shakePower, counter, time) end
  
  if title == "test" then direction = directionTest(sp, cp, shakePower, counter, time) end
  return direction
end

function calcRoll(title, carDir)
  local roll
  if useFreeCamera then
    roll = vec3(math.sin(math.pi * cameraSetting["roll"] /180),1,0)
    if title == "drone view" then roll = rollDroneFreeCamera(carDir) end
  else
    roll = math.pi * cameraSetting["roll"] /180
    if title == "drone view" then roll = rollDrone() end
  end
  return roll
end

-- Main
carListUpdate(exceptAICarFlag)

local result
if io.fileExists(__dirname .. "\\cameraSetting.json") then
  result = loadCameraConfig(__dirname .. "\\cameraSetting.json")
  if result == false then
    return nil
  end
end


if io.fileExists(__dirname .. "\\numPadKey.json") then
  result = loadNumPadKey(__dirname .. "\\numPadKey.json")
  if result == false then
    return nil
  end
end

local presetCount
if io.fileExists(__dirname .. "\\presetCamera.json") then
  loadPreset(__dirname .. "\\presetCamera.json")
else
  for presetCount = 1, 10 do
    presetCamera[presetCount] = {}
    if titles[presetCount] == nil then
      presetCamera[presetCount]["angle"] = 0
      presetCamera[presetCount]["active"] = false
    else
      presetCamera[presetCount]["angle"] = presetCount
      presetCamera[presetCount]["active"] = true
    end
  end
end

function update(dt)
  local carDir, time, shakePower, fov, dof, roll, focusCheck

	globalDT = dt

  if switch then    -- turned on
  
   
    if ctlStatus then
-- camera active
      counter = counter + dt
      carDir = calcCarDirection()

      -- Playback time setting  (if not rotating through each preset cam and loop is turned on)
      if rotation == false and cameraSetting[titles[angleType]]["loop"] == 1 then
        time = -1
      else  --set time equal to cam angle defined time
        time = cameraSetting[titles[angleType]]["time"]
      end

      -- Initialization when angles are switched
      if angleType ~= preangleType or (time > 0 and counter > time) then
        if rotation == true then
          repeat
            presetCount = presetCount + 1
            if presetCount > #presetCamera then 
              presetCount = 1 
              if carRotation then   -- rotate through list of cars
                repeat
                  carID = carID + 1
                  if carID > ac.getSim().carsCount - 1 then
                    carID = 0
                  end
                  if exceptAICarFlag and (ac.getCar(carID).isAIControlled or ac.getTyresName(carID) == "") then
                    focusCheck = false
                  else
                    focusCheck = true
                  end
                until (ac.getCar(carID).speedKmh > 10 and focusCheck) or carID == 0
              end
            end
          until presetCamera[presetCount].active == true and presetCamera[presetCount].angle > 0 
          angleType = presetCamera[presetCount].angle

			
			prevCarDistance = 0   --reset when we switch camera angles
        end


			
			
-- if Random Camera Angle is selected 
		if rndCamAngles == true then
			
			
		--	ac.debug("000 total cams",#titles)
		--	ac.debug('000 time', time)
		--	ac.debug('000 counter', counter)
		--	ac.debug("rnd num before if", math.random(1, #titles))
		--	ac.debug('001(time > 0 and counter >= time)',(time > 0 and counter >= time))
		--	ac.debug('001(counter >= time)',(counter >= time))
		--	ac.debug('003 angleType', angleType)
		--	ac.debug('003 preangleType', preangleType)
			
			
			
			time = cameraSetting[titles[angleType]]["time"]  -- set the timer based on titles preset timer
			
			--ac.debug('time', time)
			--ac.debug('counter', counter)
			
			if (time > 0 and counter > time) then  -- and the timer for currrent cam is complete
			
				
				--angleType = math.random(1,#titles)
				angleType = returnRandomAngleNumber( rndList)
				
						
				preangleType = angleType 
				counter = 0
				presetCount = angleType
				prevCarDistance = 0

				
				firstPass = true   -- reset staticCam firstPass counter
			end
		end
	--ac.debug('rndCamAngles', rndCamAngles)
		


        if cameraSetting[titles[angleType]]["cameramove"] == 0 then
          cameraInfo.position = calcPosition(titles[angleType], ac.getCar(carID).position, carDir, counter, time )
        end

		
		if titles[angleType] == "cockpit" then
          ac.setCurrentCamera(5)   --orig
		
        else
          ac.setCurrentCamera(6) 
        end
 
 
        counter = 0
        preangleType = angleType
      end

      -- numPad Key check
      -- switching Camera Angle by NumPad Key.
      if ac.isKeyDown(ac.KeyIndex.NumPad0) then
        angleType = numPadKey[1]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad1) then
        angleType = numPadKey[2]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad2) then
        angleType = numPadKey[3]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad3) then
        angleType = numPadKey[4]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad4) then
        angleType = numPadKey[5]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad5) then
        angleType = numPadKey[6]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad6) then
        angleType = numPadKey[7]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad7) then
        angleType = numPadKey[8]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad8) then
        angleType = numPadKey[9]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.NumPad9) then
        angleType = numPadKey[10]
        rotation = false
--        ui.toast(ui.Icons.Info, "Camera Mode: " .. titles[angleType]) 
        preangleType = angleType - 1
      elseif ac.isKeyDown(ac.KeyIndex.Return) then
        rotation = true
        presetCount = 0
--        ui.toast(ui.Icons.Info, "preset rotation ON.") 
        preangleType = angleType - 1
      end    

	


      -- Camera angle control
      shakePower = cameraSetting[titles[angleType]]["shake"]
      fov = cameraSetting[titles[angleType]]["fov"]
      dof = cameraSetting[titles[angleType]]["dof"]
      exp = cameraSetting[titles[angleType]]["exp"] * defaultExposure



      if cameraSetting[titles[angleType]]["cameramove"] == 1 then
        cameraInfo.position = calcPosition(titles[angleType], ac.getCar(carID).position, carDir, counter, time )
      end
      cameraInfo.look = calcDirection(titles[angleType], ac.getCar(carID).position, cameraInfo.position, shakePower, counter, time)
	  roll = calcRoll(titles[angleType], carDir)


	  
      if useFreeCamera then


   		
		ac.setCameraPosition(cameraInfo.position)
		ac.setCameraDirection(cameraInfo.look, roll)
		
        ac.setCameraFOV(fov)
        ac.setCameraExposure(exp)
        if cameraSetting["dofSwitch"] then
          if dof > 0 then  
            ac.setCameraDOF(dof)
          else
            ac.setCameraDOF(ac.getCar(carID).distanceToCamera)
          end
        else
          ac.setCameraDOF(0)
        end


		
		
      else  -- don't useFreeCamera
	  
        cameraInfo.row1 = cameraInfo.rotation(roll,carDir).row1
        cameraInfo.row2 = cameraInfo.rotation(roll,carDir).row2
        tky_camera.transform = cameraInfo
        tky_camera.fov = fov
        tky_camera.exposure = exp
        if cameraSetting["dofSwitch"] then
          tky_camera.dofFactor = 1
          if dof > 0 then
            tky_camera.dofDistance = dof
          else
            tky_camera.dofDistance = ac.getCar(carID).distanceToCamera
          end
        else -- NOT dofSwitch
          tky_camera.dofFactor = 0
        end
      end

	


    else  -- not ctlStatus
-- camera initialize
      if useFreeCamera then
        ac.setCurrentCamera(6) 
      else
        tky_camera = ac.grabCamera('tky_camera')
      end
      ctlStatus = true
      counter = 0
    end
	
		
	
  else  -- switch = false
    if ctlStatus  then
-- camera finalize


      if useFreeCamera then
        ac.setCurrentCamera(2) 
        ac.setCameraExposure(defaultExposure)
      else
        tky_camera.exposure = defaultExposure
        tky_camera:dispose() 
      end
      ctlStatus = false
    else
-- camera inactive

    end
  end
end

--///////////////////////////////////////
--    GUI related
--///////////////////////////////////////

function script.windowMain(dt)
  local result, value, changed
  if ui.checkbox('Camera ON/OFF', switch) then
    switch = not switch
  end
  
  -- introduce random camera angles
  if ui.checkbox('Random Cam Angles', rndCamAngles) then
    rndCamAngles = not rndCamAngles
	rotation = false
	presetCount = 0
  end
  if rndCamAngles then
	ui.sameLine()
    ui.text("current angle: " .. presetCount .. ": " .. titles[angleType])
  end


  if ui.checkbox('Preset Rotation', rotation) then
    rotation = not rotation
	rndCamAngles = false
    if rotation then
      presetCount = 0
    end
    preangleType = angleType - 1
  end
  if switch and rotation then
    ui.sameLine()
    ui.text("current angle: " .. presetCount .. ": " .. titles[presetCount])
  end

  ui.setNextItemWidth(220)
  carID, result = ui.combo("Car in Focus", carID, ui.ComboFlags, carList)
  if switch and rotation then
    if ui.checkbox('Car Rotation', carRotation) then
      carRotation = not carRotation
    end
    ui.sameLine()
    ui.text("current car: " .. ac.getCarName(carID))
    if ui.checkbox('except AI car', exceptAICarFlag) then
      exceptAICarFlag = not exceptAICarFlag
      carListUpdate(exceptAICarFlag)
    end
  end

  ui.text("")
  ui.tabBar("tab", function()
    ui.tabItem("Preset Setting", presetSetting)
    ui.tabItem("Camera Setting", setting)
    ui.tabItem("numPad Setting", numPadSetting)
  end)
end

function presetSetting()
  ui.text("")

  local i
  if ui.button("SAVE") then
    savePreset(__dirname .. "\\presetCamera.json")
  end
  ui.sameLine()
  if ui.button("SAVE AS") then
    os.saveFileDialog({
      title = "save preset", 
      folder = __dirname .. "\\preset",
      defaultExtension = "json",
      fileName = "presetCamera.json",
      fileTypes = {{name = "json file", mask = "*.json"}},
      addAllFilesFileType =false,
      },
      function(err, filename)
        savePreset(filename)
      end
    )
  end

  ui.sameLine()

  if ui.button("LOAD") then
    os.openFileDialog({
      title = "select preset", 
      folder = __dirname .. "\\preset",
      fileTypes = {{name = "json file", mask = "*.json"}},
      addAllFilesFileType =false,
      },
      function(err, filename)
        if io.fileExists(filename) then
          loadPreset(filename)
        end
      end
    )
  end

  ui.text("---------------------")
  ui.text("check box is active")
  for i = 1 ,#presetCamera do
    if ui.checkbox(i, presetCamera[i]["active"]) then
      presetCamera[i]["active"] = not presetCamera[i]["active"]
    end
    ui.sameLine()
    ui.setNextItemWidth(180)
    presetCamera[i]["angle"], result = ui.combo("camera angle" .. i, presetCamera[i]["angle"], ui.ComboFlags, titles)
  end

end

function setting()
  ui.text("")

  local result, err, filename
  if ui.button("SAVE") then
    saveCameraConfig(__dirname .. "\\cameraSetting.json", cameraSetting)
  end
  ui.sameLine()
  if ui.button("SAVE AS") then
    os.saveFileDialog({
      title = "save advanced camera setting", 
      folder = __dirname .. "\\setting",
      defaultExtension = "json",
      fileName = ac.getCarID() .. "_camera_setting.json",
      fileTypes = {{name = "json file", mask = "*.json"}},
      addAllFilesFileType =false,
      },
      function(err, filename)
        saveCameraConfig(filename, cameraSetting)
      end
    )
  end
  ui.sameLine()
  if ui.button("LOAD") then
    os.openFileDialog({
      title = "select camera setting", 
      folder = __dirname .. "\\setting",
      fileTypes = {{name = "json file", mask = "*.json"}},
      addAllFilesFileType =false,
      },
      function(err, filename)
        result = loadCameraConfig(filename)
      end
    )
  end

  ui.text("---------------------")
  if ui.checkbox('DOF Enable', cameraSetting["dofSwitch"]) then
    cameraSetting["dofSwitch"] = not cameraSetting["dofSwitch"]
  end
  ui.text("If the FPS drops significantly, uncheck DOF.")
  ui.text("")
  ui.setNextItemWidth(250)
  value, changed = ui.slider('camera roll: ', cameraSetting["roll"], -45, 45,'%.0f')
  if changed then cameraSetting["roll"] = value end    
  
  ui.text("")

  ui.setNextItemWidth(200)
  angleType, result = ui.combo("Select Camera Angle",angleType,  titles )
  if result then 
    rotation = false
  end

  ui.text("")

  if cameraSetting[titles[angleType]]["fov"] ~=nil then
    ui.setNextItemWidth(250)
    value, changed = ui.slider('FOV', cameraSetting[titles[angleType]]["fov"], 10, 100,'%.1f')
    if changed then cameraSetting[titles[angleType]]["fov"] = value end    
  end
  if cameraSetting[titles[angleType]]["exp"] ~=nil then
    ui.setNextItemWidth(250)
    value, changed = ui.slider('Exposure', cameraSetting[titles[angleType]]["exp"], 0.1, 1,'%.1f')
    if changed then cameraSetting[titles[angleType]]["exp"] = value end    
  end
  if cameraSetting[titles[angleType]]["dof"] ~=nil then
    ui.setNextItemWidth(250)
    value, changed = ui.slider('DOF', cameraSetting[titles[angleType]]["dof"], 0, 20,'%.1f')
    if changed then cameraSetting[titles[angleType]]["dof"] = value end    
  end
  if cameraSetting[titles[angleType]]["shake"] ~=nil then
    ui.setNextItemWidth(250)
    value, changed = ui.slider('shake power.', cameraSetting[titles[angleType]]["shake"], 0, 2,'%.1f')
    if changed then cameraSetting[titles[angleType]]["shake"] = value end    
  end
  if cameraSetting[titles[angleType]]["time"] ~=nil then
    ui.setNextItemWidth(250)
    value, changed = ui.slider('play sec.', cameraSetting[titles[angleType]]["time"], 1, 15,'%.0f')
    if changed then cameraSetting[titles[angleType]]["time"] = value end    
  end
end

function numPadSetting()
  ui.text("")

  local i, result
  if ui.button("SAVE") then
    saveNumPadKey(__dirname .. "\\numPadKey.json")
  end
  ui.sameLine()
  if ui.button("SAVE AS") then
    os.saveFileDialog({
      title = "save preset", 
      folder = __dirname .. "\\numpad",
      defaultExtension = "json",
      fileName = "numPadKey.json",
      fileTypes = {{name = "json file", mask = "*.json"}},
      addAllFilesFileType =false,
      },
      function(err, filename)
        saveNumPadKey(filename)
      end
    )
  end

  ui.sameLine()

  if ui.button("LOAD") then
    os.openFileDialog({
      title = "select preset", 
      folder = __dirname .. "\\numpad",
      fileTypes = {{name = "json file", mask = "*.json"}},
      addAllFilesFileType =false,
      },
      function(err, filename)
        if io.fileExists(filename) then
          loadNumPadKey(filename)
        end
      end
    )
  end

  ui.text("---------------------")
  ui.text("Preset Rotation ON: Enter Key.")

  for i = 1, 10 do
    ui.setNextItemWidth(250)
    numPadKey[i], result = ui.combo("Num Pad" .. i - 1 ,numPadKey[i],  titles )
  end    
end

--/////////////////////
--   Random generation
--////////////////////////




function copyAnglesList()

	for i=1, #titles do
		--ac.debug('i value', i)
		--rndList[i] = titles[i]
		rndList[i] = i
		--ac.debug('rndList[i]', rndList[i])
		--ac.debug('rndList size', #rndList)

	end
--	ac.debug('rndList size', #rndList)
end




function returnRandomAngleNumber( aList)

	local rndAngleNumber
	local rndNumber

	ac.debug('999 aList size', #aList)
-- if list is not empty
	if #aList ~= 0 then
		
		rndNumber = math.random(1, #aList)   -- produce a random number between 1 and the max size of aList
		rndAngleNumber = aList [rndNumber]   -- get the angleNumber from aList using rndNumber as the index
		table.remove(aList, rndNumber)  -- remove the rndNumber index already used, from aList (shrink it)
-- list is empty; otherwise rebuild the list
	else
		copyAnglesList()
		rndNumber = math.random(1, #aList)   -- produce a random number between 1 and the max size of aList
		rndAngleNumber = aList [rndNumber]   -- get the angleNumber from aList using rndNumber as the index
		table.remove(aList, rndNumber)  -- remove the rndNumber index already used, from aList (shrink it)
	end

	return rndAngleNumber
end

