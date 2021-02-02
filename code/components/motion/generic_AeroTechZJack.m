classdef generic_AeroTechZJack < linearstage
%% 
% Aerotech generic z-jack stage class
%
%
% All abstract methods should have doc text only in the abstract method class file.

    properties
        % Define a few stage-specific properties here. These aren't hardware
        % limits, they are just things that seem to work well and keep 
        % us within reasonable bounds. 
        
        velocityCapMax=5  % Never any need to exceed 5 mm/s
        maxMoveVelocity=2 % 2mm/s seems safe

    end

    properties (Hidden)
        defaultAcceleration=30; %
    end
    methods
        
        %Constructor
        function obj = generic_AeroTechZJack(obj)
            % The following are defaults that can be changed by component settings file
            obj.minPos = 0;
            obj.maxPos = 25;
        end %Constructor


    end %methods


end