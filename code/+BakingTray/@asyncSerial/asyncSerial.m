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
        inFlightHandler = []             % handler for the in-flight command (fire-and-forget), or []
        inFlightCommand = ''             % command string of the in-flight command (used to strip echoes)
        inFlightSince = NaT              % when the in-flight command was sent (for the stale watchdog)
        nextCmdId = 1                    % monotonic command id
        serialReplyTimeoutSeconds = 5    % bounded wait for a reply before resync
        serialTransportOK = true         % false once the port has gone away (see serialTransportFailed)
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
            obj.inFlightHandler = [];
            obj.inFlightCommand = '';
            obj.inFlightSince = NaT;
            obj.nextCmdId = 1;
            obj.serialTransportOK = true; % a fresh port: forget any earlier failure
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
            obj.cmdQueue{end+1} = struct('id',id, 'command',commandString, 'awaitReply',waitForReply, 'handler',[]);


            % Send the next queued command
            if ~obj.pumpSerialQueue
                % The transport is gone, so the command was never sent and nothing
                % can ever reply to it. Fail now rather than spin-waiting out the
                % full timeout twice for a reply that can not come.
                return
            end

            if ~waitForReply
                reply=[];
                success=true;
                return
            end

            % Wait for this command's reply. pause() yields so onSerialData can run.
            % NB: pause() flushes MATLAB's whole callback queue (incl. other software's
            % timers, e.g. ScanImage's AsyncSerialQueue), so keep the interval coarse to
            % minimise how often we perturb other subsystems.
            % If a stalled command ahead of us is blocking the queue, the first wait
            % times out; resyncSerial then drops the stall, flushes, and advances the
            % queue, so we wait once more and our command still gets its reply.
            gotReply = false;
            for attempt = 1:2
                t0 = tic;
                while ~isKey(obj.serialReplies,id) && toc(t0) < obj.serialReplyTimeoutSeconds
                    pause(0.05)
                end
                if isKey(obj.serialReplies,id)
                    gotReply = true;
                    break
                end
                obj.resyncSerial
            end

            if ~gotReply
                msg = sprintf('%s serial command %s did not return a reply\n', class(obj), commandString);
                obj.logMessage(inputname(1),dbstack,6,msg)
                return
            end

            % The reply has already had any command echo stripped in onSerialData.
            reply = obj.serialReplies(id);
            remove(obj.serialReplies,id);
            success = true;
        end % sendAndReceiveSerial


        function ok = pumpSerialQueue(obj)
            % Send the next queued command if nothing is currently awaiting a reply.
            %
            % Outputs
            % ok - false if the serial transport has gone away and the command could
            %      therefore not be sent. True otherwise, including when there was
            %      nothing to send or the queue is held up behind an in-flight command.
            %


            % Nothing here may assume the port is usable: MATLAB leaves a serialport
            % object valid after the underlying COM port disappears (a USB serial
            % adapter that re-enumerated, the device switched off) and every access
            % then throws "Object must be connected to the serial port". That must not
            % escape into a poll timer (which MATLAB then stops) or into bake.

            ok = true;

            if isempty(obj.hC) || ~isvalid(obj.hC)
                obj.serialTransportFailed('the serial port object no longer exists')
                ok = false;
                return
            end

            if obj.serialInFlight || isempty(obj.cmdQueue)
                return
            end

            item = obj.cmdQueue{1};
            obj.cmdQueue(1) = [];

            try
                % Flush stale bytes so the next reply we read is the reply to THIS command.
                if obj.hC.NumBytesAvailable>0
                    flush(obj.hC,"input")
                end
            catch ME
                obj.serialTransportFailed(ME.message)
                ok = false;
                return
            end

            % Publish the in-flight state BEFORE the write. MATLAB can service the
            % port's terminator callback from inside writeline, and onSerialData
            % discards as an orphan any reply that arrives while serialInFlight is
            % still false. A reply landing in that window was therefore thrown away
            % and the command could only time out.
            if item.awaitReply
                obj.serialInFlight = true;
                obj.inFlightId = item.id;
                obj.inFlightHandler = item.handler;
                obj.inFlightCommand = item.command;
                obj.inFlightSince = datetime('now');
            end

            try
                writeline(obj.hC,item.command);
            catch ME
                % The command never went out. Clear the in-flight state we just set
                % so the queue can not stall waiting for a reply to it.
                if item.awaitReply
                    obj.serialInFlight = false;
                    obj.inFlightId = [];
                    obj.inFlightHandler = [];
                    obj.inFlightCommand = '';
                    obj.inFlightSince = NaT;
                end
                obj.serialTransportFailed(ME.message)
                ok = false;
                return
            end

            if ~item.awaitReply
                % No reply expected: command complete, send the next one.
                % NB: if a reply arrived during writeline above, onSerialData has
                % already run and pumped the queue itself, so there is nothing to do
                % here for the awaitReply case.
                ok = obj.pumpSerialQueue;
            end
        end % pumpSerialQueue


        function serialTransportFailed(obj,reason)
            % The serial transport has failed: the port object is gone, or the COM
            % port itself has disappeared. Only a reconnect can fix either, so drop
            % everything queued (none of it can be sent) and clear the in-flight
            % state so the queue is not left stalled.
            %
            % The failure is reported once per episode. A dead port fails on every
            % poll tick, and one line every poll period would bury everything else in
            % the console.
            %
            % Subclasses override this to also mark the component as disconnected,
            % and must call this superclass method. See laser.serialTransportFailed.
            %
            % Inputs
            % reason - [string] why the transport is considered dead. Usually the
            %          message of the exception that was caught.

            obj.serialInFlight = false;
            obj.inFlightId = [];
            obj.inFlightHandler = [];
            obj.inFlightCommand = '';
            obj.inFlightSince = NaT;
            obj.cmdQueue = {};

            if obj.serialTransportOK
                fprintf('\n *** %s has lost serial comms with %s: %s\n', ...
                    class(obj), obj.serialPortName, reason)
                fprintf(' *** Reconnect the device to restore communication.\n\n')
            end

            % Only a successful reconnect (which calls setupAsyncSerial) clears this.
            obj.serialTransportOK = false;
        end % serialTransportFailed


        function portName = serialPortName(obj)
            % Name of the port we are (or were) talking to, for error messages.
            % Returns '<unknown port>' if it can not be read back, which is possible
            % because we ask precisely when the port has gone wrong.
            portName = '<unknown port>';
            if isempty(obj.hC) || ~isvalid(obj.hC)
                return
            end
            try
                portName = obj.hC.Port;
            catch
            end
        end % serialPortName


        function onSerialData(obj)
            % Terminator callback: a complete line has arrived. Match it to the
            % in-flight command. If that command supplied a handler (fire-and-forget)
            % we call it to parse the reply; otherwise we store the reply for the
            % spin-waiter in sendAndReceiveSerial. Then send the next command.
            try
                if isempty(obj.hC) || ~isvalid(obj.hC) || obj.hC.NumBytesAvailable==0
                    return
                end
                line = readline(obj.hC);
            catch ME
                % This is a callback, so an error here escapes into MATLAB's event
                % queue rather than to any caller of ours. Handle it locally.
                obj.serialTransportFailed(ME.message)
                return
            end

            if ~obj.serialInFlight
                % Orphan/late reply with nothing awaiting it. Discard.
                return
            end

            handler = obj.inFlightHandler;
            id = obj.inFlightId;
            command = obj.inFlightCommand;
            obj.serialInFlight = false;
            obj.inFlightId = [];
            obj.inFlightHandler = [];
            obj.inFlightCommand = '';
            obj.inFlightSince = NaT;

            if strlength(line)==0
                % Empty/stray line: a failed read for this command. Don't update the
                % cache, but DO advance so the queue can't stall on empty frames.
                obj.pumpSerialQueue
                return
            end

            % Some devices (e.g. the Coherent Chameleon) echo the command back before
            % (or instead of) their reply. Strip any echo of THIS command from the line
            % so the handler / waiter sees only the reply. This is a no-op for devices
            % that don't echo (their reply never contains the command as a substring).
            reply = strrep(char(line),command,'');

            if isempty(handler)
                obj.serialReplies(id) = reply; % sync path: hand to the waiter
            else
                try
                    handler(reply);            % fire-and-forget path: parse+cache
                catch ME
                    fprintf('%s serial reply handler failed: %s\n', class(obj), ME.message)
                end
            end

            obj.pumpSerialQueue % send the next queued command
        end % onSerialData


        function enqueueRead(obj,command,handler)
            % Fire-and-forget read: queue a command whose reply is parsed by 'handler'
            % in onSerialData. Returns immediately -- nothing spin-waits -- so the
            % background poller does not pump the event queue.
            id = obj.nextCmdId;
            obj.nextCmdId = obj.nextCmdId + 1;
            obj.cmdQueue{end+1} = struct('id',id, 'command',command, 'awaitReply',true, 'handler',handler);

            obj.pumpSerialQueue % send the head of the queue if the port is free
        end % enqueueRead


        function resyncSerial(obj)
            % Recover from a desync (called on a reply timeout): drop the in-flight
            % command, flush the input buffer, and continue with anything still queued.
            obj.serialInFlight = false;
            obj.inFlightId = [];
            obj.inFlightHandler = [];
            obj.inFlightCommand = '';
            obj.inFlightSince = NaT;
            if isempty(obj.hC) || ~isvalid(obj.hC)
                obj.serialTransportFailed('the serial port object no longer exists')
                return
            end
            try
                flush(obj.hC,"input")
            catch ME
                % A reply timeout on a port that has gone away lands here, so this is
                % the second place the dead transport must not be allowed to throw.
                obj.serialTransportFailed(ME.message)
                return
            end
            obj.pumpSerialQueue
        end % resyncSerial


        function resyncStaleInFlight(obj)
            % Watchdog for fire-and-forget reads: if a command has been awaiting its
            % reply for longer than the timeout (a lost reply, with no spin-waiter to
            % recover it), drop it and resync so the queue can advance. Intended to be
            % called periodically, e.g. from a status poll.
            if obj.serialInFlight && ~isnat(obj.inFlightSince) && ...
                    seconds(datetime('now') - obj.inFlightSince) > obj.serialReplyTimeoutSeconds
                obj.resyncSerial
            end
        end % resyncStaleInFlight

    end %close methods

end %close classdef
