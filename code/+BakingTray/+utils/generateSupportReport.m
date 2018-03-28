function generateSupportReport(attemptLaunch,reportFname)
% Generate a .zip file containing a support report for BakingTray
%
% function generateSupportReport(attemptLaunch,reportFname)
%
%
% Purpose
%  Saves useful install info to a zip file. Start ScanImage and BakingTray then run:
%  BakingTray.utils.generateSupportReport
%
% Inputs
% attemptLaunch - False by default. If true, attempt to launch BakingTray and
%                 ScanImage. 
% reportFname - If provided, the report is written to this location. Otherwise a 
%               UI is presented to the user for a location to be chosed. 
% 
%
%



    % Handle default input arguments
    if nargin < 1 || isempty(attemptLaunch)
        attemptLaunch = false;
    end
    
    %Generate default save location
    [~,userPath]=system('echo %USERPROFILE%');
    userDesktopDir = fullfile(userPath(1:end-1),'Desktop');
    defaultFname = ['BakingTray_Report_',  datestr(now,'dd-mm-yyyy_HH-MM'),'.zip'];
    if nargin < 2 || isempty(reportFname)
        [reportFname,pathname] = uiputfile('.zip','Choose path to save report', fullfile(userDesktopDir,defaultFname));
        if reportFname==0
            return
        end
    
        reportFname = fullfile(pathname,reportFname);
    end


    % Log files to zip and delete
    filesToZip = {};
    tempFilesToDelete = {};

    [fpath,fname,fext] = fileparts(reportFname);
    if isempty(fpath)
        fpath = pwd;
    end
    
    if isempty(fname)
        fname = fullfile(userDesktopDir,defaultFname);
    end


    disp('Generating BakingTray report...');
    wb = waitbar(0,'Generating BakingTray report');
    
    try
        % Check if ScanImage is running
        siAccessible = false;
        if evalin('base','exist(''hSI'')')
            siAccessible = true;
        end

        if attemptLaunch && ~siAccessible
            siAccessible = true;
            try
                scanimage;
            catch
                siAccessible = false;
            end
        end

        % Re-attempt to load hSI
        if siAccessible && evalin('base','exist(''hSI'')')
            hSIlocal = evalin('base','hSI');
        end


        % Check if BakingTray is running
        btAccessible = false;
        if evalin('base','exist(''hBT'')')
            btAccessible = true;
        end

        if attemptLaunch && ~btAccessible
            siAccessible = true;
            try
                BakingTray;
            catch
                btAccessible = false;
            end
        end

        % Re-attempt to load hBT
        if siAccessible && evalin('base','exist(''hBT'')')
            hBTlocal = evalin('base','hBT');
        end



        if siAccessible
            try
                % Save currently loaded MDF file
                mdf = most.MachineDataFile.getInstance;
                if mdf.isLoaded && ~isempty(mdf.fileName)
                    filesToZip{end+1} = mdf.fileName;
                end

                % Save current usr and cfg files
                fullFileUsr = fullfile(tempdir,[fname '.usr']);
                fullFileCfg = fullfile(tempdir,[fname '.cfg']);
                fullFileHeader = fullfile(tempdir,'TiffHeader.txt');
                fullFileErr = fullfile(tempdir,'ErrorLog.txt');

                hSIlocal.hConfigurationSaver.usrSaveUsrAs(fullFileUsr,'',1);
                filesToZip{end+1} = fullFileUsr;
                tempFilesToDelete{end+1} = fullFileUsr;

                hSIlocal.hConfigurationSaver.cfgSaveConfigAs(fullFileCfg, 1);
                filesToZip{end+1} = fullFileCfg;
                tempFilesToDelete{end+1} = fullFileCfg;
                
                fileID = fopen(fullFileHeader,'W');
                fwrite(fileID,hSIlocal.mdlGetHeaderString(),'char');
                
                fclose(fileID);
                filesToZip{end+1} = fullFileHeader;
                tempFilesToDelete{end+1} = fullFileHeader;
                
                errN = numel(hSIlocal.errorLog);
                if errN
                    fileID = fopen(fullFileErr,'W');
                    
                    for i = 1:errN
                        e = hSIlocal.errorLog{i};
                        fprintf(fileID, 'Logged error that occurred at %s:\n%s\n\n\n',datestr(e{1}),e{2}.getReport('extended'));
                    end

                    fclose(fileID);
                    filesToZip{end+1} = fullFileErr;
                    tempFilesToDelete{end+1} = fullFileErr;
                end
            catch
                disp('Warning: SI could not be accessed properly');
            end
        end
        

        % Add the BakingTray commit sha to filesToZip
        gitDir = fullfile(BakingTray.settings.installLocation,'.git');
        if exist(fullfile(gitDir,'HEAD'), 'file')
            fil = fopen(fullfile(gitDir,'HEAD'));
            try
                branchDir = fgetl(fil);
                fclose(fil);
            catch
                fclose(fil);
            end
            
            commitSHAfile = fullfile(gitDir,branchDir(6:end));
            
            if exist(commitSHAfile, 'file')
                filesToZip{end+1} = commitSHAfile;
            else
                fprintf('Failed to find commit SHA file %s\n', commitSHAfile)
            end
        end
        
        waitbar(0.3,wb); drawnow


        % Open a temporary text file into which we will dump a variety of information
        tmpTxtFileName = fullfile(tempdir,[fname '_system_details.txt']);

        % Record CPU info
        cpuInfo = most.idioms.cpuinfo;
        dumpToTXT(tmpTxtFileName, cpuInfo);
        tempFilesToDelete{end+1} = tmpTxtFileName;


        % Record current path
        dumpToTXT(tmpTxtFileName, struct('matlabCurrentPath', path) );

        % Record MATLAB and Java versions
        dumpToTXT(tmpTxtFileName, struct('matlabVersion', version) );
        dumpToTXT(tmpTxtFileName, struct('javaVersion', version('-java')) );

        % Record Windows version
        [~,winVer] = system('ver');
        dumpToTXT(tmpTxtFileName, struct('WindowsVersion', winVer) );

        % Get memory info
        [~,sysMem] = memory;
        mem.TotalRAMinGB = sysMem.PhysicalMemory.Total / 1024^3;
        mem.AvailableRAMinGB = sysMem.PhysicalMemory.Available / 1024^3;
        dumpToTXT(tmpTxtFileName,mem)

        % Get OpenGL information
        openGLInfo = opengl('data');
        dumpToTXT(tmpTxtFileName,openGLInfo)


        waitbar(0.5,wb); drawnow


        % Get current session history
        jSessionHistory = com.mathworks.mlservices.MLCommandHistoryServices.getSessionHistory;
        mSessionHistory = char(jSessionHistory);

        % Get current current text from the command window
        cmdWinDoc = com.mathworks.mde.cmdwin.CmdWinDocument.getInstance;
        jFullSession   = cmdWinDoc.getText(cmdWinDoc.getStartPosition.getOffset,cmdWinDoc.getLength);
        mFullSession = char(jFullSession);
      
        
        try
            %save separate files for convenience
            fn = fullfile(tempdir,'mSessionHistory.txt');
            fidt = fopen(fn,'w');
            arrayfun(@(x)fprintf(fidt,'%s\n', strtrim(mSessionHistory(x,:))),1:size(mSessionHistory,1));
            fclose(fidt);
            tempFilesToDelete{end+1} = fn;
            filesToZip{end+1} = fn;

            fn = fullfile(tempdir,'mFullSession.txt');
            fidt = fopen(fn,'w');
            fprintf(fidt,'%s', mFullSession);
            fclose(fidt);
            tempFilesToDelete{end+1} = fn;
            filesToZip{end+1} = fn;
        catch
        end
        

        % Copy the BakingTray settings files
        waitbar(0.7,wb); drawnow
        settingsFiles = dir(BakingTray.settings.settingsLocation);
        if ~isempty(settingsFiles)
            for ii=1:length(settingsFiles)
                fname = settingsFiles(ii).name;
                if startsWith(fname,'.')
                    continue
                end
                fullPathToFname = fullfile(BakingTray.settings.settingsLocation, fname);
                filesToZip{end+1} = fullPathToFname;
            end
        else
            fprintf('Failed to finding settings files at %s\n', BakingTray.settings.settingsLocation)
        end

        waitbar(0.9,wb); drawnow

        % Add the tmp file to the zip list
        filesToZip{end+1} = tmpTxtFileName;

        % Zip important information
        zip(reportFname, filesToZip);

        % Clean directory
        cellfun(@(f)delete(f),tempFilesToDelete);
        
        waitbar(1,wb);

        disp('BakingTray report finished');
    catch ME
        delete(wb);
        most.idioms.reportError(ME);
    end
    
    delete(wb); % delete the waitbar
end




function dumpToTXT(fname,data)
    fid = fopen(fname,'a');
    if isstruct(data)
        f = fields(data);
        for ii=1:length(f)
            theseData = data.(f{ii});
            fprintf(fid,'%s - ', f{ii});
            if ischar(theseData)
                fprintf(fid,'%s\n',theseData);
            end
            if isnumeric(theseData)
                fprintf(fid,'%0.2f\n',theseData);
            end
        end
    else
        fprintf('Data are not a struct\n')
    end
    fclose(fid);
end