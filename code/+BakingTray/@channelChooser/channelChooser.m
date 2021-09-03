classdef channelChooser < BakingTray.gui.child_view
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

        hAxesMain % The axes that show the wavelength plot
        hAxesExcite % The excitation spectra are plotted here


        hFilterBands % rectangles indicating filter bands
        hDyeSpectraEmission
        hDyeSpectraExcitation
        hLegend
        hPanel % panel that houses ui components
        hCheckBoxes % structure of checkbox handles
        hMessageText % Text displayed in the panel for user info

    end % properties

    properties (Hidden)
        mainGUIname = 'BakingTray_channelChooser';

        % Available dye names
        dyes = {'Alexa647', 'mCherry', 'tdTomato', 'eCFP', 'eGFP', 'eYFP', 'eBFP', 'DiI', 'DiO'}
    end % hidden properties



    methods
        function obj = channelChooser(hBT,parentView)

            obj = obj@BakingTray.gui.child_view;

            if nargin>0
                %If the BT view created this panel, it will provide this argument
                obj.model = hBT;
            end

            if nargin>1
                %If the BT view created this panel, it will provide this argument
                obj.parentView = parentView;
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
            buildFigure(obj);


        end

        function delete(obj)
            delete(obj.hFig)
        end


        function dyeCallback(obj,src,evt)   
            dyeName = src.Text;
            if src.Value == 1
                % Plot the dye 
                obj.hDyeSpectraEmission.(dyeName) = obj.plotEmissionSpectrum(dyeName);
                obj.hDyeSpectraExcitation.(dyeName) = obj.plotExcitationSpectrum(dyeName);

                if ~isempty(obj.hDyeSpectraExcitation.(dyeName))
                    obj.hDyeSpectraExcitation.(dyeName).Color = obj.hDyeSpectraEmission.(dyeName).Color;
                else
                    obj.hDyeSpectraExcitation = rmfield(obj.hDyeSpectraExcitation, dyeName);
                end

            else
                % Remove the dye               
                if isfield(obj.hDyeSpectraEmission,dyeName)
                    delete(obj.hDyeSpectraEmission.(dyeName))
                    obj.hDyeSpectraEmission = rmfield(obj.hDyeSpectraEmission, dyeName);
                end
                if isfield(obj.hDyeSpectraExcitation,dyeName)
                    delete(obj.hDyeSpectraExcitation.(dyeName))
                    obj.hDyeSpectraExcitation = rmfield(obj.hDyeSpectraExcitation, dyeName);
                end
            end
            
            obj.hLegend.String = fields(obj.hDyeSpectraExcitation); %update legend

            % Report to message box which channels the user should select in SI
            obj.updateMessageText;
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



