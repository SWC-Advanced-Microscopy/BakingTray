function varargout=getAllFirstImages(runDir)
    % Loop through all pStack files in a directory and return the first plane of each
    %
    % function out=getAllFirstImages(runDir)
    %
    % Inputs
    % runDir - Either: a) Directory in which to look for files and run.
    %              Or: b) A dir structure with a list of files to process
    %
    % Outputs
    % out - structure of image results. Return file name and first plane


    % Handle arg using private function
    pStack_list = handle_runDir(runDir);
    
    out.fname=[];
    out.im=[];

    for ii=1:length(pStack_list)
        tFile = fullfile(pStack_list(ii).folder,pStack_list(ii).name);
        if ~exist(tFile,'file')
            fprintf('File %s does not exist. Skipping\n', tFile)
            continue
        end
        fprintf('Loading %s\n',tFile)
        load(tFile)

        out(ii).fname = tFile;
        out(ii).im =imresize(pStack.imStack(:,:,1),0.4,'nearest');
    end


    if nargout>0
        varargout{1} = out;
    end