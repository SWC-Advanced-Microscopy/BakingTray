function [slicenow,existing] = resume_GUI_helper(hBT,pathToRecipe)


    %Default outputs
    slicenow=false;
    existing='nothing';

    details = BakingTray.utils.doesPathContainAnAcquisition(pathToRecipe);

    % Print to screen a summary of what is here
    lastSec = details.sections(end);
    YN = {'No','Yes'};
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



    % At this point we need to choose how the resumption itself will proceed. This will depend on the state of the acquisition
    lastSection = details.sections(end);
    if lastSection.completed
        if lastSection.sectionSliced
            nextAction.slice=false;
            nextAction.continueToNextSection=true;
        else
            % User needs to choose whether to:
            %  1a) re-image current section
            %  1b) slice and carry on
        end
    else
        % User needs to choose whether to:
        %  2a) re-image current section from the start
        %  2b) complete the remainder of this section
        %  2c) slice and carry on with the next section
    end

    % TODO for scenario 2b, autoROI will have a problem: the preview image will be partial. 
    % We therefore need some way of getting it to use the ROIs from the section before and not
    % run getNextROIs on the partially imaged section.
    % Initially we can just not allow option 2b for autoROI

    % NEEDS TO BE IN THERE SOMEWHERE
    % Did it complete and cut the last section?
    if details.sections(end).sectionSliced==true
        % Ensure that the Z-stage is at the depth of the last completed sectionplus one section thickness. 
        extraZMove = details.sliceThickness;
    else
        extraZMove=0;
    end
