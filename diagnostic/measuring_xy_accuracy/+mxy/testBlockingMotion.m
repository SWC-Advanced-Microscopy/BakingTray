function testBlockingMotion(linStage,stepSize)
% Measure how long blocking motions take if we use the controller's built-in code
%
% function testBlockingMotion(linStage,stepSize)
%
% step size in mm

if nargin<2
    stepSize=1;
end

for ii=1:10
    blockRelMove(linStage,stepSize)
    stepSize = stepSize * -1;
end


function blockRelMove(linStage,stepSize)
    curPos = linStage.axisPosition;
    targetPos = curPos + stepSize;
    linStage.relativeMove(stepSize);
    tic
    while 1
        if linStage.isMoving
            curPos = linStage.axisPosition;
            delta=abs(curPos-targetPos);
            fprintf('Pos: %0.4f mm ; Delta: %0.4f mm\n',curPos, delta)
            if delta<0.002 %within a couple of microns
                break
            end
        else
            fprintf('\n')
            break
        end
    end
    toc