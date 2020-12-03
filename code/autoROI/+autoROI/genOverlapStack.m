function overlapStack = genOverlapStack(BoundingBoxes,imSize)
    % Generate a binary image stack where each plane contains a separate ROI
    %
    % function overlapStack = autoROI.genOverlapStack(BoundingBoxes,imSize)
    %
    % Purpose
    % Used to evalue whether there are overlapping ROIs and if so by how much. 
    % See autoROI.mergeOverlapping
    %
    % Inputs
    % BoundingBoxes - a cell array of bounding boxes
    % imSize - x/y size of each frame. 
    %
    % Outputs
    % overlapStack - Binary image of size [imSize,length(BoundingBoxes)] Each plane is one
    %               bounding box. Ones are within the area and zeros outside.



    overlapStack = zeros([imSize,length(BoundingBoxes)]);

    % Fill in the blank "image" with the areas that are ROIs
    for ii=1:length(BoundingBoxes)
        tB = BoundingBoxes{ii};
        eb = autoROI.validateBoundingBox(tB, imSize);
        overlapStack(eb(2):eb(2)+eb(4), eb(1):eb(1)+eb(3),ii) = 1;
    end

    % Just in case, delete any planes which happen to empty
    sP = squeeze(sum(overlapStack,[1,2]));
    overlapStack(:,:,sP==0) = [];
