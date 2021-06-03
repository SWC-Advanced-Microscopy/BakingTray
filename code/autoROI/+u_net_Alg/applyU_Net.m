function [OUT,stats] = applyU_Net(im,tNet,plotResults)
    % Apply U-Net to image to find sample
    %
    % Inputs
    % im - preview image. one plane
    % tNet - structure containing trained U-net and some settings
    % pixSize - number of microns per pixel of im
    % nonImagedPixVal - value of background (non-imaged pixels) that we want to exclude
    %                   from any calculations. If empty or missing we don't do this. 
    % Outputs
    % OUT -  structure containing 


    if nargin<3
        plotResults=false;
    end

    origSize = size(im);

    % Subtract offset and scale
    doFinalMedFilt=true;
    [im,stats] = subtractOffset(im,doFinalMedFilt);
    im = scaleImage(im,stats);

    %up-sample if the image is too small in either dimension
    minSize = tNet.Layers(1).InputSize(1:2);
    if any( (size(im) - minSize)<1 )
        im = imresize(im,minSize);
    end

    % Run the classifier
    C = semanticseg(im,tNet);

    BW = C=='brain';
    BW = imresize(BW,origSize,'nearest'); %Because after seg it can be smaller
    BW = logical(BW);
    OUT.rawBW = BW;

    % Filter a little
    s=strel('disk',8);
    BW = imdilate(BW,s);
    BW = imerode(BW,s);
    BW = imfill(BW,'holes'); % Fill the holes


    BW = bwareafilt(BW,[80 inf]);
    OUT.FINAL = BW;

    if all(BW(:)==0)
        fprintf('No sample found by %s!\n', mfilename)
        return
    end


    if plotResults
        imagesc(im)
        axis equal tight
        colormap gray
        colorbar
        b = bwboundaries(BW);
        hold on
        for ii=1:length(b)
            plot(b{ii}(:,2), b{ii}(:,1),'-r')
        end
        hold off
        drawnow
    end

