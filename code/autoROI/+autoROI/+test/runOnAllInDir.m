function varargout = runOnAllInDir(runDir,testDir,settings)
    % Run auto-find test on all structures in runDir
    %
    % function testDirThisSession = autoROI.tests.runOnAllInDir(runDir,settings)
    %
    % Purpose
    % Batch run of autoROI.test.runOnStackStruc
    % Looks for pStack structures in the current directory and all 
    % directories within it. Saves results to a directory called "tests"
    % in the current directory.
    %
    %
    % Inputs
    % runDir - Either: a) Directory in which to look for files and run.
    %              Or: b) A dir structure with a list of files to process
    %
    % Inputs (optional)
    % testDir - where to save the test data. If missing or empty, goes into in to a 
    %           directory called "tests" in the current directory.
    % settings - Structure based on the output of the readSettings file. 
    %            Otherwise, it reads from this file directly.
    %
    %
    % Outputs
    % testDirThisSession - the location of the test directory itself: where data were saved to.
    %
    %
    % Example
    % >> ls
    %   readme.txt stacks     tests 
    % >> autoROI.tests.runOnAllInDir('stacks/twoBrains')
    %
    % Or run on all sub-directories:
    % >> autoROI.tests.runOnAllInDir('stacks')
    %
    % Run with a defined path for the output directory
    % >> autoROI.tests.runOnAllInDir('stacks','/tmp/')


if nargin<1
    fprintf('Please supply directory on which to run\n')
    return
end

if nargin<2 || isempty(testDir)
    testDir = fullfile(pwd,'tests');
end

if nargin<3 || isempty(settings)
    settings = autoROI.readSettings;
end


if ~exist(testDir,'dir')
    success=mkdir(testDir);
    if ~success
        fprintf('Failed to make %s\n',testDir);
        return
    end
end

% Handle arg using private function
pStack_list = handle_runDir(runDir);

testDirThisSession = fullfile(testDir,datestr(now,'yymmdd_HHMM'));
success=mkdir(testDirThisSession);
if ~success
    fprintf('Failed to make %s\n',testDir);
    return
else
    fprintf('Writing test data in directory %s\n', testDirThisSession)

end


% Log the details of this test run
logFname = fullfile(testDirThisSession,'LOG_FILE.txt');
fid=fopen(logFname,'w+');
fprintf(fid,'Starting at %s\n', datestr(now,'yyyy-mm-dd, HH:MM:SS'));
[~, hostname] = system('hostname'); 
fprintf(fid,'Running on machine %s\n', strtrim(hostname));

% Write settings to directory
yaml.WriteYaml(fullfile(testDirThisSession,'settings.yml'),settings);


gitinfo = autoROI.tools.getGitInfo;
fprintf(fid,'Commit %s on %s branch\n', gitinfo.hash, gitinfo.branch);
fclose(fid);
t=tic;

parfor ii=1:length(pStack_list)
    tFile = fullfile(pStack_list(ii).folder,pStack_list(ii).name);
    if ~exist(tFile,'file')
        fprintf('File %s does not exist. Skipping\n', tFile)
        continue
    end
    fprintf('Loading %s\n',tFile)

    pStack = pstack_loader(tFile);
    [~,nameWithoutExtension] = fileparts(pStack_list(ii).name);

    % Do not process if the loaded .mat file does not contain a struct
    if ~isstruct(pStack)
        fid = fopen(fullfile(testDirThisSession,['NOT_A_STRUCT_',nameWithoutExtension]),'w');
        fclose(fid);
        continue
    end

    try
        % Run
        testLog = autoROI.test.runOnStackStruct(pStack,true,settings);

        % Log useful info in first element
        testLog(1).stackFname = tFile; %Into the first element add the file name

        saveFname = fullfile(testDirThisSession,['log_',pStack_list(ii).name]);
        fprintf('Saving data to %s\n', saveFname)
        testlog_saver(saveFname,testLog)% (fullfile(testDirThisSession,['log_',pStack_list(ii).name]),'testLog')
    catch ME
        fid = fopen(fullfile(testDirThisSession,['FAIL_',nameWithoutExtension]),'w');
        fprintf(fid,ME.message);
        fclose(fid);
        fprintf('%s FAILED WITH MESSAGE :\n%s\n',nameWithoutExtension, ME.message)
    end


end


%Log when we finished and how long it took
fid = fopen(logFname,'a+');
fprintf(fid,'Finished at %s. Processed %d acquisitions in %d seconds\n\n', ...
    datestr(now,'yyyy-mm-dd, HH:MM:SS'), length(pStack_list), round(toc(t)) );
fclose(fid);


% Now we generate the summary table in that directory
autoROI.evaluate.genSummaryTable(testDirThisSession)

if nargout>0
    varargout{1}=testDirThisSession;
end

% internal functions 
function pStack=pstack_loader(fname)
    load(fname,'pStack')

function testlog_saver(fname,testLog)
    save(fname,'testLog')
