function [cutSeries,msg] = genAutoTrimSequence(obj,lastSliceThickness)
    % Generate a sequence of cutting thickness values to trim down to imaging cut size
    %
    % Purpose
    % Imaging cut thickness should be gradually approached from thicker sections. This
    % is to avoid the vibratome from alternately cutting thick and thin slices. This
    % method generates a list of increasingly thinner slices before taking three slices
    % at the target slice thickness. This is obtained from the recipe. 
    %
    % Inputs [optional]
    % lastSliceThickness - the thickness of the last cut from which we will cut thinner.
    %   By default this is sourced from BT.recipe.lastSliceThickness
    %
    % Outputs
    % cutSeries - a vector of slice thickness numbers in mm which we will loop through
    %           to trim down to the final cuttig thickness.
    % msg - a text message summarizing what will be done. If this not returned then the
    %       text is printed to screen instead.


    if nargin<2
        lastSliceThickness = obj.recipe.lastSliceThickness;
    end

    if isempty(lastSliceThickness)
        cutSeries=[];
        msg='';
        return
    end

    % To avoid cutting too much more tissue, we cap the size of the
    % the lastSliceThickness
    if lastSliceThickness>0.5
        lastSliceThickness=0.5;
    end

    targetThickness = obj.recipe.mosaic.sliceThickness;

    d = 0.6; % How much to decrease the last thickness by
    cutSeries = lastSliceThickness*d;

    while cutSeries(end) > targetThickness
        cutSeries(end+1) = cutSeries(end)*d;
    end

    % Don't waste time cutting slices really close to the final thickness.
    % Also gets rid of points thinner than the final value.
    cutSeries(cutSeries<=(targetThickness+0.015))=[];


    cutSeries = [cutSeries,repmat(targetThickness,1,3)];


    % Build a message
    msg = sprintf('Cutting a further %d slices totalling %0.2f mm\n', ...
                length(cutSeries), sum(cutSeries));

    if nargout<2
        fprintf('%s', msg)
    end

end
