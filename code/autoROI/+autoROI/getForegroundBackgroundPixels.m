function imStats = getForegroundBackgroundPixels(im,pixelSize,borderPixSize,tThresh,BW)
    % Get forground and background pixels from image 
    %
    % function imStats = getForeGroundBackGroundPixels(im,pixelSize,borderPix,tThresh)
    %
    % Purpose
    % Called by autoROI in order to help calculate 
    % the image SNR based on foreground and background pixels.
    %
    %
    % Inputs
    % im - image to analyse
    % thresh - threshold between sample and no sample. can be missing
    % borderpPix - number of pixels from border to user for background calc.
    % tThresh - Threshold for tissue/no tissue. By default this is auto-calculated
    %
    % Inputs (optional)
    % BW - A binary mask where 1s are foreground (sample) pixels. If missing, this is 
    %      calculated from im using binarizeImage.
    %
    %
    % Outputs
    % pixels - A structure containing fields foregroundPix and backgroundPix, which are
    %          vectors of pixel values.
    %
    %
    % Rob Campbell - SWC 2020

    if nargin<5 || isempty(BW)
        %Get the binary image again so it includes all tissue above the threshold
        BW = autoROI.binarizeImage(im,pixelSize,tThresh); 
    end

    verbose=false;

    % Get foreground pixels and their stats
    foregroundPix = im(find(BW));
    imStats.foregroundPix = foregroundPix';


    % Get background pixels. We treat as the background only pixels around the border 
    % of the ROI which don't have tissue in them. The presence of tissue is determined 
    % by the BW mask and the threshold. 

    inverseBW = ~BW; %Pixels outside of the sample
    % Set all pixels further in than borderPix to zero (assume they contain sample anyway)
    b = borderPixSize;
    inverseBW(b+1:end-b,b+1:end-b)=0;
    backgroundPix = im(find(inverseBW));

    % If no more than 25% of of the pixels in the border are above the threshold, we delete them. 
    % This is an unvalidated attempt to remove tissue that was not picked up by the binarization.
    f=find(backgroundPix>=tThresh);
    if length(f)<length(backgroundPix)*0.25
        backgroundPix(f)=[]; %Also get rid of any pixels that happen to be above threshold
    end
    imStats.backgroundPix = backgroundPix';


    % The BakingTray dummyScanner marked pixels that were outside of the original imaged area by assigning 
    % them the value -42. We remove these here. This is only important for analysing test data. During a live
    % acquisition this should happen.
    fB=find(imStats.backgroundPix == -42);
    fF=find(imStats.foregroundPix == -42);
    if ~isempty(fB) || ~isempty(fF)
        if verbose
            fprintf('autoROI.getForeGroundBackGroundPixels finds %d non-imaged test pixels from BakingTray dummyScanner. Removing them.\n', ...
                sum(length(fB) + length(fF)) )
        end

        % Generate warning messages if there are no pixels left. 
        if length(fB) == length(imStats.backgroundPix)
            fprintf('All background pixels are being removed. BAD!\n')
        end
        if length(fF) == length(imStats.foregroundPix)
            fprintf('All background pixels are being removed. BAD!\n')
        end
        imStats.backgroundPix(fB) = [];
        imStats.foregroundPix(fF) = [];
    end

    % The preview image is constructed with a default value of zero. Remove these if we find them
    % acquisition this should happen.
    fB=find(imStats.backgroundPix == 0);
    fF=find(imStats.foregroundPix == 0);
    if ~isempty(fB) || ~isempty(fF)
        if verbose
            fprintf('*** autoROI.getForeGroundBackGroundPixels finds %d pixels that did not have a tile placed in them. Removing them. ***\n', ...
                sum(length(fB) + length(fF)) )
        end
        % Generate warning messages if there are no pixels left. 
        if length(fB) == length(imStats.backgroundPix)
            fprintf('All background pixels are being removed. BAD!\n')
        end
        if length(fF) == length(imStats.foregroundPix)
            fprintf('All background pixels are being removed. BAD!\n')
        end
        imStats.backgroundPix(fB) = [];
        imStats.foregroundPix(fF) = [];
    end
