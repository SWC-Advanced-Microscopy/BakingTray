function areEqual = areTestStructuresEqual(structA,structB)
    % Test if two outputs for autoROI.test.runOnStackStruct are identical
    %
    % function areEqual = autoROI.evaluate.areTestStructuresEqual(structA,structB)
    %
    % Purpose
    % For testing one can compare before/after runs of autoROI.test.runOnStackStruct 
    % to ensure that code modifcations did not change the output of the function.
    %
    % Example
    %  OUT_A=autoROI.test.runOnStackStruct(pStack);
    %  OUT_B=autoROI.test.runOnStackStruct(pStack);
    %. autoROI.evaluate.areTestStructuresEqual(OUT_A,OUT_B)



    areEqual = true;

    if ~isequal(structA.report.nonImagedSqMM,structB.report.nonImagedSqMM)
        areEqual = false;
        return
    end

    if ~isequal(structA.report.nPlanesWithMissingTissue,structB.report.nPlanesWithMissingTissue)
        areEqual = false;
        return
    end

    if ~isequal([structA.roiStats.medianForeground],[structB.roiStats.medianForeground])
        areEqual = false;
        return
    end

    if ~isequal([structA.roiStats.meanBoundingBoxSqMM],[structB.roiStats.meanBoundingBoxSqMM])
        areEqual = false;
        return
    end
