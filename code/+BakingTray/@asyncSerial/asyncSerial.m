classdef asyncSerial < handle
%%  asyncSerial
%
% Async serial transport shared by hardware components that talk over a serial port.
%
% There is a single command queue and one terminator callback (onSerialData).
% sendAndReceiveSerial places a command on the queue rather than blocking on a
% readline. Replies arrive asynchronously and are matched, in order, to the
% oldest command awaiting a reply. Because nothing blocks the port while waiting,
% a command issued from a button press can no longer collide with an in-flight
% read and be dropped -- it simply queues behind it.
%
% This class is intended to be inherited (e.g. by the laser class). The composing
% class is expected to provide a logMessage method (via loghandler) and to create
% obj.hC (a serialport object) in its connect method before calling setupAsyncSerial.
%
% Rob Campbell - SWC 2026


    properties
        hC  %A handle to the hardware object or port (e.g. COM port) used to
            %control the device.
    end %close public properties


    properties (Hidden)
        % Async serial transport state (see setupAsyncSerial / sendAndReceiveSerial)
        cmdQueue = {}                    % FIFO of pending command structs
        serialReplies                    % containers.Map(id -> reply); made in setupAsyncSerial
        serialInFlight = false           % true while a command awaits its reply
        inFlightId = []                  % id of the in-flight command
        nextCmdId = 1                    % monotonic command id
        serialReplyTimeoutSeconds = 5    % bounded wait for a reply before resync
    end %close hidden properties


    methods

        function setupAsyncSerial(obj)
            % Initialise the command queue and attach the terminator callback.
            % Call this from each subclass connect() AFTER configureTerminator, before
            % any sendAndReceiveSerial call.
            obj.cmdQueue = {};
            obj.serialReplies = containers.Map('KeyType','double','ValueType','char');
            obj.serialInFlight = false;
            obj.inFlightId = [];
            obj.nextCmdId = 1;
            configureCallback(obj.hC,"terminator",@(~,~) obj.onSerialData);
        end % setupAsyncSerial


        function [success,reply]=sendAndReceiveSerial(obj,commandString,waitForReply)
            % Queue a serial command and (optionally) wait for its reply.
            % waitForReply=true spins (via pause, which lets the callback run) until
            % THIS command's reply arrives or we time out; false returns immediately.
            if nargin<3
                waitForReply=true;
            end

            success = false;
            reply = '';

            if isempty(commandString) || ~ischar(commandString)
                obj.logMessage(inputname(1),dbstack,6,sprintf('%s.sendAndReceiveSerial command string not valid.', class(obj)))
                return
            end

            % Enqueue with a unique id so a (possibly nested) waiter can find its reply.
            id = obj.nextCmdId;
            obj.nextCmdId = obj.nextCmdId + 1;
            obj.cmdQueue{end+1} = struct('id',id, 'command',commandString, 'awaitReply',waitForReply);

            obj.pumpSerialQueue % send the head of the queue if the port is free

            if ~waitForReply
                reply=[];
                success=true;
                return
            end

            % Wait for this command's reply. pause() yields so onSerialData can run.
            % NB: pause() flushes MATLAB's whole callback queue (incl. other software's
            % timers, e.g. ScanImage's AsyncSerialQueue), so keep the interval coarse to
            % minimise how often we perturb other subsystems. The real fix is to make the
            % background poller fire-and-forget so it doesn't spin-wait at all.
            t0 = tic;
            while ~isKey(obj.serialReplies,id) && toc(t0) < obj.serialReplyTimeoutSeconds
                pause(0.05)
            end

            if ~isKey(obj.serialReplies,id)
                % Timed out. Drop the stuck transaction and resync the stream.
                msg = sprintf('%s serial command %s did not return a reply\n', class(obj), commandString);
                obj.logMessage(inputname(1),dbstack,6,msg)
                obj.resyncSerial
                return
            end

            reply = obj.serialReplies(id);
            remove(obj.serialReplies,id);

            % If the device echoes the command back, remove it (no-op for non-echoers).
            reply = strrep(reply,commandString,'');
            success = true;
        end % sendAndReceiveSerial


        function pumpSerialQueue(obj)
            % Send the next queued command if nothing is currently awaiting a reply.
            if obj.serialInFlight || isempty(obj.cmdQueue)
                return
            end

            item = obj.cmdQueue{1};
            obj.cmdQueue(1) = [];

            % Flush stale bytes so the next reply we read is the reply to THIS command.
            if obj.hC.NumBytesAvailable>0
                flush(obj.hC,"input")
            end

            writeline(obj.hC,item.command);

            if item.awaitReply
                obj.serialInFlight = true;
                obj.inFlightId = item.id;
            else
                % No reply expected: command complete, send the next one.
                obj.pumpSerialQueue
            end
        end % pumpSerialQueue


        function onSerialData(obj)
            % Terminator callback: a complete line has arrived. Match it to the
            % in-flight command, hand it to the waiter, then send the next command.
            if isempty(obj.hC) || ~isvalid(obj.hC) || obj.hC.NumBytesAvailable==0
                return
            end
            line = readline(obj.hC);

            if ~obj.serialInFlight || strlength(line)==0
                % Orphan/late reply with nothing awaiting it, or empty line. Discard.
                return
            end

            obj.serialReplies(obj.inFlightId) = char(line);
            obj.serialInFlight = false;
            obj.inFlightId = [];

            obj.pumpSerialQueue % send the next queued command
        end % onSerialData


        function resyncSerial(obj)
            % Recover from a desync (called on a reply timeout): drop the in-flight
            % command, flush the input buffer, and continue with anything still queued.
            obj.serialInFlight = false;
            obj.inFlightId = [];
            if ~isempty(obj.hC) && isvalid(obj.hC)
                flush(obj.hC,"input")
            end
            obj.pumpSerialQueue
        end % resyncSerial

    end %close methods

end %close classdef
