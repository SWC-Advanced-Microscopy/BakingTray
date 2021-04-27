function OUT = applyCNN(im,tNet,pixSize)
    % Apply CNN to image to find sample
    %
    % Inputs
    % im - preview image. one plane
    % tNet - structure containing CNN network and some settings
    % pixSize - number of microns per pixel of im
    %
    % Outputs
    %


    if tNet.settings.doNorm
        im = im-mean(im(:));
    end

    
    pixWidth = floor(tNet.settings.chunkWidth / pixSize);

    imS = size(im);


    % Dim 1 (rows)
    numSteps = round(imS(1) / pixWidth);
    rSteps = round(linspace(1,imS(1),numSteps));

    % Dim 2 (cols)
    numSteps = round(imS(2) / pixWidth);
    cSteps = round(linspace(1,imS(2),numSteps));

    % Chunk it up
    chunks = ones(rSteps(2),cSteps(2),(length(rSteps)-1)*(length(cSteps)-1));
    chunkSize = [rSteps(2),cSteps(2)];

    n=1;
    containsTissue = zeros(size(chunks,3),1,'logical');
    coords = zeros(size(chunks,3),2);
    chunkPosInGrid = coords;

    for ii=1:length(rSteps)-1
        for jj=1:length(cSteps)-1
            tRows = rSteps(ii):rSteps(ii+1);
            tCols = cSteps(jj):cSteps(jj+1);


            coords(n,1) = tRows(1)+pixWidth/2;
            coords(n,2) = tCols(1)+pixWidth/2;

            chunkPosInGrid(n,:) = [ii,jj];

            tChunk = im(tRows,tCols);
            chunks(:,:,n) = imresize(tChunk,chunkSize);

            n=n+1;

        end
    end



    % Clasify
    targetChunkSize = tNet.net.Layers(1).InputSize(1:2);
    chunks = imresize(chunks,targetChunkSize);


    containsTissue=classify(tNet.net,permute(chunks,[1,2,4,3]));

    % Build a binary mask showing where there is tissue. 
    binGrid = zeros(max(chunkPosInGrid));
    ind = find(containsTissue == 'true');

    f = sub2ind(size(binGrid), chunkPosInGrid(ind,1), chunkPosInGrid(ind,2) );
    binGrid(f)=1;


    binGrid = imfill(binGrid);
    binGrid = imresize(binGrid,size(im),'nearest');
    OUT.rawBW = logical(binGrid);

    se=strel('disk',20);
    OUT.FINAL = imclose( imopen(OUT.rawBW,se), se);


    stats.chunks = chunks;
    stats.chunkWidth = tNet.settings.chunkWidth;
    stats.pixWidth = pixWidth;
    stats.voxelSizeInMicrons = pixSize;


