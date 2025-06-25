classdef ConfigManager < handle
    % Configuration management class for saving/loading application settings
    
    properties (Constant)
        CONFIG_FILE = 'voltage_controller_config.mat';
        PROFILES_DIR = 'profiles';
    end
    
    methods (Static)
        function config = getDefaultConfig()
            % Get default configuration structure
            config = struct();
            config.lastSerialPort = '';
            config.defaultFrequency = 1000;
            config.windowPosition = [100, 100, 700, 700];
            config.monitorPosition = [200, 200, 700, 400];
            config.autoConnect = false;
            config.updateRate = 0.1; % seconds
        end
        
        function config = loadConfig()
            % Load configuration from file, create default if not exists
            try
                if exist(ConfigManager.CONFIG_FILE, 'file')
                    loaded = load(ConfigManager.CONFIG_FILE);
                    config = loaded.config;
                    
                    % Merge with defaults in case new fields were added
                    defaultConfig = ConfigManager.getDefaultConfig();
                    config = ConfigManager.mergeStructs(defaultConfig, config);
                else
                    config = ConfigManager.getDefaultConfig();
                    ConfigManager.saveConfig(config);
                end
            catch ME
                warning('Error loading config: %s. Using defaults.', ME.message);
                config = ConfigManager.getDefaultConfig();
            end
        end
        
        function saveConfig(config)
            % Save configuration to file
            try
                save(ConfigManager.CONFIG_FILE, 'config');
            catch ME
                warning('Error saving config: %s', ME.message);
            end
        end
        
        function profile = createChannelProfile(startVoltages, endVoltages, steps, frequency, name)
            % Create a channel configuration profile
            %
            % Inputs:
            %   startVoltages - Array of start voltages for each channel
            %   endVoltages - Array of end voltages for each channel
            %   steps - Array of step counts for each channel
            %   frequency - Frequency setting
            %   name - Profile name
            %
            % Output:
            %   profile - Struct containing all profile data
            
            profile = struct();
            profile.name = name;
            profile.created = datetime('now');
            profile.frequency = frequency;
            profile.channels = struct();
            
            numChannels = length(startVoltages);
            for i = 1:numChannels
                profile.channels(i).startVoltage = startVoltages(i);
                profile.channels(i).endVoltage = endVoltages(i);
                profile.channels(i).steps = steps(i);
            end
        end
        
        function saveProfile(profile)
            % Save a channel configuration profile
            %
            % Input:
            %   profile - Profile struct from createChannelProfile
            
            try
                % Create profiles directory if it doesn't exist
                if ~exist(ConfigManager.PROFILES_DIR, 'dir')
                    mkdir(ConfigManager.PROFILES_DIR);
                end
                
                % Create safe filename
                safeFilename = ConfigManager.createSafeFilename(profile.name);
                filepath = fullfile(ConfigManager.PROFILES_DIR, [safeFilename '.mat']);
                
                save(filepath, 'profile');
                fprintf('Profile "%s" saved successfully.\n', profile.name);
                
            catch ME
                error('Error saving profile: %s', ME.message);
            end
        end
        
        function profile = loadProfile(profileName)
            % Load a channel configuration profile
            %
            % Input:
            %   profileName - Name of profile to load
            %
            % Output:
            %   profile - Loaded profile struct
            
            try
                safeFilename = ConfigManager.createSafeFilename(profileName);
                filepath = fullfile(ConfigManager.PROFILES_DIR, [safeFilename '.mat']);
                
                if exist(filepath, 'file')
                    loaded = load(filepath);
                    profile = loaded.profile;
                    fprintf('Profile "%s" loaded successfully.\n', profileName);
                else
                    error('Profile "%s" not found.', profileName);
                end
                
            catch ME
                error('Error loading profile: %s', ME.message);
            end
        end
        
        function profileList = getAvailableProfiles()
            % Get list of available profiles
            %
            % Output:
            %   profileList - Cell array of profile names
            
            profileList = {};
            
            try
                if exist(ConfigManager.PROFILES_DIR, 'dir')
                    files = dir(fullfile(ConfigManager.PROFILES_DIR, '*.mat'));
                    profileList = cell(length(files), 1);
                    
                    for i = 1:length(files)
                        [~, name, ~] = fileparts(files(i).name);
                        profileList{i} = name;
                    end
                end
            catch ME
                warning('Error reading profiles directory: %s', ME.message);
            end
        end
        
        function deleteProfile(profileName)
            % Delete a profile file
            %
            % Input:
            %   profileName - Name of profile to delete
            
            try
                safeFilename = ConfigManager.createSafeFilename(profileName);
                filepath = fullfile(ConfigManager.PROFILES_DIR, [safeFilename '.mat']);
                
                if exist(filepath, 'file')
                    delete(filepath);
                    fprintf('Profile "%s" deleted successfully.\n', profileName);
                else
                    warning('Profile "%s" not found.', profileName);
                end
                
            catch ME
                error('Error deleting profile: %s', ME.message);
            end
        end
        
        function safeFilename = createSafeFilename(name)
            % Create a filesystem-safe filename from a profile name
            %
            % Input:
            %   name - Original name
            %
            % Output:
            %   safeFilename - Safe filename string
            
            % Replace invalid characters with underscores
            safeFilename = regexprep(name, '[<>:"/\\|?*]', '_');
            
            % Remove leading/trailing spaces and dots
            safeFilename = regexprep(safeFilename, '^[\s\.]+|[\s\.]+$', '');
            
            % Ensure not empty
            if isempty(safeFilename)
                safeFilename = 'unnamed_profile';
            end
            
            % Limit length
            if length(safeFilename) > 50
                safeFilename = safeFilename(1:50);
            end
        end
        
        function merged = mergeStructs(default, override)
            % Merge two structs, keeping values from override where they exist
            %
            % Inputs:
            %   default - Default struct with all expected fields
            %   override - Struct with values to override defaults
            %
            % Output:
            %   merged - Combined struct
            
            merged = default;
            
            if isstruct(override)
                fields = fieldnames(override);
                for i = 1:length(fields)
                    if isfield(merged, fields{i})
                        merged.(fields{i}) = override.(fields{i});
                    end
                end
            end
        end
        
        function exportProfileToCSV(profile, filename)
            % Export profile data to CSV file
            %
            % Inputs:
            %   profile - Profile struct
            %   filename - Output CSV filename
            
            try
                % Prepare data table
                numChannels = length(profile.channels);
                channelNum = (1:numChannels)';
                startVoltages = zeros(numChannels, 1);
                endVoltages = zeros(numChannels, 1);
                steps = zeros(numChannels, 1);
                
                for i = 1:numChannels
                    startVoltages(i) = profile.channels(i).startVoltage;
                    endVoltages(i) = profile.channels(i).endVoltage;
                    steps(i) = profile.channels(i).steps;
                end
                
                % Create table
                dataTable = table(channelNum, startVoltages, endVoltages, steps, ...
                    'VariableNames', {'Channel', 'StartVoltage', 'EndVoltage', 'Steps'});
                
                % Write to CSV
                writetable(dataTable, filename);
                
                % Add metadata as comments (MATLAB doesn't support CSV comments directly)
                fprintf('Profile "%s" exported to %s\n', profile.name, filename);
                fprintf('Frequency: %.1f Hz\n', profile.frequency);
                fprintf('Created: %s\n', datestr(profile.created));
                
            catch ME
                error('Error exporting profile to CSV: %s', ME.message);
            end
        end
        
        function profile = importProfileFromCSV(filename, profileName, frequency)
            % Import profile data from CSV file
            %
            % Inputs:
            %   filename - CSV filename to import
            %   profileName - Name for the new profile
            %   frequency - Frequency setting for the profile
            %
            % Output:
            %   profile - Created profile struct
            
            try
                % Read CSV data
                dataTable = readtable(filename);
                
                % Extract data
                startVoltages = dataTable.StartVoltage;
                endVoltages = dataTable.EndVoltage;
                steps = dataTable.Steps;
                
                % Create profile
                profile = ConfigManager.createChannelProfile(startVoltages, endVoltages, steps, frequency, profileName);
                
                fprintf('Profile imported from %s\n', filename);
                
            catch ME
                error('Error importing profile from CSV: %s', ME.message);
            end
        end
    end
end