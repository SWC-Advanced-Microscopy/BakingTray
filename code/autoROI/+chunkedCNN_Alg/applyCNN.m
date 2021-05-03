function [OUT,stats] = applyCNN(im,tNet,pixSize,nonImagedPixVal)
    % Apply CNN to image to find sample
    %
    % Inputs
    % im - preview image. one plane
    % tNet - structure containing CNN network and some settings
    % pixSize - number of microns per pixel of im
    % nonImagedPixVal - value of background (non-imaged pixels) that we want to exclude
    %                   from any calculations. If empty or missing we don't do this. 
    % Outputs
    %

    if nargin<4
        nonImagedPixVal=[];
    end

    if tNet.settings.doNorm
        tmp = im;
        if ~isempty(nonImagedPixVal)
            tmp(tmp==nonImagedPixVal)=[];
        end
        im = im-mean(tmp(:));
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
    nChunks = size(chunks,3);
    containsTissue = repmat(categorical({'false'}),nChunks,1);
    coords = zeros(nChunks,2);
    chunkPosInGrid = coords;

    numSkippedChunks=0;
    indEmpty = zeros(nChunks,1,'logical'); %If not imaged we set this to 1
    imMode = mode(im(1:2:end));

    for ii=1:length(rSteps)-1
        for jj=1:length(cSteps)-1
            tRows = rSteps(ii):rSteps(ii+1);
            tCols = cSteps(jj):cSteps(jj+1);



            tChunk = im(tRows,tCols);

            coords(n,1) = tRows(1)+pixWidth/2;
            coords(n,2) = tCols(1)+pixWidth/2;

            chunkPosInGrid(n,:) = [ii,jj];


            if all(tChunk(:)==imMode)
                indEmpty(n)=true;
                numSkippedChunks = numSkippedChunks + 1;
            else
                % This is the slow line
                chunks(:,:,n) = imresize(tChunk,chunkSize);
            end

            n=n+1;

        end
    end

    if numSkippedChunks>0
        fprintf('Skipped %d/%d chunks\n', numSkippedChunks, size(coords,1))
    end


    %Remove areas that are not imaged

    % Clasify
    targetChunkSize = tNet.net.Layers(1).InputSize(1:2);
    chunks = imresize(chunks,targetChunkSize);



    f = ~indEmpty;
    chunksForClassifying = permute(chunks,[1,2,4,3]);
    chunksForClassifying = chunksForClassifying(:,:,:,f);
    containsTissue(f)=classify(tNet.net,chunksForClassifying);

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


    % Further optional information
    stats.chunks = chunks;
    stats.chunkWidth = tNet.settings.chunkWidth;
    stats.pixWidth = pixWidth;
    stats.voxelSizeInMicrons = pixSize;
    stats.im = im;


