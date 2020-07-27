function report_auto_thresh_notes(testDir)
% Exploratory. Report to CLI the smaple name and notes from the auto thresh
%
%  function autoROI.test.report_auto_thresh_notes(testDir)
%
% Purpose
% To see which samples were handled how. Either supply path to the test dir or
% cd to the test dir and run without input args. Makes a plot too.
%
% Inputs
% testDir - path test directory. Optional. 
%
%
% Outputs
% none
%
%
% Rob Campbell - SWC 2020


summaryTable = autoROI.evaluate.getSummaryTable;
if isempty(summaryTable)
    return 
end

% Print to screen key info
ind=1:size(summaryTable,1);
for ii=1:length(ind)
    fprintf('%d/%d %s -- SNR: %0.2f -- %s\n', ...
        ind(ii), length(ind), summaryTable.fileName{ii}, summaryTable.autothresh_SNR(ii), summaryTable.autothresh_notes{ii})
end

% Make a plot
clf

subplot(2,2,1)
plot(ind,summaryTable.autothresh_SNR,'.-k')
ylabel('SNR at chosen threshold')


subplot(2,2,2)
hist(summaryTable.autothresh_SNR,round(length(ind)/2))
[y,x]=hist(summaryTable.autothresh_SNR,round(length(ind)/2));

cy=cumsum(y);
cy=cy/max(cy);
yyaxis right
plot(x,cy,'-ro','linewidth',2,'markerfacecolor',[1,0.5,0.4])



subplot(2,2,3)
plot(summaryTable.autothresh_tThreshSD,summaryTable.autothresh_SNR,'ok','markerfacecolor',[1,1,1]*0.5)
plot(summaryTable.autothresh_tThreshSD,summaryTable.autothresh_SNR,'.')
hold on 

for ii=1:length(ind)
    t=text(summaryTable.autothresh_tThreshSD(ii), summaryTable.autothresh_SNR(ii), num2str(ii));
end
hold off
xlabel('tThreshSD')
ylabel('SNR')
grid
