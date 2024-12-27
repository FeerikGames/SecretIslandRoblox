local UtilFunctions = {}

function UtilFunctions.Lerp(v0, v1, t)
	return v0 + t * (v1 - v0)
end

function UtilFunctions.LerpInverse(v0, v1, v)
	local range = (v1 - v0)

	if (range == 0) then
		return v0
	end

	return  (v - v0) / range
end

function UtilFunctions.LerpColor(Color1,Color2,Alpha)
	return Color3.new(
		UtilFunctions.Lerp(Color1.R,Color2.R,Alpha),
		UtilFunctions.Lerp(Color1.G,Color2.G,Alpha),
		UtilFunctions.Lerp(Color1.B,Color2.B,Alpha)
	)
end

function UtilFunctions.QuadBezier(t, p0, p1, p2)
	local l1 = UtilFunctions.Lerp(p0, p1, t)
	local l2 = UtilFunctions.Lerp(p1, p2, t)
	local quad = UtilFunctions.Lerp(l1, l2, t)
	return quad
end

function UtilFunctions.Min(v1, v2)
	if v1 < v2 then
		return v1
	end
	return v2
end

function UtilFunctions.Max(v1, v2)
	if v1 > v2 then
		return v1
	end
	return v2
end

function UtilFunctions.Clamp01(v)
	return UtilFunctions.Min(UtilFunctions.Max(v,0 ), 1)
end

function UtilFunctions.Clamp(v, vmin, vmax)
	return UtilFunctions.Min(UtilFunctions.Max(v, vmin), vmax)
end


function UtilFunctions.MinVector3(v1:Vector3, v2:Vector3)
	return Vector3.new(math.min(v1.X,v2.X),math.min(v1.Y,v2.Y),math.min(v1.Z,v2.Z))
end

function UtilFunctions.MaxVector3(v1:Vector3, v2:Vector3)
	return Vector3.new(math.max(v1.X,v2.X),math.max(v1.Y,v2.Y),math.max(v1.Z,v2.Z))
end

function UtilFunctions.ClampVector3(v, vmin, vmax)
	return UtilFunctions.MinVector3(UtilFunctions.MaxVector3(v, vmin), vmax)
end

function UtilFunctions.RepeatClampRadian(v:number)

	if v > math.pi then
		while v > math.pi do
			v -= 2* math.pi
		end
	else
		while v < -math.pi do
			v += 2* math.pi
		end
	end

	return v
end



function UtilFunctions.ShortestRotationCycle(from:number, to:number)
	from = UtilFunctions.RepeatClampRadian(from)
	to = UtilFunctions.RepeatClampRadian(to)


	local to2 = to + 2 * math.pi
	local to3 = to - 2 * math.pi

	local dist1 = math.abs(to - from)
	local dist2 = math.abs(to2 - from)
	local dist3 = math.abs(to3 - from)
	
	local min = to
	local minDist = dist1

	if dist2 < minDist then
		min = to2
		minDist = dist2
	end
	
	if dist3 < minDist then
		min = to3
		minDist = dist3
	end
	

	return from, min
end

function UtilFunctions.RepeatClampRadianVector3(v:Vector3)
	local x = UtilFunctions.RepeatClampRadian(v.X)
	local y = UtilFunctions.RepeatClampRadian(v.Y)
	local z = UtilFunctions.RepeatClampRadian(v.Z)

	return Vector3.new(x,y,z)
end

function UtilFunctions.ShortestRotationCycleVector3(from:Vector3, to:Vector3)
	from = UtilFunctions.RepeatClampRadianVector3(from)
	to = UtilFunctions.RepeatClampRadianVector3(to)

	local fromX, toX = UtilFunctions.ShortestRotationCycle(from.X, to.X )
	local fromY, toY = UtilFunctions.ShortestRotationCycle(from.Y, to.Y )
	local fromZ, toZ = UtilFunctions.ShortestRotationCycle(from.Z, to.Z )

	from = Vector3.new(fromX,fromY,fromZ)
	to = Vector3.new(toX,toY,toZ)

	return from, to
end


