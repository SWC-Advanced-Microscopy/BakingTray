function im = placeImageInBlankFrame(im,offset,imSize)
% Place image im as a sub-image in a larger area
%
% function im = placeImageInBlankFrame(im,offset,imSize)
%
%
% Purpose
% Create a blank image of size imSize and place a smaller image, im, within it
% at the offset location defined by the vector offset. 
%
% Inputs
% im - 2D image
% offset - 1 by 2 vector defining image offset
% imSize - 1 by 2 vector defining final image size
% NOTE - For convenience if the two vectors are longer than 2, they are clipped. 
%
% Outputs
% im - output image 
%
% Example
% p = peaks(100);
% pt = autoROI.placeImageInBlankFrame(p,[45,145],[400,400]);

offset = offset(1:2);
imSize = imSize(1:2);

% Issue a warning if we will see clipping
if (size(im,1) + offset(1)) > imSize(1) || ...
    (size(im,2) + offset(2)) > imSize(2)

    fprintf('WARNING: autoROI.%s will clip image during translation\n', mfilename)
end


% Pad existing image to the desired size
backgroundPixValue = 0;
im(imSize(1),imSize(2)) = backgroundPixValue;

% Now translate to the correct offset
im = imtranslate(im, offset(1:2));
