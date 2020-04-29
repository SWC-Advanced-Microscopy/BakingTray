function removeOverlays(obj,overlayToRemove)
    % Remove overlaid line plot data from preview image
    % 
    % function removeOverlays(obj,overlayToRemove)
    %
    % Purpose
    % The preview image could have overlaid line plot data. The handles
    % for these are stored in the structure obj.plotOverlayHandles, which 
    % could contain a number of different things. e.f. brain borders, tile positions,
    % etc. 
    %
    % Inputs
    % If no inputs are provided, this function deletes all plot handles.
    % Alternatively, if overlayToRemove is a string then all overlays 
    % associated with that field name are removed.
    %
    % e.g. removeOverlays('tileGrid') will remove plot elements stored in 
    % obj.plotOverlayHandles.tileGrid
    %

    if isempty(obj.plotOverlayHandles)
        return
    end

    if nargin<2
        overlayToRemove=[];
    end

    f=fields(obj.plotOverlayHandles);
    for ii=1:length(f)
        % Skip if the user provided an overlay name and this does not match
        if ~isempty(overlayToRemove) && ~strcmp(f{ii},overlayToRemove)
            continue
        end
        delete(obj.plotOverlayHandles.(f{ii}))
        obj.plotOverlayHandles = rmfield(obj.plotOverlayHandles,(f{ii}));
    end

end
