function [slicenow,existing] = resume_GUI_helper(hBT,pathToRecipe)
    % helper function of BT.resumeAcquisition
    %
    % function [slicenow,existing] = resume_GUI_helper(hBT,pathToRecipe)
    %
    % Purpose
    % This function examines the current acquisition state and determines
    % what options are available for resuming. It brings up a simple GUI
    % for the user to choose an option. It then returns the actions needed
    % to implement this in the form of its two output arguments. 
    %
    % Inputs
    % hBT - instance of class BT
    % pathToRecipe - path to acquisition we want to resume
    %
    % Outputs
    % slicenow - the "slicenow" input arg of BT.resumeAcquisition
    % existing - the "existing" input arg of BT.resumeAcquisition
    %
    % If slicenow is NaN, BT.resumeAcquisition uses this as
    % a flag to bail out and not conduct the resumption.
    %
    %
    % Rob Campbell - SWC July 2020


    %Default outputs
    slicenow=false;
    existing='nothing';

    % Extract info about this acquisition
    details = BakingTray.utils.doesPathContainAnAcquisition(pathToRecipe);

    % Define some useful variable
    msgBoxName = 'Acquisition resume'; % Message box name: printed in window title-bar
    lastSec = details.sections(end);   % convenience
    YN = {'No','Yes'};                 % used to build the on-screen message


    % Print to screen a summary of what is here
    msg = sprintf(['\n Details:\n  Path: %s\n  # Sections: %d\n  Last section #: %d\n', ...
                    '  Last section completed: %s\n  Last section cut: %s\n', ...
                    '  Scan mode: %s\n\n'
                  ], ...
        pathToRecipe, ...
        length(details.sections), ...
        lastSec.sectionNumber, ...
        YN{lastSec.allPositionsImaged+1}, ...
        YN{lastSec.sectionSliced+1}, ...
        details.scanmode);

    fprintf(msg)



    if lastSec.sectionSliced
        % The last section was sliced and so all positions must also have been imaged.
        % Options are either to carry on with imaging the next section ot to bail out.
        msg = sprintf(['The last section completed and was sliced.\n', ...
                    'Do you want to carry on imaging the next section?\n']);
        reply = questdlg(msg,msgBoxName,'Yes','No','No');
        switch reply
            case 'Yes'
                slicenow=false;
                existing='nothing';
            case 'No'
                slicenow=nan;
        end
        return
    end

    % If we are here, the last section was sliced but we don't know whether
    % all positions were imaged. Even if they were, we don't know that the
    % user wants to keep the data.

    if lastSec.allPositionsImaged
        msg = sprintf(['The last section was not sliced but all tile positions were imaged.\n', ...
                       'Do you want to:\n', ...
                       'A) Re-acquire the last section then carry on\n', ...
                       'B) Slice, removing the last section, then carry on\n', ...
                       'C) Nothing']);
        reply = questdlg(msg,msgBoxName,'A','B','C','C');

        switch reply
            case 'A'
                slicenow=false;
                existing='reimage';
             case 'B'
                slicenow=true;
                existing='nothing';
            case 'C'
                slicenow=nan;
        end

    else
        % If we are here, it means the acquisition stopped midway through the last section. 
        % It won't have cut if this happens.

        % TODO -- we also want to offer the choice of resuming from the last imaged tile. 
        % However, autoROI will have a problem with this as the preview image will be partial. 
        % We therefore need some way of getting it to use the ROIs from the section before and not
        % run getNextROIs on the partially imaged section.
        % Initially we can just not allow option 2b for autoROI

        msg = sprintf(['The last section was partially imaged.\n', ...
                    'Do you want to:\n', ...
                    'A) Re-acquire the last section from the start then carry on\n', ...
                    'B) Slice, leaving the last section partially imaged, then carry on\n', ...
                    'C) Nothing']);

        reply = questdlg(msg,msgBoxName,'A','B','C','C');

        switch reply
            case 'A'
                slicenow=false;
                existing='reimage';
             case 'B'
                slicenow=true;
                existing='nothing';
            case 'C'
                slicenow=nan;
        end
    end
