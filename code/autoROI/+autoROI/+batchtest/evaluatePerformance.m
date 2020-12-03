function varargout = evaluatePerformance(referenceDir,testDir)
    % Evaluates the performance of two directories and returns pass/fail info to screen
    %
    % function passedAllTests = evaluatePerformance(referenceDir,testDir)
    %
    % Purpose
    % Does a basic test of a test directory and reports whether or not it does
    % worse than a reference directory. This function is to be used like a unit test. 
    % In practice, it will be called by runEvaluation
    %
    %
    % Inputs
    % referenceDir - the reference (known good) directory
    % testDir - the directory being assessed
    %
    %
    % Outputs (optional)
    % passedAllTests - boolean. If true, all tests were passed. False otherwise.
    % msgString - String containing all text displayed to screen when function is run. 
    %
    %
    % Rob Campbell - April 2020


    passedAllTests=false;

    reportString = '';

    % Report what is being compared
    clc
    reportString = sprintf('\n\n ** TEST RESULTS ** \n\n');
    reportString = [reportString, sprintf('Reference directory:\n%s\n', readLogFile(referenceDir))];
    reportString = [reportString, sprintf('Test directory:\n%s\n', readLogFile(testDir))];

    % TEST ONE: are there missing files in the test table?
    refTable  = autoROI.evaluate.getSummaryTable(referenceDir);
    testTable = autoROI.evaluate.getSummaryTable(testDir);


    % Report whether the two tables are the same size
    if size(refTable,1) == size(testTable,1)
        reportString = [reportString, sprintf('PASS: Test and reference tables have the same number of entries.\n')];
    else
        reportString = [reportString, ...
          sprintf('FAIL: Test table has %d entries but reference table has %d entries.\n', ...
                size(testTable,1), size(refTable,1))];
          passedAllTests=false;
    end

    % Report exactly what the differences are
    missingFileInds = cellfun(@(x) isempty(strmatch(x,testTable.fileName)), ...
            refTable.fileName,'UniformOutput',false);
    missingFileInds = find(cell2mat(missingFileInds));

    if any(missingFileInds)
        if length(missingFileInds)>1
            reportString = [reportString, sprintf('FAIL: The following %d acquisitions are missing from the test table:\n', length(missingFileInds))];
        else
            reportString = [reportString, sprintf('FAIL: The following acquisition is missing from the test table:\n')];
        end
        for ii=1:length(missingFileInds)
            reportString = [reportString, sprintf(' %s\n',refTable.fileName{missingFileInds(ii)})];
        end
        reportString = [reportString, sprintf('\n')];
        passedAllTests=false;
    else
        reportString = [reportString, sprintf('PASS: All test acquisitions are present in reference table.\n')];
    end



    % Now get the result data without any missing files. i.e. only files common to the two
    % test directories will be processsed from now on.
    [cTable,refTable,testTable] = autoROI.evaluate.genComparisonTable(referenceDir,testDir,true);
    if isempty(cTable)
        reportString = [reportString, sprintf('FAILED to get comparison table. Quitting.\n')]
        passedAllTests=false;
        return
    end



    % TEST TWO: are there more unprocessed sections?
    f=find(cTable.d_numUnprocessedSections<0);
    if ~isempty(f)
        if length(f)>1
            reportString = [reportString, sprintf('FAIL: %d test acquisitions have an increased in the number of unprocessed sections:\n', length(f))];
        else
            reportString = [reportString, sprintf('FAIL: %d test acquisition has an increased in the number of unprocessed sections:\n', length(f))];
        end
        for ii=1:length(f)
            reportString = [reportString, sprintf(' %s goes from %d unprocessed sections to %d unprocessed sections.\n', ...
                cTable.fileName{f(ii)}, refTable.numUnprocessedSections(f(ii)), ...
                testTable.numUnprocessedSections(f(ii)))];
        end
        reportString = [reportString, sprintf('\n')];
        passedAllTests=false;
    else
        reportString = [reportString, sprintf('PASS: No acquisitions see an increase in the number of unprocessed sections.\n')];
    end



    % TEST THREE: has there been a significant increase in the number of square mm not imaged?
    maxToleratedSqMMIncrease=15;
    f=find(cTable.d_totalNonImagedSqMM < -maxToleratedSqMMIncrease);
    if ~isempty(f)
        if length(f)>1
            reportString = [reportString, sprintf('FAIL: %d test acquisitions have seen a decrease of >%d sq mm:\n', ...
                length(f), maxToleratedSqMMIncrease)];
        else
            reportString = [reportString, sprintf('FAIL: %d test acquisition has seen a decrease of >%d sq mm:\n', ...
                length(f), maxToleratedSqMMIncrease)];
        end
        for ii=1:length(f)
            reportString = [reportString, sprintf(' %s goes from %0.2f sq mm missed to %0.2f sq mm missed.\n', ...
                cTable.fileName{f(ii)}, refTable.totalNonImagedSqMM(f(ii)), ...
                testTable.totalNonImagedSqMM(f(ii)))];
        end
        reportString = [reportString, sprintf('\n')];
        passedAllTests=false;
    else
        reportString = [reportString, sprintf('PASS: No acquisitions saw an increase in non-imaged sq mm of >%d.\n', maxToleratedSqMMIncrease)];
    end



    % TEST FOUR: do any acquisitions now cross a threshold for too tissue not imaged?
    maxToleratedSqMMLoss=50;
    f=find(testTable.totalNonImagedSqMM > maxToleratedSqMMLoss);
    if ~isempty(f)
        if length(f)>1
            reportString = [reportString, sprintf('FAIL: %d test acquisitions have lost more than %d sq mm:\n', ...
                length(f), maxToleratedSqMMLoss)];
        else
            reportString = [reportString, sprintf('FAIL: %d test acquisition has seen a decrease of >%d sq mm:\n', ...
                length(f), maxToleratedSqMMLoss)];
        end
        for ii=1:length(f)
            reportString = [reportString, sprintf(' %s now loses %0.2f sq mm (reference was %0.2f sq mm).\n', ...
                cTable.fileName{f(ii)}, testTable.totalNonImagedSqMM(f(ii)), ...
                refTable.totalNonImagedSqMM(f(ii)))];
        end
        reportString = [reportString, sprintf('\n')];
        passedAllTests=false;
    else
        reportString = [reportString, sprintf('PASS: No acquisitions have >%d sq mm of non-imaged tissue.\n', maxToleratedSqMMLoss)];
    end



    % TEST FIVE: Is there a problematic increase in the number of sections with over-flowing ROIs?
    maxToleratedOverFlowingSectionInrease=2;
    f=find(cTable.d_numSectionsWithOverFlowingCoverage > maxToleratedOverFlowingSectionInrease);
    if ~isempty(f)
        if length(f)>1
            reportString = [reportString, sprintf('FAIL: %d test acquisitions show an increase of over %d sections that overflow original FOV:\n', ...
                length(f), maxToleratedOverFlowingSectionInrease)];
        else
            reportString = [reportString, sprintf('FAIL: %d test acquisition shows an increase of over %d sections that overflow original FOV:\n', ...
                length(f), maxToleratedOverFlowingSectionInrease)];
        end
        for ii=1:length(f)
            reportString = [reportString, sprintf(' %s now has %d over-flowing section (reference had %d).\n', ...
                cTable.fileName{f(ii)}, testTable.numSectionsWithOverFlowingCoverage(f(ii)), ...
                refTable.numSectionsWithOverFlowingCoverage(f(ii)))];
        end
        reportString = [reportString, sprintf('\n')];
        passedAllTests=false;
    else
        reportString = [reportString, sprintf('PASS: No acquisitions see an increase in the number of over-flowing sections.\n')];
    end


    % FINALLY: are the reference test acquisition results identical? 
    % This isn't a failure point, as changing parameter will result in things not 
    % being the same. But after some changes we make to the code we will expect things
    % to stay indentical, so we need to know this. 
    if sum(abs(cTable.d_totalNonImagedSqMM))==0
        reportString = [reportString, sprintf('\nThe test and reference results have *IDENTICAL* non imaged areas.\n')];
    else
        reportString = [reportString, sprintf('\nThe test and reference results *DO NOT* have identical non imaged areas.\n')];
    end

    if sum(abs(cTable.d_medPropPixelsInRoiThatAreTissue))==0
        reportString = [reportString, sprintf('The test and reference results have *IDENTICAL* proportions of sample pixels in ROIs.\n')];
    else
        reportString = [reportString, sprintf('The test and reference results *DO NOT* identical proportions of sample pixels in ROIs.\n')];
    end

    if sum(abs(refTable.autothresh_tThreshSD-testTable.autothresh_tThreshSD))==0
        reportString = [reportString, sprintf('The test and reference results have *IDENTICAL* initial auto-thresh tThreshSD values for all samples.\n')];
    else
        reportString = [reportString, sprintf('The test and reference results *DO NOT* have identical initial auto-thresh tThreshSD values for all samples.\n')];
    end

    if sum(abs(refTable.mean_tThresh-testTable.mean_tThresh))==0
        reportString = [reportString, sprintf('The test and reference results have *IDENTICAL* mean thresholds for all samples.\n')];
    else
        reportString = [reportString, sprintf('The test and reference results *DO NOT* have identical mean thresholds for all samples.\n')];
    end

    % Show results to screen
    disp(reportString)

    if nargout>0
        varargout{1}=passedAllTests;
    end

    if nargout>1
        varargout{2}=reportString;
    end

    if nargout>2
        varargout{3}=cTable;
    end



function out = readLogFile(testDir)
    % Reads the log file form the test directory
    fname = fullfile(testDir,'LOG_FILE.txt');
    out='';
    if ~exist(fname,'file')
        reportString = fprintf('Can not find log file at: %s\n', fname);
        return
    end

    fid = fopen(fname,'r');

    out='';
    while 1
        tline=fgetl(fid);
        if ~ischar(tline), break, end
        out=[out,sprintf('%s\n',tline)];
    end

    fclose(fid);


