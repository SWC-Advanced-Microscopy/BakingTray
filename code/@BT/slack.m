function slack(obj,message)
    % Send Slack messge using Dylan Muir's SendSlackNotification
    %
    % BT.slack(message)
    %
    % If the message string is empty, nothing is sent.

    if isempty(message)
        return
    end

    SLACK = obj.recipe.SLACK;
    if isempty(SLACK) || isempty(SLACK.hook)
        msg = sprintf('No Slack hook defined. BT.slack will do nothing.\n');
        obj.acqLogWriteLine(msg);
        return
    end

    try
        status = BakingTray.slack.SendSlackNotification(SLACK.hook,[SLACK.user,' ', message]);

        if ~strcmp(status,'ok')
            msg = ['Failed to send Slack message with error: ', status];
            obj.acqLogWriteLine(msg);
        end
    catch ME 
        obj.acqLogWriteLine(ME.message)
    end
