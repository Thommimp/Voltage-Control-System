classdef VoltageMonitor < handle
    properties
        fig
        ax
        barPlot
        voltageData
        serialConnection
        startButton
        packetSize = 50    % Expected packet size 2*channel + start og stop
        numChannels = 24
        maxVoltage = 30
    end

    methods
        function obj = VoltageMonitor(serialConn, startBtn)
            obj.serialConnection = serialConn;
            obj.startButton = startBtn;
            obj.initializeData();
            obj.createPlotWindow();
            obj.startSerialCallback();
        end

        function initializeData(obj)
            obj.voltageData = zeros(1, obj.numChannels);
        end

        function createPlotWindow(obj)
            obj.fig = uifigure('Name', 'Real-time Voltage Monitor', ...
                               'Position', [200 200 800 500]);
            obj.fig.CloseRequestFcn = @(src, event) obj.onCloseFigure();

            obj.ax = uiaxes(obj.fig, 'Position', [60 80 700 350]);
            title(obj.ax, 'Channel Voltages (Real-time)', 'FontSize', 14);
            xlabel(obj.ax, 'Channel Number', 'FontSize', 12);
            ylabel(obj.ax, 'Voltage (V)', 'FontSize', 12);

            obj.ax.XLim = [0.5 obj.numChannels + 0.5];
            obj.ax.YLim = [0 obj.maxVoltage];
            obj.ax.XTick = 1:obj.numChannels;
            grid(obj.ax, 'on');

            obj.barPlot = bar(obj.ax, 1:obj.numChannels, obj.voltageData);

            uilabel(obj.fig, 'Position', [20 20 300 20], ...
                    'Text', 'Status: Monitoring...', ...
                    'FontSize', 10);
        end

        function startSerialCallback(obj)
            configureCallback(obj.serialConnection, "byte", obj.packetSize, ...
                              @(src, event) obj.serialCallback());
        end

        function serialCallback(obj)
            try
                if obj.serialConnection.NumBytesAvailable >= obj.packetSize
                    allData = read(obj.serialConnection, obj.serialConnection.NumBytesAvailable, "uint8");
                    disp(allData);
                    for i = length(allData) - obj.packetSize + 1:-1:1
                        packet = allData(i:i + obj.packetSize - 1);
                      %  fprintf('Raw packet: %s\n', num2str(packet));

                        if packet(1) == 170 && packet(end) == 85  % 0xAA and 0x55
                            voltageBytes = packet(2:end-1);
                            voltages16 = typecast(uint8(voltageBytes), 'uint16');
                            voltageData = double(voltages16) * obj.maxVoltage / 65535;

                            if length(voltageData) == obj.numChannels
                                % Print to terminal
                                obj.voltageData = voltageData;
                                obj.barPlot.YData = obj.voltageData;
                                drawnow limitrate;
                                break
                            end
                        end
                    end
                end
            catch ME
                fprintf('Error in serialCallback: %s\n', ME.message);
            end
        end

        function onCloseFigure(obj)
            obj.close();
        end

        function close(obj)
            if ~isempty(obj.startButton) && isvalid(obj.startButton)
                obj.startButton.Text = 'Start';
                obj.startButton.Value = false;
            end

            obj.sendStopPacket();

            if ~isempty(obj.serialConnection) && isvalid(obj.serialConnection)
                configureCallback(obj.serialConnection, "off");
            end

            if ~isempty(obj.fig) && isvalid(obj.fig)
                delete(obj.fig);
            end

            fprintf('Voltage monitor closed.\n');
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
    end
end
