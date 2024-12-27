local SpatialUtils = {}

function SpatialUtils.IsPositionInPart(Position,Part,PositionMultiplier : Vector3)
	local RelPosition = Part.CFrame:PointToObjectSpace(Position) * (PositionMultiplier or Vector3.new(1,1,1))
	if math.abs(RelPosition.X) <= Part.Size.X/2 and math.abs(RelPosition.Y) <= Part.Size.Y/2 and math.abs(RelPosition.Z) <= Part.Size.Z/2 then
		return true
	end
	return false
end

return SpatialUtils