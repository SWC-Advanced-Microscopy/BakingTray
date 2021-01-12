function plotResults(testDir,varargin)
% Make summary plots of all data in a test directory
%
%  function autoROI.test.plotResults(testDir)
%
% Purpose
% This function helps to highlight which samples still need more work. If
% run with no input argument, it works in the current directory. 
%
% Inputs
% testDir - path test directory. Optional. If missing or empty, current directory.
%
% Inputs (param/val pairs)
% excludeIndex - vector of acquisition idexes to exclude from plotting.
%
%
% Outputs
% none
%
%
% Rob Campbell - SWC 2020

if nargin<1 || isempty(testDir)
    testDir=[];
end

params = inputParser;
params.CaseSensitive=false;
params.addParameter('excludeIndex',[],@isnumeric)

params.parse(varargin{:})
excludeIndex = params.Results.excludeIndex;



summaryTable = autoROI.evaluate.getSummaryTable(testDir);
if isempty(summaryTable)
    return 
end

% Sort by sqmm missed
[~,ind] = sort(summaryTable.totalNonImagedSqMM);
summaryTable = summaryTable(ind,:);


if ~isempty(excludeIndex)
    summaryTable(excludeIndex,:)=[];
end

%report to screen the file name and index of each recording
autoROI.evaluate.printFileNamesAsDoubleColumnTable(summaryTable.fileName)



% Report if any samples failed
failedSamples = dir(fullfile(testDir,'FAIL_*'));
if ~isempty(failedSamples)
    if length(failedSamples)==1
        fprintf('\n** THERE IS %d FAILED ACQUISITON IN FOLDER %s:\n', ...
            length(failedSamples), testDir)
    else
        fprintf('\n** THERE ARE %d FAILED ACQUISITONS IN FOLDER %s:\n', ...
            length(failedSamples), testDir)
    end
    cellfun(@(x) fprintf(' %s\n',strrep(x,'FAIL_','')), {failedSamples.name})
    fprintf('\n')
end

% Report recordings with unprocessed sections
f=find(summaryTable.numUnprocessedSections>0);
if ~isempty(f)
    fprintf('\n\n ** The following recordings have unprocessed sections that contained data:\n')
    for ii=1:length(f)
            fprintf('%d/%d. %s -- %d unprocessed sections. tThresh SD=%0.2f\n', f(ii), size(summaryTable,1), ...
        summaryTable.fileName{f(ii)}, summaryTable.numUnprocessedSections(f(ii)), ...
        summaryTable.tThreshSD(f(ii))     );
    end
end


% Get the plot settings
pS = plotSettings;


clf
nRows=6;
nCols=3;

subplot(nRows,nCols,1)
x=1:length(summaryTable.totalNonImagedSqMM);
plot(x,summaryTable.totalNonImagedSqMM, pS.basePlotStyle{:})

% Overlay circles onto problem cases
hold on 
plot(x(summaryTable.isProblemCase), ...
    summaryTable.totalNonImagedSqMM(summaryTable.isProblemCase), ...
    pS.highlightProblemCases{:}) 
hold off
ylabel('Square mm missed')

grid on
%cap really large values and plot again
f=find(summaryTable.totalNonImagedSqMM>100);
if ~isempty(f)
    capped = summaryTable.totalNonImagedSqMM;
    capped(capped>100)=nan;
    yyaxis('right');
    plot(capped, '.-','color',[0,0,1,0.35])
    ylabel('Capped at 50 sq mm')
    set(gca,'YColor','b')
end
xlabel('Acquisition #')

title('Total square mm missed (lower better). Problem cases highlighted.')
xlim([1,size(summaryTable,1)])


subplot(nRows,nCols,2)
plot(summaryTable.maxNonImagedSqMM, pS.basePlotStyle{:})
hold on 
plot(xlim,[0,0],'k:')
grid on
hold off
xlabel('Acquisition #')
ylabel('Square mm missed')
title('Worst section square mm missed (lower better)')
xlim([1,size(summaryTable,1)])



subplot(nRows,nCols,3)
plot(summaryTable.totalExtraSqMM, pS.basePlotStyle{:})
hold on 