-- TODO lerp with missing value point
-- 
-- resolve a curve/dopsheet by a given key an return interpolated value
-- 
-- param points : an array with the interpolation keys in first position followed by n values
-- param keyValue : the key value to use in the interpolation
-- return a array with keycount-1 entries
function UtilFunctions.CurveResolve(points, keyValue)
	local pointsCount = #points

	if  pointsCount % 2 ~= 0 then  
		error("Invalid points count")
	end

	local keysCount = pointsCount / 2

	if pointsCount < keysCount * 2 then  
		error("no enought points to lerp")
	end

	local interpolationIndex = 1
	local nextInterpolationIndex = interpolationIndex + keysCount

	local keyRefA = points[interpolationIndex]
	local keyRefB = points[nextInterpolationIndex]

	if keyRefA == nil or keyRefB == nil then
		error("Invalid key value, cannot be nil")
	end

	while keyValue > keyRefB and nextInterpolationIndex <= keysCount do
		interpolationIndex += 2 -- jump key per key
		nextInterpolationIndex = interpolationIndex + keysCount

		keyRefA = points[interpolationIndex]
		keyRefB = points[nextInterpolationIndex]

		if keyRefA == nil or keyRefB == nil then
			error("Invalid key value, cannot be nil")
		end
	end

	local interpolationProgress = (keyValue - keyRefA) / (keyRefB - keyRefA)

	local valueRefA = points[interpolationIndex+1]
	local valueRefB = points[nextInterpolationIndex+1]

	return valueRefA + interpolationProgress * (valueRefB - valueRefA)    
end

-- TODO lerp with missing value point
-- 
-- resolve a curve/dopsheet by a given key an return interpolated value
-- 
-- param points : an array with the interpolation keys in first position followed by n values
-- param chunkSize : the chunk size. key included (minimum 2) 
-- param keyValue : the key value to use in the interpolation
-- return a array with chunkSize-1 entries
function UtilFunctions.CurveResolveMuliValue(points, chunkSize, keyValue)
	local pointsCount = #points

	if  pointsCount % chunkSize ~= 0 then  
		error("Invalid points count")
	end

	local keysCount = pointsCount / chunkSize

	if pointsCount < keysCount * 2 then  
		error("no enought points to lerp")
	end

	local interpolationIndex = 1
	local nextInterpolationIndex = interpolationIndex + keysCount

	local keyRefA = points[interpolationIndex]
	local keyRefB = points[nextInterpolationIndex]

	if keyRefA == nil or keyRefB == nil then
		error("Invalid key value, cannot be nil")
	end

	while keyValue > keyRefB and nextInterpolationIndex <= keysCount do
		interpolationIndex += chunkSize -- jump key per key
		nextInterpolationIndex = interpolationIndex + keysCount

		keyRefA = points[interpolationIndex]
		keyRefB = points[nextInterpolationIndex]

		if keyRefA == nil or keyRefB == nil then
			error("Invalid key value, cannot be nil")
		end
	end

	local interpolationProgress = (keyValue - keyRefA) / (keyRefB - keyRefA)
	local interpolatedPoints = {}

	for i=1,chunkSize-1 do
		local valueRefA = points[interpolationIndex+i]
		local valueRefB = points[nextInterpolationIndex+i]

		interpolatedPoints[i] = valueRefA + interpolationProgress * (valueRefB - valueRefA)
	end

	return interpolatedPoints
end

-- From Unity3D
function UtilFunctions.SmoothDamp(current, target, currentVelocity,  smoothTime,  maxSpeed, deltaTime)

	-- Based on Game Programming Gems 4 Chapter 1.10
	smoothTime = UtilFunctions.Max(0.0001, smoothTime)
	local omega = 2 / smoothTime

	local x = omega * deltaTime
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
	local change = current - target
	local originalTo = target

	-- Clamp maximum speed
	local maxChange = maxSpeed * smoothTime
	change = UtilFunctions.Clamp(change, -maxChange, maxChange)
	target = current - change;

	local temp = (currentVelocity + omega * change) * deltaTime;
	currentVelocity = (currentVelocity - omega * temp) * exp;
	local output = target + (change + temp) * exp;

	-- Prevent overshooting
	if ((originalTo - current) > 0) == (output > originalTo) then
		output = originalTo;
		currentVelocity = (output - originalTo) / deltaTime;
	end

	return output, currentVelocity
end

