function OUT=measureTilingAccuracy(hBT,pos,nTimes)
% 
% Run through tile pattern, pos, nTimes and save
% data to disk indicating where the stage went to 
% and where it should have gone

if nargin<3
    nTimes=1;
end
nPos = length(pos);
OUT = ones(length(pos)*nTimes,4);

n=1;
for NN = 1:nTimes
    
    if nTimes>1
        fprintf('Doing rep %d/%d\n',NN,nTimes)
    end

    hBT.moveXYto(pos(1,1),pos(1,2), true);
    pause(0.2)

    for ii=1:nPos
        hBT.moveXYto(pos(ii,1),pos(ii,2), true);
        [xP,yP]=hBT.getXYpos;
        OUT(n,1)=pos(ii,1);
        OUT(n,2)=pos(ii,2);
        OUT(n,3)=xP;
        OUT(n,4)=yP;
        n=n+1;
    end
    pause(0.2)
end

