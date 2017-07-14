function logPositionToPositionArray(obj,fakeLog)
	% Log the current X/Y position to the position array matrix
    %
    % function logPositionToPositionArray(obj,fakeLog)
    %
    % Purpose
	% This is used during acquisition to keep track of the actual
	% stage position before each tile was acquired. The data are
    % logged in BT.positionArray. Columns 5 and 6 are the recorded
    % x and y positions respectively. 
    %
    % Inputs
    % if fakeLog is true, just copy the current tile desired position into
    % the actual position. False by default


	if isempty(obj.currentSectionNumber)
		obj.logMessage(inputname(1),dbstack,6,'no current section number defined. Can not log position to array')
		return
	end

    if nargin<2
        fakeLog=false;
    end

    if fakeLog
        obj.positionArray(obj.currentTilePosition,5) = obj.positionArray(obj.currentTilePosition,3);
        obj.positionArray(obj.currentTilePosition,6) = obj.positionArray(obj.currentTilePosition,4);
    else
        [x,y]=obj.getXYpos;
        obj.positionArray(obj.currentTilePosition,5) = x;
        obj.positionArray(obj.currentTilePosition,6) = y;
    end
