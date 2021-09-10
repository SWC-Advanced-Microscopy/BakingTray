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

        hLaserSetButton
        hChannelSetButton
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
                %If the BT view class created this panel, it will provide this argument
                obj.parentView = parentView;
            end

            obj.chanRanges = BakingTray.channelChooser.readSettings;

            % Build the figure
            buildFigure(obj);


        end

        function delete(obj)
            delete(obj.hFig)
        end



        function setLaserWavelengthCallback(obj,~,~)
            if obj.model.laser.isPoweredOn == false
                warndlg('Laser wavelength can not be set until laser is powered on.')
                return
            end
            if isempty(obj.hDyeSpectraExcitation)
                warndlg('Select dyes to calculate an optimal laser wavelength.')
                return
            end 

            optimalWavelength = obj.determineLaserWavelength;
            if isempty(optimalWavelength)
                warndlg('No optimal laser wavelength is available.')
                return
            end 

            msg = sprintf('Tune laser to %d nm?',optimalWavelength);
            q=questdlg(msg,'','Yes','No','Yes');
            if strcmpi(q,'yes')
                obj.model.laser.setWavelength(optimalWavelength);
            end
        end %setLaserWavelengthCallback


        function setChannelsToAcquire(obj,~,~)
            if isempty(obj.hDyeSpectraExcitation)
                warndlg('Select dyes to determine which channels to save.')
                return
            end 
            chansToSave = obj.determineChansToSave;
            if isempty(chansToSave)
                warndlg('Not able to determine channels to save.')
                return
            end 
            obj.model.scanner.setChannelsToAcquire = chansToSave;
        end %setChannelsToAcquire


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
        end %dyeCallback


        function updateMessageText(obj,src,evt)

            % First list channels to save
            chansToSave = obj.determineChansToSave;
            msg = sprintf('Channels to save:\n');
            for ii=1:length(chansToSave)
                cr=obj.chanRanges(chansToSave(ii));
                msg = sprintf('%sChan %d (%s), ', msg, cr.hardwareChanIndex, cr.name);
            end
            msg(end-1:end)=[];


            % No add optimal laser wavelength
            optimalWavelength = obj.determineLaserWavelength;
            if ~isempty(optimalWavelength)
                msg = sprintf('%s\nOptimal laser wavelength: %d nm',msg,optimalWavelength);
            end

            obj.hMessageText.Value = msg;
        end %updateMessageText

    end % methods


end % classdef
