classdef VoltageController < handle
    properties (Constant)
        MAX_VOLTAGE = 30;
        NUM_CHANNELS = 24;
    end
    
    properties
        fig
        startVoltageFields
        endVoltageFields
        stepFields
        holdEndCheckboxes
        frequencyField
        portDropdown
        serialConnection
        plotWindow
        
        % UI Elements
        setAllStart
        setAllEnd
        setAllSteps
        setAllHold
    end
    
    methods
        function obj = VoltageController()
            obj.createMainUI();
            obj.setupSerialPorts();
        end
        
        function createMainUI(obj)
            obj.fig = uifigure('Position', [100, 100, 700, 700], 'Name', 'Voltage Controller');
            obj.fig.CloseRequestFcn = @(~,~) obj.cleanup();
            
            % Title
            uilabel(obj.fig, ...
                'Text', sprintf('Voltage Controller for %d Channels', obj.NUM_CHANNELS), ...
                'FontSize', 16, ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'Position', [100, 650, 500, 30]);
            
            % Big Start Button
            uibutton(obj.fig, 'state',...
                'Text', 'Start', ...
                'FontSize', 18, ...
                'FontWeight', 'bold', ...
                'Position', [550, 610, 120, 50], ...
                'ValueChangedFcn', @(btn, event) obj.openPlotWindow(btn));
            
            obj.createFrequencyControls();
            obj.createChannelTable();
            obj.createSetAllControls();
            obj.createControlButtons();
        end
        
        function createFrequencyControls(obj)
            uilabel(obj.fig, 'Text', 'Frequency (Hz):', 'Position', [50, 610, 100, 22], 'FontWeight', 'bold');
            obj.frequencyField = uieditfield(obj.fig, 'numeric', 'Position', [160, 610, 100, 22]);
            uibutton(obj.fig, 'Text', 'Apply', ...
                'Position', [265, 610, 45, 22], ...
                'ButtonPushedFcn', @(btn, event) obj.setFrequency(obj.frequencyField.Value));
        end
        
        function createChannelTable(obj)
            % Table headers
            uilabel(obj.fig, 'Text', 'Channel', 'Position', [50, 580, 60, 22], 'FontWeight', 'bold');
            uilabel(obj.fig, 'Text', 'Start Voltage (V)', 'Position', [170, 580, 120, 22], 'FontWeight', 'bold');
            uilabel(obj.fig, 'Text', 'End Voltage (V)', 'Position', [300, 580, 120, 22], 'FontWeight', 'bold');
            uilabel(obj.fig, 'Text', 'Steps', 'Position', [470, 580, 100, 22], 'FontWeight', 'bold');
            uilabel(obj.fig, 'Text', 'Hold End?', 'Position', [550, 580, 80, 22], 'FontWeight', 'bold');
            
            % Scrollable panel
            scrollPanel = uipanel(obj.fig, ...
                'Position', [50, 125, 600, 420], ...
                'Scrollable', 'on');
            
            rowHeight = 22;
            spacing = 4;
            totalHeight = obj.NUM_CHANNELS * (rowHeight + spacing);
            yStart = totalHeight - rowHeight;
            
            obj.startVoltageFields = gobjects(obj.NUM_CHANNELS, 1);
            obj.endVoltageFields = gobjects(obj.NUM_CHANNELS, 1);
            obj.stepFields = gobjects(obj.NUM_CHANNELS, 1);
            
            for i = 1:obj.NUM_CHANNELS
                y = yStart - (i-1)*(rowHeight + spacing);
                
                uilabel(scrollPanel, 'Text', sprintf('%d', i), 'Position', [20, y, 30, 22]);
                
                obj.startVoltageFields(i) = uieditfield(scrollPanel, 'numeric', ...
                    'Position', [120, y, 100, 22]);
                
                obj.endVoltageFields(i) = uieditfield(scrollPanel, 'numeric', ...
                    'Position', [250, y, 100, 22]);
                
                obj.stepFields(i) = uieditfield(scrollPanel, 'numeric', ...
                    'Position', [390, y, 100, 22]);

                obj.holdEndCheckboxes(i) = uicheckbox(scrollPanel, ...
                     'Position', [500, y, 100, 22]);

            end
        end
        
        function createSetAllControls(obj)
            uilabel(obj.fig, 'Text', 'Set All:', 'Position', [50, 550, 60, 22], 'FontWeight', 'bold');
            
            obj.setAllStart = uieditfield(obj.fig, 'numeric', 'Position', [170, 550, 50, 22]);
            uibutton(obj.fig, 'Text', 'Apply', ...
                'Position', [225, 550, 45, 22], ...
                'ButtonPushedFcn', @(btn, event) obj.setAll(obj.startVoltageFields, obj.setAllStart.Value));
            
            obj.setAllEnd = uieditfield(obj.fig, 'numeric', 'Position', [300, 550, 50, 22]);
            uibutton(obj.fig, 'Text', 'Apply', ...
                'Position', [355, 550, 45, 22], ...
                'ButtonPushedFcn', @(btn, event) obj.setAll(obj.endVoltageFields, obj.setAllEnd.Value));
            
            obj.setAllSteps = uieditfield(obj.fig, 'numeric', 'Position', [440, 550, 50, 22]);
            uibutton(obj.fig, 'Text', 'Apply', ...
                'Position', [495, 550, 45, 22], ...
                'ButtonPushedFcn', @(btn, event) obj.setAll(obj.stepFields, obj.setAllSteps.Value));

         end
   
        
        function createControlButtons(obj)
            % First row buttons
            uibutton(obj.fig, 'Text', 'Send Values', ...
                'Position', [20, 50, 110, 30], ...
                'ButtonPushedFcn', @(btn, event) obj.updateVoltages());
            
            uibutton(obj.fig, 'state', ...
                'Text', 'Auto Sweep', ...
                'Position', [280, 50, 100, 30], ...
                'ValueChangedFcn', @(btn, event) obj.toggleSweep(btn));
            
            uibutton(obj.fig, 'state', ...
                'Text', 'Connect', ...
                'Position', [390, 50, 90, 30], ...
                'ValueChangedFcn', @(btn, event) obj.toggleConnect(btn));
            
            % Second row buttons
            uibutton(obj.fig, 'Text', 'Load Last values from stm32 ', ...
                'Position', [20, 10, 110, 30]);
            
            uibutton(obj.fig, 'Text', 'Save Profile', ...
                'Position', [140, 10, 110, 30]);
            
            uibutton(obj.fig, 'Text', 'Refresh Ports', ...
                'Position', [490, 90, 90, 22], ...
                'ButtonPushedFcn', @(btn, event) obj.refreshPorts());
        end
        
        function setupSerialPorts(obj)
            allPorts = serialportlist("all");
            ports = allPorts(startsWith(allPorts, "/dev/cu."));
            
            if isempty(ports)
                ports = {'No ports found'};
            end
            
            obj.portDropdown = uidropdown(obj.fig, ...
                'Items', ports, ...
                'Position', [390, 90, 90, 22], ...
                'Enable', 'on');
        end
        
        function refreshPorts(obj)
            newPorts = serialportlist("all");
            if isempty(newPorts)
                newPorts = {'No ports found'};
            end
            obj.portDropdown.Items = newPorts;
        end
        
        function updateVoltages(obj)
            for i = 1:obj.NUM_CHANNELS
                if ~obj.validateChannelValues(i)
                    return;
                end
                
                packet = obj.createVoltagePacket(i);
                obj.sendPacket(packet, sprintf('Channel %d', i));
                pause(0.1); % 0.5 second delay

            end
        end
        
        function isValid = validateChannelValues(obj, channelNum)
            startVal = obj.startVoltageFields(channelNum).Value;
            endVal = obj.endVoltageFields(channelNum).Value;
            stepsVal = obj.stepFields(channelNum).Value;
            
            if startVal < 0 || startVal > obj.MAX_VOLTAGE
                errordlg(sprintf('Start voltage out of range (0–%d) on channel %d', obj.MAX_VOLTAGE, channelNum), 'Value Error');
                isValid = false;
                return;
            end
            if endVal < 0 || endVal > obj.MAX_VOLTAGE
                errordlg(sprintf('End voltage out of range (0–%d) on channel %d', obj.MAX_VOLTAGE, channelNum), 'Value Error');
                isValid = false;
                return;
            end
            if stepsVal <= 0 || stepsVal > 65535
                errordlg(sprintf('Steps must be between 1 and 65535 on channel %d', channelNum), 'Value Error');
                isValid = false;
                return;
            end
            
            isValid = true;
        end
        
        function packet = createVoltagePacket(obj, channelNum)
            disp(class(obj.holdEndCheckboxes))
            startVal = obj.startVoltageFields(channelNum).Value;
            endVal = obj.endVoltageFields(channelNum).Value;
            stepsVal = obj.stepFields(channelNum).Value;
            holdEndValue = get(obj.holdEndCheckboxes(channelNum), 'Value');

            
            % Convert voltage to DAC values
            startValConv = startVal * 65535 / obj.MAX_VOLTAGE;
            endValConv = endVal * 65535 / obj.MAX_VOLTAGE;
            
            % Prepare byte arrays
            startInt = fliplr(typecast(uint16(startValConv), 'uint8'));
            endInt = fliplr(typecast(uint16(endValConv), 'uint8'));
            stepsInt = fliplr(typecast(uint16(stepsVal), 'uint8'));
            
            packet = [170, 12, 1, channelNum, holdEndValue, startInt, endInt, stepsInt, 0];
        end
        
        function sendPacket(obj, packet, description)
            if obj.isSerialConnected()
                write(obj.serialConnection, packet, 'uint8');
                packetHex = arrayfun(@(b) sprintf('%02X', b), packet, 'UniformOutput', false);
                packetStr = strjoin(packetHex, ' ');
                fprintf('%s packet: %s\n', description, packetStr);
            end
        end
        
        function toggleSweep(obj, btn)
            if btn.Value
                btn.Text = 'Stop Sweep';
            else
                btn.Text = 'Auto Sweep';
            end
        end
        
        function toggleConnect(obj, btn)
            if btn.Value
                obj.connectSerial(btn);
            else
                obj.disconnectSerial(btn);
            end
        end
        
        function connectSerial(obj, btn)
            selectedPort = obj.portDropdown.Value;
            if strcmp(selectedPort, 'No ports found')
                uialert(obj.fig, 'No valid serial port selected.', 'Connection Error');
                btn.Value = false;
                return;
            end
            
            try
                obj.serialConnection = serialport(selectedPort, 115200);
                configureCallback(obj.serialConnection, "byte", 1, @obj.readSerial);
                flush(obj.serialConnection);
                btn.Text = 'Disconnect';
                disp(['Connected to: ' selectedPort]);
            catch err
                uialert(obj.fig, ['Failed to connect: ' err.message], 'Connection Error');
                btn.Value = false;
            end
        end
        
        function disconnectSerial(obj, btn)
            if ~isempty(obj.serialConnection)
                configureCallback(obj.serialConnection, "off");
                clear obj.serialConnection;
                obj.serialConnection = [];
            end
            btn.Text = 'Connect';
            disp('Disconnected from serial port');
        end
        
        function readSerial(obj, src, ~)
            bytesAvailable = src.NumBytesAvailable;
            if bytesAvailable > 0
                data = read(src, bytesAvailable, "uint8");
                hexStrs = sprintf('%02X ', data);
                disp("Received (hex):");
                disp(hexStrs);
                disp("Received (decimal):");
                disp(data);
            end
        end
        
        function openPlotWindow(obj, btn)


            if btn.Value
                btn.Text = 'Running';
                obj.startDataCollection();
                obj.plotWindow = VoltageMonitor(obj.serialConnection, btn);
            else
                btn.Text = 'Start';
                obj.stopDataCollection();
                if ~isempty(obj.plotWindow)
                    obj.plotWindow.close();
                    obj.plotWindow = [];
                end
            end
        end
        
        function startDataCollection(obj)
            if obj.isSerialConnected()
                startPacket = [170, 4, 2, 0];
                write(obj.serialConnection, startPacket, 'uint8');
                 disp("here")

            end
        end
        
        function stopDataCollection(obj)
            if obj.isSerialConnected()
                stopPacket = [170, 4, 8, 0];
                write(obj.serialConnection, stopPacket, 'uint8');
            end
        end
        
        function setAll(obj, fieldArray, value)
            for i = 1:numel(fieldArray)
                fieldArray(i).Value = value;
            end
        end
        
        function setFrequency(obj, frequency)
            if frequency > 200000
                errordlg(sprintf('Frequency set too high DACs can maximum handle up to 200Khz and you set %d hz', frequency), 'Value Error');
                return;
            end
            
            if ~obj.isSerialConnected()
                errordlg('Please choose a valid serial port and connect first.', 'Serial Port Error');
                return;
            end
            
            freqInt = fliplr(typecast(uint32(frequency), 'uint8'));
            freq3bytes = freqInt(2:4);
            freqPacket = [170, 7, 8, freq3bytes, 0];
            
            obj.sendPacket(freqPacket, 'Frequency');
        end
        
        function connected = isSerialConnected(obj)
            connected = ~isempty(obj.serialConnection) && isvalid(obj.serialConnection) && strcmp(obj.serialConnection.Status, 'open');
        end
        
        function cleanup(obj)
            try
                if ~isempty(obj.plotWindow)
                    obj.plotWindow.close();
                end
            catch
            end
            
            try
                obj.disconnectSerial(struct('Text', 'Connect'));
            catch
            end
            
            try
                delete(obj.fig);
            catch
            end
        end
    end
end