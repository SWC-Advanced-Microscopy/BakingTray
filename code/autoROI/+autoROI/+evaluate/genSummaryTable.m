function varargout = genSummaryTable(dirToProcess)
% Generate a summary table for a test directory
%
% function summaryTable = boundingBoxFromLastSection.evaluate.genSummaryTable(dirToProcess)
%
%
% Purpose
% Load all testLog files in a test directory and condense the key infofmation into a single table.
% Works in current directory if no directory is provided as input. The summary table is written
% into the test directory and also optionally returned as an output argument. The table is saved
% as a file called summary_table.mat containing a variable called 'summaryTable'.
%
% Inputs
% dirToProcess - Path to test directory to process. If missing, it attempt to run on the current dir.
%
%
% Outputs
% summaryTable - summary table.
%
%
% Rob Campbell - SWC 2020


if nargin<1
    dirToProcess=pwd;
end

tLogs = dir(fullfile(dirToProcess,'log_*.mat'));

if isempty(tLogs)
    fprintf('No testLog .mat files found in directory %s\n', dirToProcess)
    return
end


% Pre-allocate the variables that we will later use to build the table
% Most of these numbers come from evaluateROIs. Some from runOnStackStruct or runOnAllInDir.
n=length(tLogs);
fileName = {tLogs.name}';
pStackFname = cell(n,1);
mean_tThresh = zeros(n,1); %Mean over all elements of log structure
rollingThreshold = zeros(n,1);
numSectionsWithHighCoverage = zeros(n,1); %See evluateBoundingBoxes. Should be with coverage of over 0.99
numSectionsWithOverFlowingCoverage = zeros(n,1); %See evluateBoundingBoxes. ROI coverage larger then FOV.
numUnprocessedSections = zeros(n,1);
% zeros(n,1); %% TODO -- delete
totalImagedSqMM = zeros(n,1);
propImagedArea = zeros(n,1); %Proportion of the original FOV that was imaged
nSamples = zeros(n,1);
isProblemCase = zeros(n,1);

totalNonImagedTiles = zeros(n,1);
totalNonImagedSqMM = zeros(n,1);
totalExtraSqMM = zeros(n,1);
maxNonImagedTiles = zeros(n,1);
maxNonImagedSqMM = zeros(n,1);
maxExtraSqMM = zeros(n,1);
nPlanesWithMissingTissue = zeros(n,1);

%autothresh_notes = cell(n,1);
%autothresh_SNR = zeros(n,1);
%autothresh_tThreshSD = zeros(n,1);


% Loop through the testLog files. Load each in turn and 
% populate above variables.
fprintf('\nGenerating summary table:\n')
for ii=1:n
    fname=fullfile(dirToProcess,fileName{ii});
    fprintf('Processing %s\n',fname)
    load(fname)

    % Populate variables
    pStackFname{ii} = testLog.stackFname;
    mean_tThresh(ii) = mean([testLog.roiStats.tThresh]);
    rollingThreshold(ii) = testLog.settings.stackStr.rollingThreshold;
    numSectionsWithHighCoverage(ii) = testLog.report.numSectionsWithHighCoverage;
    numSectionsWithOverFlowingCoverage(ii) = testLog.report.numSectionsWithOverFlowingCoverage;
    numUnprocessedSections(ii) = testLog.numUnprocessedSections;

    %% medPropPixelsInRoiThatAreTissue(ii) = testLog.report.medPropPixelsInRoiThatAreTissue; %% TODO -- delete
    totalImagedSqMM(ii) = testLog.report.totalImagedSqMM;
    propImagedArea(ii) = testLog.report.propImagedArea;
    nSamples(ii) = testLog.nSamples;

    % Get auto-thresh info
    if ~isempty(strfind(pStackFname{ii},'problemCases'))
        isProblemCase(ii) = 1;
    end

    % Get more info from report structure
    totalNonImagedTiles(ii) = sum(testLog.report.nonImagedTiles);
    totalNonImagedSqMM(ii) = sum(testLog.report.nonImagedSqMM);
    totalExtraSqMM(ii) = sum(testLog.report.extraSqMM);

    maxNonImagedTiles(ii) = max(testLog.report.nonImagedTiles);
    maxNonImagedSqMM(ii) = max(testLog.report.nonImagedSqMM);
    maxExtraSqMM(ii) = max(testLog.report.extraSqMM);

    nPlanesWithMissingTissue(ii) = max(testLog.report.nPlanesWithMissingTissue);
end


% Construct table
fprintf('\nBuilding table\n')
isProblemCase = logical(isProblemCase);
summaryTable = table(fileName, rollingThreshold, numSectionsWithHighCoverage, ...
    mean_tThresh, numSectionsWithOverFlowingCoverage, totalImagedSqMM, ... 
    propImagedArea, nSamples, isProblemCase, numUnprocessedSections, ...
    totalNonImagedTiles, totalNonImagedSqMM, totalExtraSqMM, ...
    maxNonImagedTiles, maxNonImagedSqMM, maxExtraSqMM,nPlanesWithMissingTissue, ...
    pStackFname);


% Save the table to disk
fname=fullfile(dirToProcess,'summary_table.mat');
fprintf('Saving table to %s\n', fname)
save(fname,'summaryTable')


if nargout>0
    varargout{1}=summaryTable;
end




function [notes, tThreshSD, SNR] = returnAutoThreshSummaryStats(testLog)
    % Get the autoThresh stats from the case that best matches the finally chosen
    % tThreshSD that was returned by the auto-thresholder

    notes = testLog.autothreshStats(1).notes;
    notes = strtrim(notes);

    tThreshSDactual=testLog.roiStats(1).tThreshSD;

    % Find the SNR of the closest tThresh we have
    tTvec = [testLog.autothreshStats.tThreshSD];
    d = abs(tTvec - tThreshSDactual);
    [~,ind] = min(d);
    tThreshSD = tTvec(ind);
    SNR = testLog.autothreshStats(ind).SNR_medThreshRatio;


function checkSize(varargin)
    % Used for debugging if one variable is a different size. Otherwise ignore this function. 
    for ii=1:length(varargin)
        fprintf('%d/%d - %dx%d\n', ii, length(varargin), size(varargin{ii},1), size(varargin{ii},2))
    end