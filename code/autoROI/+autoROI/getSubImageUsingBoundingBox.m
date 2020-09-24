function subIm = getSubImageUsingBoundingBox(im,BoundingBox,maintainSize,padValue)
    % Pull out a sub-region of the image based on a bounding box.
    %
    % function subIm = autoROI.getSubImageUsingBoundingBox(im,BoundingBox,maintainSize,padValue)
    %
    %
    % Inputs
    % im - 2d image from which we will extract a sub-region
    % BoundingBox - in the form: [left corner pos, bottom corner pos, width, height]
    % maintainSize - false by default. If true, the output (subIM), is the same size as im
    %                but all pixels outside BoundingBox are zero. i.e. it's padded with
    %                zeros. 
    % padValue - The value to use for padding the image if maintainSize is true. The 
    %            default is zero. For images with negative values, we might want to 
    %            use a different value, so that the binarization works.
    %
    %
    % Outputs
    % subIm - the sub-image as a 2D matrix
    %
    % 
    % Rob Campbell - SWC 2020


    if nargin<3 || isempty(maintainSize)
        maintainSize=false;
    end

    if nargin<4
        padValue=0;
    end

    BoundingBox = autoROI.validateBoundingBox(BoundingBox,size(im));

    subIm = im(BoundingBox(2):BoundingBox(2)+BoundingBox(4), ...
               BoundingBox(1):BoundingBox(1)+BoundingBox(3));


    % If maintainSize is true, we pad the image with so that it mataches
    % the orignal size of im. The padding value can optionally be a non-zero
    % value, which is used by autoROI to handle images with negative numbers.
    if maintainSize
        tmp=zeros(size(im))+padValue;
        tmp(BoundingBox(2):BoundingBox(2)+BoundingBox(4), ...
            BoundingBox(1):BoundingBox(1)+BoundingBox(3)) = subIm;
        subIm =tmp;
    end

