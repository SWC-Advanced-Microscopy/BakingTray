function [SD,medbg,minThresh] = obtainCleanBackgroundSD(im,settings)
%
% Purpose
% autoROI.getForegroundBackgroundPixels returns as background 
% pixels those which are in the border and were not marked as containing
% tissue in the previous section. 
% However, has happened on very rare occaisions that tissue creeping 
% in de novo in the border region does not get picked up at all and inflates
% the SD of the border. To avoid this we fit a 2-component GMM here and take the 
% SD of the dominant component. 


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
    BG = removeBrightBlocks(im,settings);
    BG = BG(:);
    BG(BG == -42) = [];
    BG(BG == 0) = [];

    [SD,medbg] = gmmSD(BG);
    minThresh = medbg + SD*3;
end



% TODO - we need to log what happened so we know which SD we are actually using. 

end




function [SD,mu] =gmmSD(data)
    data = single(data(:));
    options = statset('MaxIter',1000);
    gm_f = fitgmdist(data,2,'Replicates',1,'Regularize', 0.1, 'Options',options);

    [~,sorted_ind] = sort(gm_f.mu,'ascend');
    SD = gm_f.Sigma(sorted_ind(1))^0.5;
    mu = gm_f.mu(sorted_ind(1));
end

function im = removeBrightBlocks(im,settings)
    if isvector(im)
        % see same if statement below
        return
    end
    blockSize = 950;
    pixSize = settings.main.rescaleTo;

    resizeBy = pixSize/blockSize;
    targetSize = round(size(im)*resizeBy);
    imR = imresize(im, targetSize ,'nearest');

    %imagesc(imR), axis square

    %Get rid of the brightest patches
    t = sort(imR(:),'ascend');

    thresh = t(round(length(t)*0.5));

    maskMatrix = imresize(imR<=thresh,size(im),'nearest');
    %imagesc(int16(maskMatrix).*im);
    maskMatrix = cast(maskMatrix,class(im));
    im = im .* maskMatrix;
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
