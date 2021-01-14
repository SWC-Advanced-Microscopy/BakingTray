function [im,stats] = removeBrightBlocks(im,settings)
    % Removes the brightest portions of an image
    %
    % function [im,stats] = autoROI.removeBrightBlocks(im,settings)
    %
    % Purpose
    % This removes the brightest regions of an image by dividing it up
    % into squares of a given size, calculating the mean pixel value
    % in each square, then removing all pixels that fall into the
    % brightest squares. This is called by autoROI.obtainCleanBackgroundSD
    %
    % Inputs
    % im - a 2d image
    % settings - optional. The output of autoROI.readSettings
    %
    % Outputs
    % im - the image with bright pixels set to zero
    % stats - more info to be used for debugging and logging
    %
    % Rob Campbell - SWC 2021



    if nargin<2
        settings = autoROI.readSettings;
    end


    % The block size is the size of the squares into which we will breakdown the image
    blockSize = 350; % TODO -- incorporate into settings
    pixSize = settings.main.rescaleTo;

    resizeBy = pixSize/blockSize;
    targetSize = round(size(im)*resizeBy);
    imR = imresize(im, targetSize ,'nearest');


    %Get rid of the brightest patches
    t = sort(imR(:),'ascend');

    % Remove blocks that contain only non-imaged pixels. This can happen
    % because we will be feeding this function images where only some 
    % regions have been imaged. Non-imaged regions will be zero. Regions
    % outside of the intended FOV will be -42.
    t(t==0)=[]; 
    t(t==-42)=[]; 

    % keepProp defines the proportion of the lowest values to keep. If this is
    % 0.25, for instance, the dimmest 25% of blocks are kept. 

    % If we have imaged more than 20 sqmm we get rid of the dimmest 10% of blocks
    totalSqmm = length(t) * blockSize * 1E-3;

    if totalSqmm>30
        getRid = round(length(t)*0.1);
        t(1:getRid)=[];
    end

    thresh = t(round(length(t)*settings.autoThresh.keepProp));

    % Make a matrix of zeros and ones defining which sqiares to keep and
    % then resize it to match the original image size.
    maskMatrix = imresize(imR<=thresh,size(im),'nearest');
    maskMatrix = cast(maskMatrix,class(im));


    % Mask out the bright pixels
    im = im .* maskMatrix;

    if nargout>1
        stats.imR = imR;
    end
end
