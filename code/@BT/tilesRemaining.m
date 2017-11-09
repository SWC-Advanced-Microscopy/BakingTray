function n=tilesRemaining(obj)
    % Return the number of tiles remaining in this section
    %
    % n=BT.tilesRemaining
    %
    % KNOWN BUG:
    % This will be innaccurate for the first tile. 
    % Since the stage could move to the first position, the position is 
    % logged, then the acquisition crashes, we report one completed tile. 
    % Not important so we proceed. 

    n=[];
    if isempty(obj.positionArray)
        obj.logMessage(inputname(1),dbstack,6,'no position array. No acquisition running.')
        return
    end

    n = isnan(obj.positionArray(:,end));
    n = sum(n);
