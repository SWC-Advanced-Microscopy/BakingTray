function success=attachMotionAxes(obj,settings)
    % Attach all available motion axes to BT
    %
    % function success=attachMotionAxes(obj,settings)
    %
    % Inputs (optional)
    % settings - this is the motionAxis field from the settings structure produced by
    %            the settings reader BakingTray.settings.readComponentSettings
    %            If left empty, the the settings file is read by this function 
    %            and the correct field is extracted.
    %
    % Outputs
    % success - Returns true if a BT hardware component was built successfully. 
    %           The component itself is placed in the BT object as a property,
    %           so BT is a composite object.
    %
    %



    %Read the settings file if a structure was not supplied for this component
    if nargin<2 || isempty(settings)
         settings=BakingTray.settings.readComponentSettings;
         settings=settings.motionAxis;
    end
    success=false;

    % We loop through all available motion axes and pair them up with the correct
    % properties in BT (xAxis, yAxis, zAxis)

    for nC = 1:length(settings) %Loop through all available controllers
        thisController = settings(nC);
        if isempty(thisController)
            continue
        end

        for nS = 1:length(thisController.stage)
            thisStage = thisController.stage(nS);
            if isempty(thisStage)
                continue
            end
            %So now we have a stage/controller pair. 
            %This provides a mechanism for coping with multiple stages on the same controller

            %First check the axisName field is present and valid
            % TODO: this should all go into a component reader so we won't even get to this point if the settings are bad
            % TODO: in fact, these checks are in linearcontroller...
            if ~isfield(thisStage.settings,'axisName')
                error('No field stage.settings.axisName defined for stage. This is an error in your settings file.')
            end
            if isempty(thisStage.settings.axisName)
                error('Field stage.settings.axisName has no assigned value for stage. This is an error in your settings file.')
            end

            thisAxisName=thisStage.settings.axisName;

            if ~isstr(thisAxisName)
                error('Field stage.settings.axisName should be a string')
            end
            if ~regexp(thisAxisName,'^[xyz]Axis$')
                error('Field stage.settings.axisName is incorrect. It should be one of: xAxis, yAxis, or zAxis. You supplied %s',thisAxisName)
            end
            if ~isempty(obj.(thisAxisName))
                error('Axis %s has already been set up. Settings file must have a duplicate %s field.',thisAxisName,thisAxisName)
            end


            %Report to screen what we are attempting to connect
            fprintf('Setting up axis %s on linear stage controller %s #%d\n',...
                thisAxisName, thisController.type, nC)

            try
                obj.(thisAxisName)=buildMotionComponent(thisController.type, thisController.settings, ...
                                             thisStage.type, thisStage.settings);

            catch ME1
                disp(ME1.message)
                fprintf('FAILED TO BUILD AXIS: %s\n',thisAxisName)
                disp(ME1.message)
                for ii=1:length(ME1.stack)
                    st=ME1.stack(ii);
                    fprintf('\t%s - %s (line: %d)\n', st.name,st.file,st.line)
                end
                fprintf('\n')
                obj.(thisAxisName)=[];
            end

            %Return false if the attachment failed
            if ~isempty(obj.(thisAxisName))
                %Add a link to the BT parent object to the component so this component can access
                %other attached components
                obj.(thisAxisName).parent=obj;
            else
                fprintf('No axis attached for %s\n',thisAxisName)
            end
        end
    end



    success = ~isempty(obj.xAxis) && ~isempty(obj.yAxis) && ~isempty(obj.zAxis);

end
