function [im,pixelSize,origPixelSize] = rescaleAndFilterImage(im,pixelSize)
    % Used to filter and rescale the images. 
    %
    % function [im,pixelSize,origPixelSize] = dynamicThresh_Alg.rescaleAndFilterImage(im,pixelSize)
    %
    % Purpose
    %  Used by autoROI to filter the image. 
    %
    % TODO -- this should be used when thresholding the first image!


    settings = autoROI.readSettings;
    rescaleTo = settings.main.rescaleTo;

    % Remove sharp edges. This helps with artifacts associated with the missing corner tile found in test 
    % Future data do not have this problem, but we keep this correction here because the test data used to
    % develop the autoROI all have this problem.
    im = autoROI.removeCornerEdgeArtifacts(im);
    sizeIm=size(im);

    if rescaleTo>1
        %fprintf('%s is rescaling image to %d mic/pix from %0.2f mic/pix\n', mfilename, rescaleTo, pixelSize);

        sizeIm = round( sizeIm / (rescaleTo/pixelSize) );
        im = imresize(im, sizeIm,'nearest'); %Must use nearest-neighbour to avoid interpolation
        origPixelSize = pixelSize;
        pixelSize = rescaleTo;
    else
        origPixelSize = pixelSize;
    end



    % Median filter the image first. This is necessary, otherwise downstream steps may not work.
    im = medfilt2(im,[settings.main.medFiltRawImage,settings.main.medFiltRawImage]);
    im = single(im);
