function genBordersForAllInDir(thresh)
% Loop through all p-stack files in current directory and generate ground truth borders for all
%
% pStack = autoROI.groundTruth.genBordersForAllInDir(thresh)
%
% Purpose
% Speeds up initial border making. You will still have to curate them, but it's less
% human time to generate all automatcally then look a them. 
%
% 
% Inputs
% thresh - optional SD threshold to use.
%

if nargin==0;
    thresh=[];
end

D = dir ('*_previewStack.mat');

if isempty(D)
    fprintf('No preview mat files found in %s\n', pwd);
    return
end


for ii=1:length(D)
    fname = D(ii).name;

    fprintf('Loading %s...\n', fname)
    load(fname)

    fprintf('Getting borders for %s\n', fname)
    pStack = autoROI.groundTruth.genGroundTruthBorders(pStack,thresh);

    fprintf('Saving %s...\n', fname)
    save('-v7.3',fname,'pStack')
end