function pStack = resizePStack(pStack,micsPixTarget)
    % Change the number of microns per pixel to micsPixTarget
    %
    % function pStack = boundingBoxFromLastSection.tools.resizePStack(pStack,micsPixTarget)
    %
    % Purpose
    % Change the number of microns per pixel in a pStack
    %
    % Inputs
    % pStack - structure to work on
    % micsPixTarget - the number of microns per pixel to resize to 


    % Figure out the new image size
    rescaleBy = pStack.voxelSizeInMicrons / micsPixTarget;

    if rescaleBy >= 1
        fprintf('Not rescaling. Rescale factor is >=1\n')
        return
    end

    newSize = round([size(pStack.imStack,1:2)*rescaleBy, ...
        size(pStack.imStack,3)]);

    % Apply to the imagestack and the binarized data
    fprintf('Resizing images by %0.2f...', rescaleBy);
    pStack.imStack = imresize3(pStack.imStack,newSize);
    pStack.binarized = logical(imresize3(single(pStack.binarized),newSize));
    fprintf('done\n');

    % Rescale the borders
    for ii=1:length(pStack.borders{1})
        thisSection = pStack.borders{1}{ii};

        % Just in case there are borders with no points, we remove them
        emptyInd=find(cellfun(@(x) isempty(x),thisSection));
        thisSection(emptyInd)=[];

        for jj=1:length(thisSection)
            thisROI = round(thisSection{jj} * rescaleBy);

            %Constrain ROIs to the FOV

            % Any zeros should be 1
            f=find(thisROI<1);
            thisROI(f)=1;

            % Now constrain the max values
            f=find(thisROI(:,1)>newSize(1));
            thisROI(f,1)=newSize(1);

            f=find(thisROI(:,2)>newSize(2));
            thisROI(f,2)=newSize(2);

            % Replace the ROI
            thisSection{jj} = thisROI;
        end
        pStack.borders{1}{ii} = thisSection;
    end

    % Replace the pixel size
    pStack.voxelSizeInMicrons = micsPixTarget;