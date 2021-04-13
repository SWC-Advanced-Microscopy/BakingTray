function SD = obtainCleanBackgroundSD(data,bypassGMM)
% Optionally remove potential bright (tissue) pixels using a GMM
%
% function SD = obtainCleanBackgroundSD(data,bypassGMM)
% 
% 
% Purpose
% autoROI.getForegroundBackgroundPixels returns as background those
% pixels which are in the border and were not marked as containing
% tissue in the previous section. However, has happened on very rare
% occasions that tissue creeping in de novo in the border region does 
% not get picked up at all and inflates the SD of the border. To avoid
% this we fit a 2-component GMM here and take the  SD of the dominant 
% component. 
%
% NOTE
% The GMM approach is poorly tested right now so this routine is actually
% skipped. i.e. ** THIS FUNCITON JUST RETURNS THE SD OF THE DATA **
%
% Inputs
% data - the background pixels from the border
% bypassGMM - false by default. If false we just return the SD.
%             only if true do we try the GMM.



if nargin<2
    bypassGMM=true;
end


if bypassGMM
    SD = std(data);
    return
end



try
    SD = gmmSD(data);
catch ME
    disp(ME.message)
    SD = std(data);
end

% TODO - if we actually end up using this, we need to log what happened so we
%        know which SD we are actually using. 



function SD =gmmSD(data)
    data = single(data(:));
    options = statset('MaxIter',500);

    gm_f = fitgmdist(data,2,'Replicates',5,'Options',options);
    [~,sorted_ind] = sort(gm_f.ComponentProportion,'descend');
    SD = gm_f.Sigma(sorted_ind(1))^0.5;

