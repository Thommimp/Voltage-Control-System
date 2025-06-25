function main()
    % Main entry point for the Voltage Controller application
    % Creates and starts the voltage controller GUI
    
    try
        % Create the voltage controller instance
        controller = VoltageController();
        
        % Display success message
        fprintf('Voltage Controller initialized successfully.\n');
        fprintf('GUI is ready for use.\n');
        
    catch ME
        % Handle any errors during initialization
        fprintf('Error initializing Voltage Controller: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  File: %s, Function: %s, Line: %d\n', ...
                ME.stack(i).file, ME.stack(i).name, ME.stack(i).line);
        end
    end
end