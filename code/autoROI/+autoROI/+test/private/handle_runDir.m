function pStack_list = handle_runDir(runDir)

    % Process the runDir argument for runOnAllInDir
    if ischar(runDir)
        % runDir should be a path to directory that contains pStack files.
        % Find those files and assign them to a dir structure.
        if ~exist(runDir,'dir')
            fprintf('%s is not a valid directory in the path\n', runDir)
            return
        end
        pStack_list = dir(fullfile(runDir, '/**/*_previewStack.mat'));

        if isempty(pStack_list)
            fprintf('Found no preview stacks in %s\n',runDir)
            return
        end
    elseif isstruct(runDir)
        % runDir is a directory structure containing paths to pStack files
        fprintf('%s is running analysis over %d files provided in dir structure\n', ...
            mfilename, length(runDir))
        pStack_list = runDir;
    end
