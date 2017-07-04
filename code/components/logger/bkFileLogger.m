classdef bkFileLogger < handle

% bkFileLogger handles the logging of messages to disk.
% The code for linking this to a concrete class is in loghandler.m
%
% obj=bkFileLogger(fnames,allToScreen,overwrite)
%
% Examples
% 1) log to a file retaining existing contents
%   myLogger = bkFileLogger('logName.csv') 
%
% 2) Log to multiple files, flushing existing contents
%   myLogger = bkFileLogger({'logName1.csv','logName2.csv'},1) 
%
%
% Behavior
% bkFileLogger will by default append lines to files that already exist. 
%
% Rob Campbell - Basel 2016


    properties % (Access=protected)
        fnames  % A string or cell array of strings corresponding to relative or absolute paths 
                % of files to which messages are to be streamed

        fid % numeric vector that is a list of handles to which messages should be streamed. 
                % e.g. could be [1,FID] to display to screen and also write to a file
    end



    methods 

        function obj=bkFileLogger(fnames,overwrite)
            % fnames - string or cell array of strings defining relative or absolute paths to log files
            % overwrite - if true, wipe any data that already exist in fnames before writing
            if nargin<1 | isempty(fnames)
                fnames=[];
            end
            if nargin<2 | isempty(overwrite)
                overwrite=false;
            end

            %Make fnames a cell array if it is not. This is just so it's easier to work with.
            if ischar(fnames)
                fnames = {fnames};
            end

            obj.fnames=fnames;

            %Wipe the files if needed
            obj.openFiles(overwrite);
        end %constructor

        function delete(obj)
            obj.closeFiles
        end %destructor


    end %methods



    methods (Access=protected)
        %open and close file handles
        function openFiles(obj,overwrite)
            if isempty(obj.fnames)
                return
            end

            if nargin<2 | ~overwrite
                permission='a';
            else
                permission='w+';
            end

            for ii=1:length(obj.fnames)
                fname=obj.fnames{ii};

                obj.fid(ii) = fopen(fname,permission);

                if obj.fid(ii)<0
                    fprintf('Failed to open file handle for log file with name %s\n',fname)
                else
                    fprintf('Logging to file %s\n',fname)
                end
            end
        end %openFiles


        function closeFiles(obj)
            if isempty(obj.fid)
                return
            end

            for ii=1:length(obj.fid)
                if obj.fid(ii)>2 %attempt to close if this handle may be a file
                    try
                        success=fclose(obj.fid(ii));
                        if success<0
                            fprintf('Failed to close handle associated with file %s\n', obj.fnames{ii})
                        else
                            fprintf('\nClosed log files\n')
                        end
                    catch exception
                        disp(exception.message) 
                    end %try
                end %if obj.fid
            end %for ii

        end %closeFiles



    end %protected methods

end %close the class
