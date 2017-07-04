function logPositionToPositionArray(obj)
	% Log the current X/Y position to the position array matrix
    %
    % function logPositionToPositionArray(obj)
    %
    % Purpose
	% This is used during acquisition to keep track of the actual
	% stage position before each tile was acquired


	if isempty(obj.currentSectionNumber)
		obj.logMessage(inputname(1),dbstack,6,'no current section number defined. Can not log position to array')
		return
	end

    [x,y]=obj.getXYpos;
    obj.positionArray(obj.currentTilePosition,5)=x;
    obj.positionArray(obj.currentTilePosition,6)=y;
  
  