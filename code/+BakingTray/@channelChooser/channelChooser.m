classdef channelChooser < handle
    % BakingTray.channelChooser
    %
    % Purpose
    % Bring up a GUI indicating the bandwidth of each channel and a range of available
    % fluorophores. Indicates which channels should be used for which fluorophore 
    % combinations. 
    %
    %
    % Rob Campbell, SWC, 2021


    properties
        chanRanges % structure listing available channel ranges. Built in the constructor

        % Available dye names
        dyes = {'Alexa647', 'mCherry', 'tdTomato', 'eCFP', 'eGFP', 'eYFP', 'eBFP', 'DiI', 'DiO'}

    end % properties

    properties (Hidden)
        hFig % Handle of the GUI figure window
        hAxesMain % The axes that show the wavelength plot
        mainGUIname = 'channelChooserMain'
        hFilterBands % rectangles indicating filter bands
        hDyeSpectra
        hPanel % panel that houses ui components
        hCheckBoxes % structure of checkbox handles
        hMessageText % Text displayed in the panel for user info
    end % hidden properties



    methods
        function obj = channelChooser

            % Do not open if it already exists. Just focus existing window and end
            f=findobj('Tag',obj.mainGUIname);
            if ~isempty(f)
                % TODO -- test this
                figure(f)
                delete(obj)
                return
            end

            % Hard code for now. (TODO)
            obj.chanRanges(1).centre = 676;
            obj.chanRanges(1).width = 29;
            obj.chanRanges(1).name = 'Far Red';
            obj.chanRanges(1).hardwareChanIndex = 1;

            obj.chanRanges(2).centre = 605;
            obj.chanRanges(2).width = 70;
            obj.chanRanges(2).name = 'Red';
            obj.chanRanges(2).hardwareChanIndex = 2;

            obj.chanRanges(3).centre = 525;
            obj.chanRanges(3).width = 39;
            obj.chanRanges(3).name = 'Green';
            obj.chanRanges(3).hardwareChanIndex = 3;

            obj.chanRanges(4).centre = 460;
            obj.chanRanges(4).width = 60;
            obj.chanRanges(4).name = 'Blue';
            obj.chanRanges(4).hardwareChanIndex = 4;


            % Build the figure
            buildFigure(obj)


        end

        function delete(obj)
            delete(obj.hFig)
        end


        function dyeCallback(obj,src,evt)   
            dyeName = src.Text;
            if src.Value == 1
                % Plot the dye 
                obj.hDyeSpectra.(dyeName) = obj.plotEmissionSpectrum(dyeName);
            else
                % Remove the dye               
                if isfield(obj.hDyeSpectra,dyeName)
                    delete(obj.hDyeSpectra.(dyeName))
                    obj.hDyeSpectra = rmfield(obj.hDyeSpectra, dyeName);
                end
            end
            % Report to message box which channels the user should select in SI
            obj.updateMessageText
        end


        function updateMessageText(obj,src,evt)
            chansToSave = obj.determineChansToSave;
            msg = 'Channels to save: ';
            for ii=1:length(chansToSave)
                cr=obj.chanRanges(chansToSave(ii));
                msg = sprintf('%sChannel %d (%s), ', msg, cr.hardwareChanIndex, cr.name);
            end
            msg(end-1:end)=[];
            obj.hMessageText.Value = msg;
        end
    end % methods


end % classdef