function UtilFunctions.SmoothDampVector3(  current:Vector3,   target:Vector3,  currentVelocity:Vector3,   smoothTime:number,   maxSpeed:number,    deltaTime:number)

	local output_x = 0;
	local output_y = 0;
	local output_z = 0;

	-- Based on Game Programming Gems 4 Chapter 1.10
	smoothTime = math.max(0.0001, smoothTime);
	local omega = 2 / smoothTime;

	local x = omega * deltaTime;
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);

	local change_x = current.X - target.X;
	local change_y = current.Y - target.Y;
	local change_z = current.Z - target.Z;
	local originalTo:Vector3 = target;

	-- Clamp maximum speed
	local maxChange = maxSpeed * smoothTime;

	local maxChangeSq = maxChange * maxChange;
	local sqrmag = change_x * change_x + change_y * change_y + change_z * change_z;

	if sqrmag > maxChangeSq then

		local mag = math.sqrt(sqrmag)
		change_x = change_x / mag * maxChange;
		change_y = change_y / mag * maxChange;
		change_z = change_z / mag * maxChange;
	end

	target = Vector3.new(current.X - change_x, current.Y - change_y , current.Z - change_z)

	local temp_x = (currentVelocity.X + omega * change_x) * deltaTime;
	local temp_y = (currentVelocity.Y + omega * change_y) * deltaTime;
	local temp_z = (currentVelocity.Z + omega * change_z) * deltaTime;

	currentVelocity = Vector3.new((currentVelocity.X - omega * temp_x) * exp, (currentVelocity.Y - omega * temp_y) * exp , (currentVelocity.Z - omega * temp_z) * exp)

	output_x = target.X + (change_x + temp_x) * exp;
	output_y = target.Y + (change_y + temp_y) * exp;
	output_z = target.Z + (change_z + temp_z) * exp;

	-- Prevent overshooting
	local origMinusCurrent_x = originalTo.X - current.X;
	local origMinusCurrent_y = originalTo.Y - current.Y;
	local origMinusCurrent_z = originalTo.Z - current.Z;
	local outMinusOrig_x = output_x - originalTo.X;
	local outMinusOrig_y = output_y - originalTo.Y;
	local outMinusOrig_z = output_z - originalTo.Z;

	if origMinusCurrent_x * outMinusOrig_x + origMinusCurrent_y * outMinusOrig_y + origMinusCurrent_z * outMinusOrig_z > 0 then

		output_x = originalTo.X;
		output_y = originalTo.Y;
		output_z = originalTo.Z;

		currentVelocity = Vector3.new((output_x - originalTo.X) / deltaTime, (output_y - originalTo.Y) / deltaTime, (output_z - originalTo.Z) / deltaTime)
	end

	return   Vector3.new(output_x, output_y, output_z), currentVelocity
end

function UtilFunctions.evalNS(ns:NumberSequence, time:number)
	time = UtilFunctions.Clamp(time,0,1)
	-- If we are at 0 or 1, return the first or last value respectively
	if time == 0 then return ns.Keypoints[1].Value end
	if time == 1 then return ns.Keypoints[#ns.Keypoints].Value end
	-- Step through each sequential pair of keypoints and see if alpha
	-- lies between the points' time values.
	for i = 1, #ns.Keypoints - 1 do
		local this = ns.Keypoints[i]
		local next = ns.Keypoints[i + 1]
		if time >= this.Time and time < next.Time then
			-- Calculate how far alpha lies between the points
			local alpha = (time - this.Time) / (next.Time - this.Time)
			-- Evaluate the real value between the points using alpha
			return (next.Value - this.Value) * alpha + this.Value
		end
	end
end

function UtilFunctions.NumberSequenceResolve(numberSequence:NumberSequence, keyRange:NumberRange, valueRange:NumberRange,  keyValue:number)
	
	local progress = UtilFunctions.LerpInverse(keyRange.Min, keyRange.Max, keyValue)
	
	local value = UtilFunctions.evalNS(numberSequence, progress) 
	local finalValue = UtilFunctions.Lerp(valueRange.Min, valueRange.Max, value)

	return finalValue
end


function UtilFunctions.NumberSequenceResolveVector3(numberSequenceX:NumberSequence, numberSequenceY:NumberSequence, numberSequenceZ:NumberSequence, keyRange:NumberRange, valueRange:NumberRange,  keyValue:number)
	
	local finalValueX = UtilFunctions.NumberSequenceResolve(numberSequenceX, keyRange, valueRange, keyValue)
	local finalValueY = UtilFunctions.NumberSequenceResolve(numberSequenceY, keyRange, valueRange, keyValue)
	local finalValueZ = UtilFunctions.NumberSequenceResolve(numberSequenceZ, keyRange, valueRange, keyValue)

	return Vector3.new(finalValueX,finalValueY,finalValueZ)
end

return UtilFunctions