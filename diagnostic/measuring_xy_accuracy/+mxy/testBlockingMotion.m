function testBlockingMotion(linStage,stepSize)
% Measure how long blocking motions take if we use the controller's built-in code
%
% function testBlockingMotion(linStage,stepSize)
%
% step size in mm


for ii=1:10
    blockRelMove(linStage,stepSize)
    stepSize = stepSize * -1;
end


function blockRelMove(linStage,stepSize)
    linStage.relativeMove(stepSize);
    tic
    while 1
        if linStage.isMoving
            fprintf('.')
        else
            fprintf('\n')
            break
        end
    end
    toc