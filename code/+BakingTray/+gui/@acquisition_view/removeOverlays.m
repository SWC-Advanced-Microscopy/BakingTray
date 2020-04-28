function removeOverlays(obj)
    % Remove image ALL overlays

    if isempty(obj.plotOverlayHandles)
        return
    end

    f=fields(obj.plotOverlayHandles);
    for ii=1:length(f)
        delete(obj.plotOverlayHandles.(f{ii}))
        obj.plotOverlayHandles = rmfield(obj.plotOverlayHandles,(f{ii}));
    end

    
end