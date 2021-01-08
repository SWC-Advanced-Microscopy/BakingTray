function BG = getBackgroundPixels(im,settings)
% Obtains background pixels 
%
% WORK IN PROGRESS


if nargin<2
    settings = autoROI.readSettings;
end

method = 'border';

switch method
case 'border'
    BG = borderPixGetter(im,settings);
case 'gmm'
end



% Remove any non-imaged pixels
BG(BG == -42) = [];
BG(BG == 0) = [];




end


function BG = borderPixGetter(im,settings)
    b = settings.main.borderPixSize;
    BG = [im(1:b,:), im(:,1:b)', im(end-b+1:end,:), im(:,end-b+1:end)'];
    BG = BG(:);
end