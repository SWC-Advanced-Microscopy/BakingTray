function summaryTable = getSummaryTable(testDir)
% Local helper function for getting the summary table.
% Avoids boilerplate. 


summaryTable = [];

if nargin<1 || isempty(testDir)
    testDir=pwd;
end

if ~exist(testDir,'dir')
    fprintf('The test directory %s does not exist.\n',testDir);
    return
end

fname = fullfile(testDir,'summary_table.mat');

if ~exist(fname,'file')
    fprintf('No summary_table.mat file found.\n');

    return
else
    load(fname)
end

