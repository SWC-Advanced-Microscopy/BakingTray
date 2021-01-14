function [cTable,refTable,testTable] = genComparisonTable(dirReference,dirTest,quiet)
% Generate a table of variables that can be used to compare two test directories
%
%  function cTable = autoROI.test.genComparisonTable(dirReference,dirTest)
%
%
% Purpose
% The output of this function is used by the likes of compareResults, which graphically
% displays the information calculted here. The data in dirTest will be compared to the
% "known good" data in dirReference.
% For comparison data that are the difference between the two we always subtract the
% test data from the refrence. i.e.:
% d_numUnprocessedSections = refTable.numUnprocessedSections - testTable.numUnprocessedSections
%
% Also returns the tables used to make the comparison table. These have been filtered
% so that they contain the same acquisitions in the same order. 
%
% Inputs
% dirReference - path to first file, which will correspond to the "initial" data
% dirTest - path to second file, which will correspond to the "new" state. 
%
% Inputs
% optional - quiet. False by default. If true, don't report import status and filenames to screen
%
%
% Outputs
% cTable - Comparison structure
% refTable - the reference results table
% testTable - the test results table
%
%
% Rob Campbell - SWC 2020


if nargin<3 || isempty(quiet)
    quiet=false;
end

cTable = [];

refTable = autoROI.evaluate.getSummaryTable(dirReference);
testTable = autoROI.evaluate.getSummaryTable(dirTest);

if isempty(refTable) || isempty(testTable)
    return
end



% Remove any samples in the test table that don't exist in the reference table
% and then sort them both alphabetically .
acquisitionsExcluded=false;

missingFileInds = cellfun(@(x) isempty(strmatch(x,refTable.fileName)), ...
    testTable.fileName,'uniformoutput',false);
missingFileInds = cell2mat(missingFileInds);

if any(missingFileInds)
    if ~quiet
        if sum(missingFileInds)>1
            fprintf('Removing %d acquisitions from test table because they are not present in the reference table:\n', sum(missingFileInds));
        else
            fprintf('Removing %d acquisition from test table because it is not present in the reference table:\n', sum(missingFileInds));
        end
        cellfun(@(x) fprintf(' %s\n',x),testTable.fileName(missingFileInds))
        fprintf('\n')
    end
    testTable(find(missingFileInds),:)=[];
    acquisitionsExcluded=true;
end

% Now remove any samples in the reference table that aren't in the test table
missingFileInds = cellfun(@(x) isempty(strmatch(x,testTable.fileName)), ...
    refTable.fileName,'uniformoutput',false);
missingFileInds = cell2mat(missingFileInds);

if any(missingFileInds)
    if ~quiet
        if sum(missingFileInds)>1
            fprintf('Removing %d acquisitions from reference table because they are not present in the test table:\n', sum(missingFileInds));
        else
            fprintf('Removing %d acquisition from reference table because it is not present in the test table:\n', sum(missingFileInds));
        end
        cellfun(@(x) fprintf(' %s\n',x),refTable.fileName(missingFileInds))
        fprintf('\n')
    end
    refTable(find(missingFileInds),:)=[];
    acquisitionsExcluded=true;
end



%Sort both tables alphabetically so we have data from the same sample on each row
%Then sort by sqmm missed in ref table once they share index values.
[~,ind] = sort(refTable.fileName);
refTable = refTable(ind,:);
testTable = testTable(ind,:);

[~,ind] = sort(refTable.totalNonImagedSqMM);
refTable = refTable(ind,:);
testTable = testTable(ind,:);

%report to screen the file name and index of each recording.
%the weirdness below is because we make a two-column list.
if ~quiet
    autoROI.evaluate.printFileNamesAsDoubleColumnTable(refTable.fileName)

    if acquisitionsExcluded
        fprintf('\nSome acquisitions were excluded. See text above acquisition list.\n\n')
    end
end



% Generate data that will be useful to downstream functions for evaluating performance

% File names
fileName = refTable.fileName;

% Difference in the number of unprocesssed sections
d_numUnprocessedSections = refTable.numUnprocessedSections - testTable.numUnprocessedSections;

% Difference in the total non-imaged square mm of sample
d_totalNonImagedSqMM = refTable.totalNonImagedSqMM - testTable.totalNonImagedSqMM;

% difference in the total sq mm of of sample imaged more than once
d_totalExtraSqMM = refTable.totalExtraSqMM - testTable.totalExtraSqMM;

% difference in sq mm of of sample imaged more than once for the worst section
d_maxExtraSqMM = refTable.maxExtraSqMM - testTable.maxExtraSqMM;

% difference in the median proportion of pixels in the ROI that are tissue
% TODO - is that over sections? DELETE
%d_medPropPixelsInRoiThatAreTissue = refTable.medPropPixelsInRoiThatAreTissue - testTable.medPropPixelsInRoiThatAreTissue;

% difference in the total imaged sq mm
d_totalImagedSqMM = refTable.totalImagedSqMM - testTable.totalImagedSqMM;

% difference in the number of ROIs that overflow the original FOV
d_numSectionsWithOverFlowingCoverage = refTable.numSectionsWithOverFlowingCoverage -  testTable.numSectionsWithOverFlowingCoverage;

cTable = table(fileName, ...
            d_numUnprocessedSections, ...
            d_totalNonImagedSqMM, ...
            d_totalExtraSqMM, ...
            d_maxExtraSqMM, ...
            d_totalImagedSqMM, ...
            d_numSectionsWithOverFlowingCoverage);


