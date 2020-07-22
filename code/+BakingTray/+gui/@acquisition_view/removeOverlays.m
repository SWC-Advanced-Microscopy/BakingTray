function removeOverlays(obj,overlayToRemove)
    % Remove overlaid line plot data from the preview image
    %
    % function removeOverlays(obj,overlayToRemove)
    %
    % Purpose
    % The preview image could have overlaid line plot data, such as tile locations
    % or bounding boxes. The handles for these are stored in the structure 
    % obj.plotOverlayHandles, which could contain a number of different things. 
    % e.g. brain borders, tile positions, etc. This convenience method looks them
    % up by name and deletes: both removing data from the plot and also the 
    % associated field from the structure.
    %
    %
    % Inputs
    % If no inputs are provided, this function deletes *all* plot handles and removes
    % all fields from the plotOverlayHandles structure.Alternatively, if 
    % overlayToRemove is a string then all overlays associated with that field name 
    % are removed.
    %
    % e.g. After running overlayTileGridOnImage, we can do: obj.removeOverlays('tileGrid') 
    % to remove all plot elements assocaited with the tile grid. These were stored in:
    % obj.plotOverlayHandles.tileGrid
    %
    %
    % See also:
    % obj.overlayTileGridOnImage
    % obj.overlayBoundingBoxesOnImage
    % obj.overlayPointsOnImage


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

end %removeOverlays
