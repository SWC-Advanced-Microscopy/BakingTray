function runEvaluation(dataPath)
    % Re-evaluate all data in the reference test directory
    %
    % function runEvaluation(dataPath)
    %
    % Purpose
    % There will be a reference directory of current best performance. 
    % This function re-runs the analyses on all samples in that directory. 
    % It produces a new directory of test data in this process and then 
    % evaluates if the results in the new directory are worse than the 
    % existing directory. It does not check if the resulst are better. 
    %
    %
    % Inputs
    % dataPath - either the path to where the data are kept or the path 
    %            to a specific reference folder. If the former, it 
    %            searches for a directory called "test_reference" and 
    %            works on that.
    %
    %
    % Example Usage
    % $ cd ~/Desktop/
    % $ git clone https://github.com/raacampbell/autofinder.git
    % >> cd ~/Desktop/autofinder/
    % >> addToPath
    % Removing /home/user/work/code/autoFindBrain/code from MATLAB path.
    % Adding /home/user/Desktop/autofinder/code to MATLAB path.
    % >> cd tests
    % >> runEvaluation('/Volumes/data/previewStacks')
    %
    %
    % Rob Campbell - April 2020



    if exist(fullfile(dataPath,'test_reference'),'dir')
        % Can we find the test_reference directory in this path?
        dataPath = fullfile(dataPath,'test_reference');

    elseif exist(fullfile(dataPath,'summary_table.mat'),'file')
        % Is this a test directory? If so, dataPath will be deemed the folder
        % from which we get the test data.
    end


    % Load the summary table and generate a list of paths to pStack files within it.
    pathToSummaryTable = fullfile(dataPath,'summary_table.mat');
    if ~exist(pathToSummaryTable,'file')
        fprintf('Can not find summary table at: %s\n', pathToSummaryTable)
        return
    end

    load(pathToSummaryTable)
    % Make an output similar to dir, because this is what is expected
    % by autoROI.tests.runOnAllInDir, which will get
    % this sturcture as input
    for ii=1:size(summaryTable)
        [folder,name,extension] = fileparts(summaryTable.pStackFname{ii});
        pStackDirStruct(ii).name = [name,extension];
        pStackDirStruct(ii).folder = folder;
        pStackDirStruct(ii).isdir = false;
    end


    % We will run in a temporary directory
    testDir = tempdir;
    fprintf('Running test in temporary folder with:\n');
    fprintf('autoROI.test.runOnAllInDir(pStackDirStruct,''%s'')\n\n', ...
            testDir)

    testDirThisSession = autoROI.test.runOnAllInDir(pStackDirStruct,testDir);


    % Now evaluate results
    autoROI.batchtest.evaluatePerformance(dataPath,testDirThisSession)
    fprintf('\n\nEvaluated performance with:\nevaluatePerformance(''%s'',''%s'')\n\n', ...
        dataPath,testDirThisSession)
