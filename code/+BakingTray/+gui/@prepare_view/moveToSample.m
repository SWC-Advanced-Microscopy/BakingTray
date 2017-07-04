function moveToSample(obj,~,~)
    % Move to the middle of the sample
    %
    % function BT.moveToSample(obj,event,~)

    
    [~,xMSG] = obj.isSafeToMove(obj.model.xAxis);
    [~,yMSG] = obj.isSafeToMove(obj.model.yAxis);

    if ~isempty(xMSG) || ~isempty(yMSG)
        if ~strcmp(xMSG,yMSG)
            msg=[xMSG,yMSG];
        else
            msg=xMSG;
        end
        warndlg(msg,'')
        return
    end

    %The middle of the sample:

    R=obj.model.recipe;

    X = R.FrontLeft.X-R.mosaic.sampleSize.X/2;
    Y = R.FrontLeft.Y-R.mosaic.sampleSize.Y/2;

    obj.model.moveXYto(X,Y);

end
