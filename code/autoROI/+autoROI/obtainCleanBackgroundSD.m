function SD = obtainCleanBackgroundSD(data,bypassGMM)
% Remove potential bright (tissue) pixels using a GMM
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
    bypassGMM=false;
end

bypassGMM=true;

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

% TODO - we need to log what happened so we know which SD we are actually using. 



function SD =gmmSD(data)
    data = single(data(:));
    options = statset('MaxIter',500);

    gm_f = fitgmdist(data,2,'Replicates',5,'Options',options);
    [~,sorted_ind] = sort(gm_f.ComponentProportion,'descend');
    SD = gm_f.Sigma(sorted_ind(1))^0.5;

