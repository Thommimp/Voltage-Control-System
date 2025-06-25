classdef VoltageMonitor < handle
    properties
        fig
        ax
        barPlot
        timerObj
        voltageData
        serialConnection
        startButton
        updateRate = 0.05  % 50ms update period for smooth animation
        packetSize = 48    % Expected packet size in bytes
        numChannels = 24   % Number of voltage channels
        maxVoltage = 30    % Maximum voltage for scaling
    end
    
    methods
        function obj = VoltageMonitor(serialConn, startBtn)
            obj.serialConnection = serialConn;
            obj.startButton = startBtn;
            obj.initializeData();
            obj.createPlotWindow();
            obj.startTimer();
        end
        
        function initializeData(obj)
            obj.voltageData = zeros(1, obj.numChannels);
        end
        
        function createPlotWindow(obj)
            % Create main figure
            obj.fig = uifigure('Name', 'Real-time Voltage Monitor', ...
                              'Position', [200 200 800 500], ...
                              'Resize', 'on');
            obj.fig.CloseRequestFcn = @(src, event) obj.onCloseFigure();
            
            % Create axes with better positioning
            obj.ax = uiaxes(obj.fig, 'Position', [60 80 700 350]);
            
            % Configure plot appearance
            title(obj.ax, 'Channel Voltages (Real-time)', 'FontSize', 14);
            xlabel(obj.ax, 'Channel Number', 'FontSize', 12);
            ylabel(obj.ax, 'Voltage (V)', 'FontSize', 12);
            
            % Set axis limits and ticks
            obj.ax.XLim = [0.5 obj.numChannels + 0.5];
            obj.ax.YLim = [0 obj.maxVoltage];
            obj.ax.XTick = 1:obj.numChannels;
            grid(obj.ax, 'on');
            
            % Create initial bar plot
            obj.barPlot = bar(obj.ax, 1:obj.numChannels, obj.voltageData);
            
            % Add status label (simpler approach for UIFigure)
            uilabel(obj.fig, 'Position', [20 20 300 20], ...
                   'Text', 'Status: Monitoring...', ...
                   'FontSize', 10);
        end
        
        function startTimer(obj)
            % Clear any stale data from serial buffer
            obj.clearSerialBuffer();
            
            % Create and start timer with high frequency for smooth updates
            obj.timerObj = timer('ExecutionMode', 'fixedSpacing', ...
                               'Period', obj.updateRate, ...
                               'TimerFcn', @(~,~) obj.updatePlot(), ...
                               'ErrorFcn', @(~,~) obj.handleTimerError());
            start(obj.timerObj);
        end
        
        function updatePlot(obj)
            try
                if obj.isSerialReady()
                    % Get the latest voltage data
                    newVoltageData = obj.readLatestVoltageData();
                    
                    if ~isempty(newVoltageData)
                        % Update internal data
                        obj.voltageData = newVoltageData;
                        
                        % Update plot efficiently
                        obj.barPlot.YData = obj.voltageData;
                        
                        % Force immediate redraw for smooth animation
                        drawnow;
                    end
                end
            catch ME
                % Handle errors gracefully
                fprintf('Error in updatePlot: %s\n', ME.message);
            end
        end
        
        function voltageData = readLatestVoltageData(obj)
            voltageData = [];
            
            try
                availableBytes = obj.serialConnection.NumBytesAvailable;
                
                if availableBytes >= obj.packetSize
                    % Calculate how many complete packets are available
                    completePackets = floor(availableBytes / obj.packetSize);
                    
                    % Read all available data
                    totalBytesToRead = completePackets * obj.packetSize;
                    allData = read(obj.serialConnection, totalBytesToRead, "uint8");
                    
                    % Extract the most recent complete packet
                    latestPacketStart = (completePackets - 1) * obj.packetSize + 1;
                    latestPacketEnd = completePackets * obj.packetSize;
                    latestPacket = allData(latestPacketStart:latestPacketEnd);
                    
                    % Convert to voltage values
                    voltages16 = typecast(uint8(latestPacket), 'uint16');
                    voltageData = double(voltages16) * obj.maxVoltage / 65535;
                    
                    % Validate data length
                    if length(voltageData) ~= obj.numChannels
                        fprintf('Warning: Received %d channels, expected %d\n', ...
                               length(voltageData), obj.numChannels);
                        voltageData = [];
                    end
                end
            catch ME
                fprintf('Error reading serial data: %s\n', ME.message);
            end
        end
        
        function ready = isSerialReady(obj)
            ready = ~isempty(obj.serialConnection) && ...
                    isvalid(obj.serialConnection) && ...
                    obj.serialConnection.NumBytesAvailable >= obj.packetSize;
        end
        
        function clearSerialBuffer(obj)
            try
                if ~isempty(obj.serialConnection) && isvalid(obj.serialConnection)
                    if obj.serialConnection.NumBytesAvailable > 0
                        flush(obj.serialConnection);
                        pause(0.01); % Brief pause to ensure buffer is cleared
                    end
                end
            catch ME
                fprintf('Warning: Could not clear serial buffer: %s\n', ME.message);
            end
        end
        
        function handleTimerError(obj)
            fprintf('Timer error occurred. Attempting to restart...\n');
            obj.stopTimer();
            pause(0.1);
            obj.startTimer();
        end
        
        function onCloseFigure(obj)
            obj.close();
        end
        
        function close(obj)
            % Update start button state
            if ~isempty(obj.startButton) && isvalid(obj.startButton)
                obj.startButton.Text = 'Start';
                obj.startButton.Value = false;
            end
            
            % Stop monitoring
            obj.stopTimer();
            obj.sendStopPacket();
            
            % Close figure
            if ~isempty(obj.fig) && isvalid(obj.fig)
                delete(obj.fig);
            end
            
            fprintf('Voltage monitor closed.\n');
        end
        
        function stopTimer(obj)
            if ~isempty(obj.timerObj) && isvalid(obj.timerObj)
                try
                    stop(obj.timerObj);
                    delete(obj.timerObj);
                catch ME
                    fprintf('Warning: Error stopping timer: %s\n', ME.message);
                end
                obj.timerObj = [];
            end
        end
        
        function sendStopPacket(obj)
            if ~isempty(obj.serialConnection) && isvalid(obj.serialConnection)
                try
                    stopPacket = [170, 4, 6, 0];
                    write(obj.serialConnection, stopPacket, 'uint8');
                    fprintf('Stop packet sent.\n');
                catch ME
                    fprintf('Warning: Could not send stop packet: %s\n', ME.message);
                end
            end
        end
        
        % Additional utility methods
        function setUpdateRate(obj, newRate)
            % Allow dynamic update rate changes
            if newRate > 0.01 && newRate < 1.0
                obj.updateRate = newRate;
                if ~isempty(obj.timerObj) && isvalid(obj.timerObj)
                    obj.stopTimer();
                    obj.startTimer();
                end
            end
        end
        
        function stats = getConnectionStats(obj)
            % Get connection statistics
            stats = struct();
            if ~isempty(obj.serialConnection) && isvalid(obj.serialConnection)
                stats.connected = true;
                stats.bytesAvailable = obj.serialConnection.NumBytesAvailable;
                stats.updateRate = obj.updateRate;
            else
                stats.connected = false;
                stats.bytesAvailable = 0;
                stats.updateRate = 0;
            end
        end
    end
end