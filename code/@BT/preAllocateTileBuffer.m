function preAllocateTileBuffer(obj)
    % pre-allocate the tile buffer array based upon the current scan settings
    %
    % BT.preAllocateTileBuffer(obj)
    %
    % Purpose
    % The tile buffer in BT.downSampledTileBuffer holds all images acquired at the last 
    % X/Y position. i.e. all depths and all channels. The data in this buffer are
    % downsampled versions on the raw data. The degree to which they have been downsampled
    % determined by BT.downsampleImageSize, which is a scalar defining how many pixels 
    % on a side the square downsampled tile will contain. These downsampled tiles are used 
    % build a live preview image. They can also be used for tasks like adaptive scanning,
    % to scan only the specimen. 


    scnSet = obj.scanner.returnScanSettings;
    maxChans = obj.scanner.maxChannelsAvailable;
    numPlanes = obj.recipe.mosaic.numOpticalPlanes;

    %calculate the number of lines per frame (in case of rectangular frames)
    downsampleRatio = obj.downsampleMicronsPerPixel / scnSet.micronsPerPixel_rows;

    obj.downSampledTileBuffer = zeros(...
        round(scnSet.linesPerFrame * downsampleRatio), ...
        round(scnSet.pixelsPerLine * downsampleRatio), ...
        numPlanes, ...
        maxChans, ...
        'int16');


    fprintf('Pre-allocated tile buffer to %d x %d %d x %d\n', size(obj.downSampledTileBuffer))
