function out = batchDir(runDir)
    % function [tThresh,stats] = autoROI.autoThresh.batchDir(runDir)
    %
    % Run on all in directory and retun a structure with the results





    pStack_list = dir(fullfile(runDir, '/**/*_previewStack.mat'));

    if isempty(pStack_list)
        fprintf('Found no preview stacks in %s\n',runDir)
        return
    end

    for ii=1:length(pStack_list)
        tFile = fullfile(pStack_list(ii).folder,pStack_list(ii).name);
        fprintf('\n\n\n  ****   %d/%d Loading %s ****\n\n', ii, length(pStack_list), tFile)
        pStack = pstack_loader(tFile);
        [~,nameWithoutExtension] = fileparts(pStack_list(ii).name);

        [out(ii).thresh,out(ii).stats]=autoROI.autothresh.run(pStack,false);

        out(ii).nameWithoutExtension=nameWithoutExtension;
        out(ii).fullPath=tFile;
        fprintf('\n  ****   %d/%d FINISHED %s ****\n\n', ii, length(pStack_list), tFile)
        pause
    end


function pStack=pstack_loader(fname)
    load(fname)