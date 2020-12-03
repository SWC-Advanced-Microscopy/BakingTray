function overlayTileGrid(pStack,ind)
    % Determines where tile borders ought to be and overlays a grid at these locations
    %
    % function autoROI.plotting.overlayTileGrid(pStack,ind)
    %
    % Purpose
    % To check that we are calculating the tile size and tile borders properly,
    % this function takes as input a pStack, plots a section, and overlays the 
    % tile borders.
    %
    % Inputs
    % pStack - the preview stack structure
    % ind - which slice to plot. If missing, it plots a slice 1/3 of the way into 
    %       the stack.
    %
    % Outputs
    % none


    % Plot a plane 1/3 of the way in by default
    if nargin<2
        ind = round(size(pStack.imStack,3)*0.33);
    end

    if ind > size(pStack.imStack,3)
        fprintf('You asked for plane %d but there are only %d planes\n', ...
            ind, size(pStack.imStack,3))
        return
    end

    verbose = true;


    % Move stages to the middle of the sample area so we are more likely to see something if we take an image
    im_mmY = size(pStack.imStack,2) * pStack.voxelSizeInMicrons * 1E-3;
    im_mmX = size(pStack.imStack,1) * pStack.voxelSizeInMicrons * 1E-3;

    if verbose
        fprintf('Image is %0.2f by %0.2f mm\n', im_mmX, im_mmY)
    end


    % Set the sample size to something reasonable based on the area of the sample
    obj.scannerSettings.FOV_alongColsinMicrons=pStack.tileSizeInMicrons;
    obj.scannerSettings.FOV_alongRowsinMicrons=pStack.tileSizeInMicrons;


    pixelsPerLine=round(pStack.tileSizeInMicrons / pStack.voxelSizeInMicrons);


    % Calculate the number of tiles in X and Y using the un-padded (original data)
    overlap = pStack.recipe.mosaic.overlapProportion;
    tilesY = size(pStack.imStack,1) / (pixelsPerLine*(1-overlap));
    tilesX = size(pStack.imStack,2) / (pixelsPerLine*(1-overlap));

    tilesY = floor(tilesY);
    tilesX = floor(tilesX);

    if verbose
        fprintf('Image is covered using %d by %d tiles\n', tilesX, tilesY)
        fprintf('Tiles are %d pixels (%0.2f mm) on a side\n', ...
         pixelsPerLine, pixelsPerLine*pStack.voxelSizeInMicrons * 1E-3)
    end


    figure(1923)
    clf
    tPlane = pStack.imStack(:,:,ind);
    imagesc(tPlane)
    caxis([0,4*mean(tPlane(:))])
    colormap gray
    axis equal tight

    hold on
    % Ovelay lines then overlay points at the intersections
    for ii=1:tilesX
        x = pixelsPerLine * ii * (1-overlap);
        plot([x,x],ylim,'--','Color',[1,0,0,0.46])
    end

    for ii=1:tilesY
        y = pixelsPerLine * ii * (1-overlap);
        plot(xlim, [y,y],'--','Color',[1,0,0,0.46])
    end

    for ii=1:tilesX
        y = (1:tilesY) * pixelsPerLine * (1-overlap);
        x = pixelsPerLine * ii * (1-overlap);
        x = repmat(x,length(y),1);
        plot(x,y,'+r','MarkerSize',12)
    end


    hold off

end