% Highlight problem cases
plot(x(summaryTable.isProblemCase), ...
    summaryTable.totalExtraSqMM(summaryTable.isProblemCase), ...
    pS.highlightProblemCases{:}) 

% Highlight cases with many sections having high coverage
f = find(summaryTable.numSectionsWithOverFlowingCoverage>0);
plot(x(f), ...
    summaryTable.totalExtraSqMM(f), ...
    pS.highlightHighCoverage{:}) 

plot(xlim,[0,0],'k:')
grid on
hold off
xlabel('Acquisition #')
ylabel('Square mm extra')
title('Total square mm extra (lower better). red: problem. green: overflowing coverage.')
xlim([1,size(summaryTable,1)])

%Report to terminal cases where we have over-flowing ROIs
if ~isempty(f)
    fprintf('\nThe following have overflowing ROIs:\n')
    for ii=1:length(f)
        fprintf('%d/%d %s -- %d sections\n', ...
            f(ii),size(summaryTable,1), summaryTable.fileName{f(ii)}, ...
            summaryTable.numSectionsWithOverFlowingCoverage(f(ii)) )
    end
    fprintf('\n')
end

subplot(nRows,nCols,4)
plot(summaryTable.maxExtraSqMM, pS.basePlotStyle{:})
hold on 
plot(xlim,[0,0],'k:')
grid on
hold off
xlabel('Acquisition #')
ylabel('Aquare mm extra')
title('Section with most extra square mm (lower better)')
xlim([1,size(summaryTable,1)])



subplot(nRows,nCols,5)
plot(summaryTable.totalImagedSqMM,summaryTable.totalNonImagedSqMM, pS.basePlotStyle{:},'linestyle','none')
xoffset = diff(xlim)*0.0075;
yoffset = diff(ylim)*0.02;
for ii=1:length(summaryTable.totalImagedSqMM)
    text(summaryTable.totalImagedSqMM(ii)+xoffset, summaryTable.totalNonImagedSqMM(ii)+yoffset,num2str(ii))
end
hold off
xlabel('Extra sq mm')
ylabel('Missed sq mm')


subplot(nRows,nCols,6)
nBins=round(length(summaryTable.totalNonImagedSqMM)/5);
if nBins<5
    nBins=5;
end
hist(summaryTable.totalNonImagedSqMM,nBins)
xl=xlim;
xlim([0,xl(2)]);
xlabel('Missed sq mm')
ylabel('# acquisitions')



subplot(nRows,nCols,7)
plot(summaryTable.propImagedArea, pS.basePlotStyle{:})
mu=mean(summaryTable.propImagedArea);
hold on
plot(x(summaryTable.isProblemCase), ...
    summaryTable.propImagedArea(summaryTable.isProblemCase), ...
    pS.highlightProblemCases{:}) 
plot([xlim],[mu,mu],'--b')
hold off
xlabel('Acquisition #')
ylabel('Total imaged sq mm')
title(sprintf('Prop orig area covered by ROIs (mean=%0.3f). highlights are problem cases', mu))
ylim([0,1])
grid on
xlim([1,size(summaryTable,1)])



subplot(nRows,nCols,8)
plot(summaryTable.medPropPixelsInRoiThatAreTissue, pS.basePlotStyle{:})
mu = mean(summaryTable.medPropPixelsInRoiThatAreTissue);
hold on
plot([xlim],[mu,mu],'--b')
hold off
xlim([1,size(summaryTable,1)])
ylim([0,1])
xlabel('Acquisition #')
ylabel('Prop ROI area filled')
title('Proportion of imaged ROI that is filled with tissue')
grid on



subplot(nRows,nCols,9)
%plot(summaryTable.totalNonImagedSqMM, summaryTable.autothresh_SNR,'ok')
%xlabel('Non-imaged SqMM')
%ylabel('SNR From auto-thresh')
%grid on



subplot(nRows,nCols,10)
%plot(summaryTable.autothresh_SNR, summaryTable.tThreshSD,'ok')
%xlabel('SNR From auto-thresh')
%ylabel('tThreshSD')
%grid on


subplot(nRows,nCols,11)
plot(x,summaryTable.tThreshSD, pS.basePlotStyle{:})
xlabel('Acquisition #')
ylabel('tThreshSD')
grid on
xlim([1,size(summaryTable,1)])


