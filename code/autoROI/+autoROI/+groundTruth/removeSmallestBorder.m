function pStack = removeSmallestBorder(pStack,inds,targetNumber)
% Remove the smallest sample border from pStack.borders{inds}
%
% pStack = autoROI.groundTruth.stackToGroundTruth(removeSmallestBorder(pStack,inds,targetNumver)
%
% Purpose
% Used to help curate data. Removes whichever is the smallest border in each cell defined by 
% the vector inds.
%
% 
% Inputs
% pStack - pStack data structure.
% inds - a vector to loop over. These are indecies of pStack.borders
%            have multiple samples.
% targetNumber - empty by default. If supplied this scalar will ask the function to keep the 
%                "targetNumber" largest borders and delete all the rest.
%
% Outputs
% pStack - pStack data structure.
%
%

if nargin<3
    targetNumber=[];
end

if ~isstruct(pStack)
    fprintf('pStack should be a structure\n')
    return
end

if ~isfield(pStack,'borders')
    fprintf('No borders field in pStruct. First you need to run autoROI.groundTruth.genGroundTruthBorders\n')
    return
end


for ii=1:length(inds)
    tInd = inds(ii);

    if tInd > length(pStack.borders{1})
        fprintf('index %d is out of range. length borders is %d. Skipping.\n', ...
            tInd, length(pStack.borders{1}))
        continue
    end

    % Get the borders and the sorted indecies
    tB = pStack.borders{1}{tInd};
    L = cellfun(@length, tB);
    [~,ind]=sort(L);

    %Find smallest border and remove it
    if ~isempty(targetNumber) && isscalar(targetNumber) && targetNumber>0
        if targetNumber>=length(L)
            continue
        end
        fprintf('Keeping the largest %d borders from a list of %d borders\n', targetNumber, length(tB));
        tB(ind(1: (length(L)-targetNumber)) )=[];
    else
        fprintf('Removing the smallest border from a list of %d borders\n', length(tB));
        tB(ind(1))=[];
    end


    pStack.borders{1}{tInd} = tB;
 
end
