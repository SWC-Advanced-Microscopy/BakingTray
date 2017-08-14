classdef (Abstract) loghandler < handle


    % The log handler class provides methods and properties for 
    % integrating a bk_logger object into a concrete class. 
    % This must be inherited by a concrete class in order to function.
    %
    % For example, the linearcontroller class inherits loghandler
    % so that linear stage controller concrete classes, such C891, 
    % have access to methods that will handle error logging. These
    % methods work on a bk_logger object attached to an instance
    % of C891 as a property. The methods simplify the process of 
    % choosing what to display to screen, error handling, etc. 

    properties 
        %There are 5 levels of log message (see bk_logger.bk_logger)
        %Setting the following to 1 would cause everything to be logged.
        %Setting to 5 would cause only the most serious errors to be logged.

        logMessageThreshFile = 2     % Display threshold for file
        logMessageThreshScreen = 4   % Display threshold for screen
    end


    properties (Access=protected)
        loggerObject %The logger object is attached here
        loggerObjectType='bkFileLogger' %logger objects should be of this type
        displayUrgentMessagesThresh=4 %Messages at or above this threshold are displayed to screen even if no logger is attached

        %Define the strings associate with each message ID index.
        %progressively more serious events should be at higher indexes.
        MSGID={'MSG#5', 'MSG#4', 'MSG#3', 'MSG#2', 'MSG#1', 'ERR', 'FAILURE'}
    
        % * First we have five granularities of message detail: MSG#5 to MSG#1
        %
        % * Errors are things that have gone wrong, but should not be fatal.
        %   Events that might cause very small quantities of data loss might
        %   classify as an error.
        %
        % * Failure indicates a condition that is serious. Events that might 
        %   cause cessation of acquisition, inability to start acquisition,


    end



    methods 

        function attachLogObject(obj,loggerObject)
            %Attach log object 
            if ~isa(loggerObject,obj.loggerObjectType)
                fprintf('Can not attach object of class %s. Must be a %s object\n',...
                    class(loggerObject),obj.loggerObjectType)
                return
            end

            if length(loggerObject)>1
                fprintf('loggerObject must be a scalar. Not attaching.\n')
                return
            end

            if ~isempty(obj.loggerObject)
                fprintf('A log object is already attached. Detach it first with the detachLogObject method.\n')
                return
            end

            obj.loggerObject=loggerObject;
            obj.logMessage('loghandler',dbstack,5,'ATTACH LOGGER');
        end % attachLogObject


        function detachLogObject(obj,keepLoggerOpen)
            %Close files (by default) and detaches log object
            % function detachLogObject(obj,keepLoggerOpen)
            %
            % keepLoggerOpen is 0 by default
            if nargin<2
                keepLoggerOpen=0;
            end

            if isempty(obj.loggerObject)
                return
            end

            if isvalid(obj.loggerObject)
                obj.logMessage('loghandler',dbstack,5,'DETACH LOGGER')
            else
                fprintf('Cleaning up partially removed logger object\n')
            end

            try 
                if ~keepLoggerOpen & isvalid(obj.loggerObject)
                    delete(obj.loggerObject);
                end
            catch
                fprintf('Failed to gracefully delete loggerObject\n')
            end
            obj.loggerObject=[];
        end % detachLogObject


        function logMessage(obj,callerObjectName,dbStackOutput,msgID,msg)
            %
            %  logMessage(callerObjectName, dbStackOutput, msgID, msg)
            %
            % Inputs 
            % callerObjectName - a string defining the name of the caller object
            % dbStackOutput - the output of the dbstack command run from the caller method
            % msgID - This is a scalar that is mapped to a short message ID string that can 
            %         be use to tag messages for easier searching. if msgID is -1, the nothing
            %         is done. 
            % msg - an optional message string
            %
            % e.g.
            % bk_loggger.log(inputname(1),dbstack,[],'optionalMessageString')
            %
            % Prints messages in the form:
            % MSGID,ddmm77-HHMMSS,callerObject,method,message


            if msgID==-1
                return
            end

            if nargin<4 || isempty(msgID)
                msgID=1;
            end

            if nargin<5 || isempty(msg)
                msg='';
            end


            %Get the dbstack chain
            if msgID<6 %unimportant messages have no line numbers
                db = dbStackOutput(1).name;
                if length(dbStackOutput)>1
                    for ii=2:length(dbStackOutput)
                        db = [db,' -> ',dbStackOutput(ii).name];
                    end
                end
            else %message is important so it has line numbers
                db = sprintf('%s{%d}',dbStackOutput(1).name,dbStackOutput(1).line);
                if length(dbStackOutput)>1
                    for ii=2:length(dbStackOutput)
                        N = sprintf('%s{%d}',dbStackOutput(ii).name,dbStackOutput(ii).line);
                        db = [db,' -> ',N];
                    end
                end
            end


            %Show the message to screen if appropriate
            if msgID >= obj.logMessageThreshScreen
                spaces=repmat(' ',length(obj.MSGID)-msgID,1);
                fprintf('%s%s -- %s -- [%s,%s]\n', spaces, obj.returnMSGID(msgID), msg, callerObjectName, db)
            end

            %Return if no logger is attached for handling logging to a file
            if isempty(obj.loggerObject)
                return
            end

            %Log the message to one or more files as needed
            if msgID >= obj.logMessageThreshFile

                msgString = sprintf('%s,%s,%s,%s,%s', ... 
                    obj.returnMSGID(msgID), datestr(now,'yymmdd-HHMMSS'), ... 
                    callerObjectName, dbStackOutput.name, msg);

                for ii=1:length(obj.loggerObject.fid)
                    H=obj.loggerObject.fid(ii);
                    if H>0
                        fprintf(H,'%s\n',msgString);
                    end
                end %ii=1:length...
            end 

        end %logMessage

    end %methods


    methods (Access=private)
        function MSGID = returnMSGID(obj,id)
            try
                MSGID = obj.MSGID{id};
            catch exception
                disp(exception)
                MSGID = obj.MSGID{1};
            end
        end
    end
end