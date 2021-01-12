function [SD,medbg,minThresh,stats] = obtainCleanBackgroundSD(im,settings)
%
% Purpose
% autoROI.getForegroundBackgroundPixels returns as background 
% pixels those which are in the border and were not marked as containing
% tissue in the previous section. 
% However, has happened on very rare occaisions that tissue creeping 
% in de novo in the border region does not get picked up at all and inflates
% the SD of the border. To avoid this we fit a 2-component GMM here and take the 
% SD of the dominant component. 


if isempty(im)
    SD=[];
    medbg=[];
    minThresh=[];
    return
end

if nargin<2
    settings = autoROI.readSettings;
end

method =  'brightest_gmm';

switch method
case 'border_vanilla'
    BG = borderPixGetter(im,settings);
    SD = std(BG);
    medbg = median(BG);
    minThresh=[];
case 'border_gmm'
    BG = borderPixGetter(im,settings);
    SD = gmmSD(BG);
    medbg = median(BG);
    minThresh=[];
case 'whole_gmm'
    [SD,medbg] = gmmSD(im);
    minThresh = medbg + SD*3;
case 'brightest_gmm'
    % Ensure no background pixels play a role in the calculation
    [BG,statsBrightBlocks] = removeBrightBlocks(im,settings);

    BG = BG(:);
    BG(BG == -42) = [];
    BG(BG == 0) = [];

    [SD,medbg,statsGMM] = gmmSD(BG);
    minThresh = medbg + SD*3;
end


if nargout>3
    stats.statsBrightBlocks = statsBrightBlocks;
    stats.statsGMM = statsGMM;
end

end


function [SD,mu,stats] =gmmSD(data)

    data = single(data(:));

    options = statset('MaxIter',250);
    try
        rng( sum(double('Uma wags on')) ); % For reproducibility
        gm_f = fitgmdist(data,2,'Replicates',1,'Regularize', 0.3, 'Options',options);

    catch ME
        size(data)
        gm_f = [];
        disp(ME.message)
    end

    [~,sorted_ind] = sort(gm_f.mu,'ascend');
    SD = gm_f.Sigma(sorted_ind(1))^0.5;
    mu = gm_f.mu(sorted_ind(1));

    if nargout>2
        stats.gm_f = gm_f;
        x=linspace(-1000,2^15,2000);
        [n,x]=hist(data,x);
        stats.hist.x = x;
        stats.hist.n = n;
    end
end

function [im,stats] = removeBrightBlocks(im,settings)
    if isvector(im)
        % see same if statement below
        return
    end

    blockSize = 350;
    pixSize = settings.main.rescaleTo;

    resizeBy = pixSize/blockSize;
    targetSize = round(size(im)*resizeBy);
    imR = imresize(im, targetSize ,'nearest');

    %imagesc(imR), axis square

    %Get rid of the brightest patches
    t = sort(imR(:),'ascend');

    % remove blocks that contain only non-imaged pixels
    t(t==0)=[]; 
    t(t==-42)=[]; 

    keepProp=0.5;
    thresh = t(round(length(t)*keepProp));

    maskMatrix = imresize(imR<=thresh,size(im),'nearest');
    %imagesc(int16(maskMatrix).*im);
    maskMatrix = cast(maskMatrix,class(im));
    im = im .* maskMatrix;

    if nargout>1
        stats.keepProp = keepProp;
        stats.imR = imR;
    end
end

function BG = borderPixGetter(im,settings)

    if isvector(im)
        % HACK. In case a function that already has border pixels calls this to use the gmmSD
        % This is temporary because it's really only because of getForeGroundBackGroundPixels,
        % which will die if we proceed with the plan we have in place for this function.
        BG=im;
        return
    end
    b = settings.main.borderPixSize;
    BG = [im(1:b,:), im(:,1:b)', im(end-b+1:end,:), im(:,end-b+1:end)'];
    BG = BG(:);

    % Remove any non-imaged pixels
    BG(BG == -42) = [];
    BG(BG == 0) = [];

end
