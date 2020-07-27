function resizeAllInDir(runDir,targetMicsPix)
    % Perform resize on all pStack files in a directory
    %
    % function autoROI.tools.resizeAllInDir(runDir,targetMicsPix)
    %
    % Purpose
    % Batch run of autoROI.tools.resizePStack
    % Looks for pStack structures in the current directory and all 
    % directories within it. **REPLACES EXISTING FILES!**
    %
    %
    % Inputs (optional)
    % runDir - directory in which to look for files and run. If missing, 
    %          the current directory is used.
    % micsPixTarget - the number of microns per pixel to resize to 
    %
    %
    % Example
    % >> ls
    % >> autoROI.tools.resizeAllInDir('stacks/twoBrains',20)
    %
    % Or run on all sub-directories:
    % >> autoROI.tools.resizeAllInDir('stacks',20)




    % Find all pStackf files

    pStack_list = dir(fullfile(runDir, '/**/*_previewStack.mat'));

    if isempty(pStack_list)
        fprintf('Found no preview stacks in %s\n',runDir)
        return
    end



    parfor ii=1:length(pStack_list)
        tFile = fullfile(pStack_list(ii).folder,pStack_list(ii).name);

        try
            fprintf('Loading %s\n',tFile)
            pStack = pstack_loader(tFile);

            pStack = autoROI.tools.resizePStack(pStack,targetMicsPix);

            pstack_saver(tFile,pStack)
        catch ME
            fprintf('RESIZE OF FILE %s FAILED!\n', tFile)
        end
    end


    % internal functions 
    function pStack=pstack_loader(fname)
        load(fname)

    function pstack_saver(fname,pStack)
        save(fname,'pStack')
