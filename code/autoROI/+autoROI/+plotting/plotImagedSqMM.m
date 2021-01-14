function plotImagedSqMM(logData)
% Plot imaged sq mm in each section as a line plot
%
% Load the test log and supply as input arg



sqmm = zeros(1,length(logData.roiStats));

for ii=1:length(sqmm)
    sqmm(ii) = sum(logData.roiStats(ii).BoundingBoxSqMM);
end



clf
subplot(2,1,1)
plot(sqmm,'.k-')
hold on
t=[sqmm(1),sqmm];
%plot(t,'.r-')
xlabel('Section #')
ylabel('imaged sqmm')


% Plot percent change from previous section
pChange = [sqmm(1),sqmm];
subplot(2,1,2)

plotDat=(sqmm-circshift(sqmm,1)) ./ circshift(sqmm,1);


plot(plotDat,'.k-')
xlabel('section #')
ylabel('prop. change from previous')
