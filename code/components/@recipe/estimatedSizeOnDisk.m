function estimatedSizeInGB = estimatedSizeOnDisk(obj,numTiles)
    % recipe.estimatedSizeOnDisk(numTiles)
    %
    % Return the estimated size of of the acquisition on disk in gigabytes
    %
    % Inputs
    % numTIles - this optional input defines the number of tiles the system
    %            will acquire per optical plane. It is used to avoid this
    %            method needing to call the NumTiles class, which can be slow. 
    %            numTiles is calculated from the current scan settings if it's 
    %            missing.


    if ~obj.parent.isScannerConnected
        fprintf('No scanner connected. Can not estimate size on disk\n')
        estimatedSize=nan;
        return
    end

    if nargin<2
        N=obj.NumTiles;
        numTiles = N.X * N.Y;
    end


    imagesPerChannel = obj.mosaic.numOpticalPlanes * obj.mosaic.numSections * numTiles;

    scnSet = obj.ScannerSettings;
    totalImages = imagesPerChannel * length(scnSet.activeChannels);

    totalBytes = totalImages * scnSet.pixelsPerLine * scnSet.linesPerFrame * 2; %2 bytes per pixel (16 bit)

    totalBytes = totalBytes *1.01; % Add 1% for headers and so forth

    estimatedSizeInGB = totalBytes/1024^3;

end % estimatedSizeOnDisk
