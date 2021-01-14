function compareResults(dirReference,dirTest,varargin)
% Compare fnameB to fnameA using plots and stats printed to screen
%
%  function autoROI.test.compareResults(dirReference,dirTest)
%
% 
% Inputs
% dirReference - path to first file, which will correspond to the "initial" data
% dirTest - path to second file, which will correspond to the "new" state. 
%
% Optional Inputs (param/val pairs)
% excludeIndex - vector of acquisition idexes to exclude from plotting.
%
%
% Outputs
% none
%
%
% Rob Campbell - SWC 2020


[cTable,refTable,testTable] = autoROI.evaluate.genComparisonTable(dirReference,dirTest);

if isempty(cTable)
    return
end


params = inputParser;
params.CaseSensitive=false;
params.addParameter('excludeIndex',[],@isnumeric)

params.parse(varargin{:})
excludeIndex = params.Results.excludeIndex;


% Optionally exclude indexes
if ~isempty(excludeIndex)
    cTable(excludeIndex,:)=[];
    refTable(excludeIndex,:)=[];
    testTable(excludeIndex,:)=[];
end


% Issue some reports to screen
f=find(cTable.d_numUnprocessedSections>0);
if isempty(f)
    for ii=1:length(f)
        fprintf('GOOD -- %d/%d. %s now has fewer unprocessed sections: %d -> %d\n', ...
            f(ii), size(refTable,1), refTable.fileName{f(ii)}, ...
            refTable.numUnprocessedSections(f(ii)), testTable.numUnprocessedSections(f(ii)) )
    end
end

f=find(cTable.d_numUnprocessedSections<0);
if isempty(f)
    for ii=1:length(f)
        fprintf('BAD -- %d/%d. %s now has more unprocessed sections: %d -> %d\n', ...
            f(ii), size(refTable,1), refTable.fileName{f(ii)}, ...
            refTable.numUnprocessedSections(f(ii)), testTable.numUnprocessedSections(f(ii)) )
    end
end


% Get the plot settings
pS = plotSettings;


clf

subplot(3,2,[1,2])
plot(cTable.d_totalNonImagedSqMM, pS.basePlotStyle{:})
hold on 
plot(xlim,[0,0],'k:')
grid on
hold off
xlabel('Acquisition #')
ylabel('ref minus test square mm missed')
title('\Delta Total square mm missed (higher better)')
xlim([1,size(refTable,1)])


subplot(3,2,3)
plot(cTable.d_totalExtraSqMM, pS.basePlotStyle{:})
hold on 
plot(xlim,[0,0],'k:')
grid on
hold off
xlabel('Acquisition #')
ylabel('ref minus test square mm extra')
title('Total sq mm extra -- pixels imaged more than once (lower better)')
xlim([1,size(cTable,1)])

subplot(3,2,4)
plot(cTable.d_maxExtraSqMM, pS.basePlotStyle{:})
hold on 
plot(xlim,[0,0],'k:')
grid on
hold off
xlabel('Acquisition #')
ylabel('ref minus test square mm extra')
title('Largest square mm increase (lower better)')
xlim([1,size(cTable,1)])

subplot(3,2,5)
plot(cTable.d_totalImagedSqMM, pS.basePlotStyle{:})
hold on 
plot(xlim,[0,0],'k:')
grid on
hold off
xlabel('Acquisition #')
ylabel('ref minus test total ROI sq mm')
title('Total ROI sq mm')
xlim([1,size(cTable,1)])



