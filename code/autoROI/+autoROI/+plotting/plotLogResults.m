function out=plotLogResults(data)

% plot stats log results from individual pStacks or experiments in useful ways 
% UNDER CONSTRUCTION







% cat all the histograms together that are used for calculating the SD
n=data.roiStats(1).statsSD.statsGMM.hist.n;
x=data.roiStats(1).statsSD.statsGMM.hist.x;
n = repmat(n,length(data.roiStats),1);
x = repmat(x,length(data.roiStats),1);
for ii=1:size(n,1)
    n(ii,:)=data.roiStats(ii).statsSD.statsGMM.hist.n;
    x(ii,:)=data.roiStats(ii).statsSD.statsGMM.hist.x;
end

out.x = x;
out.n = n;