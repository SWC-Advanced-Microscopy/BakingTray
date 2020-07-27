function reportrecipeName
    % Report the name of the sample in the recipe alongside the file name of the pStack file
    %
    % Purpose
    % Used to look for cases where the pStack file has the wrong recipe
    % Pulls all pStack files in the current directory and sub-dirs.
    % Run from directory in question. No inputs or outputs. Just prints to
    % screen. 


    % Find all pStackf files
    runDir = pwd;
    pStack_list = dir(fullfile(runDir, '/**/*_previewStack.mat'));

    if isempty(pStack_list)
        fprintf('Found no preview stacks in %s\n',runDir)
        return
    end



    parfor ii=1:length(pStack_list)
        tFile = fullfile(pStack_list(ii).folder,pStack_list(ii).name);

        try
            pStack = pstack_loader(tFile);
            ID=pStack.recipe.sample.ID;

            fprintf('%s \t %s\n', tFile, ID)
        catch ME
            fprintf('RESIZE OF FILE %s FAILED!\n', tFile)
        end
    end


    % internal functions 
    function pStack=pstack_loader(fname)
        load(fname)

