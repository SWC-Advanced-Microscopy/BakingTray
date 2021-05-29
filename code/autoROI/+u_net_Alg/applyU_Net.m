function OUT = applyU_Net(im,tNet,pixSize,nonImagedPixVal)
    % Apply U-Net to image to find sample
    %
    % Inputs
    % im - preview image. one plane
    % tNet - structure containing trained U-net and some settings
    % pixSize - number of microns per pixel of im
    % nonImagedPixVal - value of background (non-imaged pixels) that we want to exclude
    %                   from any calculations. If empty or missing we don't do this. 
    % Outputs
    % 


    % Medfilt really helps avoid classifiying small bright things as tissue
    im  = single(im);
    mFilt=7;
    im = medfilt2(im,[mFilt,mFilt]); 

    %up-sample if the image is too small in either dimension
    minSize = tNet.Layers(1).InputSize(1:2);

    if any( (size(im) - minSize)<1 )
        im = imresize(im,minSize);
    end


    % Make histo and subtract peak value (which is roughly the offset)
    [n,x]=hist(im(:),1000);
    peakValue = x(n==max(n));
    im = im - peakValue;


    % Spread out signal if it's dim
    maxVal = 750;
    if max(im(:))<maxVal
        tScale = maxVal/max(im(:));
        CAP = 15;
        if tScale>CAP
            fprintf('Capping at %d\n',CAP)
            tScale=CAP;
        end
        fprintf('Signal under %d. Multiplying it by %0.1f\n',maxVal,tScale)
        
        im = im*tScale;
    end

    [n,x]=hist(im(:),1000);

    % Run the classifier
    C = semanticseg(im,tNet);

    BW = C=='brain';
    BW = imresize(BW,size(im),'nearest'); %Because after seg it can be smaller
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
    end

