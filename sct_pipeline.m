%% Preprocessing Pipeline of the Simon Conflict Task Dataset
clear;
clc;
close all;


%% Reset MATLAB search path to default to avoid conflicts
restoredefaultpath


%% Add paths of required toolboxes — EDIT THESE for your system
toolboxDIR = '/MATLAB_ToolBoxes';  % or wherever you keep toolboxes

addpath(fullfile(toolboxDIR, 'fieldtrip-20250114'));
addpath(fullfile(toolboxDIR, 'zapline-plus-1.2.1'));
addpath(fullfile(toolboxDIR, 'auto-ica-checking'));

ft_defaults;


%% Define required paths
baseDIR = fileparts(fileparts(mfilename('fullpath')));
dataDIR = fullfile(baseDIR, 'Raw_Data');
resultsDIR = fullfile(baseDIR, 'FT_Results');


%% Loop through subjects and process data one at a time 
subjects = [1]; % Subjects you want to preprocess — edit as needed

for subject = subjects
    
    % Generate filenames
    subjectStr = sprintf('sub-%03d', subject);
    filepath = fullfile(dataDIR, subjectStr, 'ses-01', 'eeg');
    filename = [subjectStr '_ses-01_task-SimonConflict_eeg.set'];
    layoutFilename = fullfile(filepath, ...
        [subjectStr '_ses-01_task-SimonConflict_electrodes.tsv']);
    
    % Create the subject-specific directory for the results
    subjectDIR = fullfile(resultsDIR, subjectStr);
    if ~isfolder(subjectDIR)
        mkdir(subjectDIR);
    end

    % Start logging command window output to a diary file
    diaryFilename = fullfile(subjectDIR, [subjectStr '_log.txt']);
    diary(diaryFilename);  
    diary on;

    try
       
        fprintf('\n\n\t********************    Start Processing Subject: %s    ********************\n\n', subjectStr);

        % Load EEG data, excluding the EOG channel
        eegData = sct_loadRawData(fullfile(filepath, filename));
        
        % Remove line noise - Apply high/low-pass filters
        % Save preprocessed 
        preprocessed = sct_preprocess(eegData, subjectDIR);
        
        % Recreate CPz channel (pre-ICA)
        interpolated = sct_interpolate(preprocessed, layoutFilename, 'pre-ICA');
           
        % Define trials - Segment the data into trials
        trials = sct_defineTrials(interpolated);      
    
        % Inspect the data for bad trials automatically - Reject bad trials
        % Save cleanTrials
        cleanTrials  = sct_autoInspectTrials(trials, subjectDIR);
         
        % Run ICA
        % Save components
        components = sct_runICA(cleanTrials, subjectDIR);

        % Plot components to detect artifactual ones
        components = sct_inspectICA(components, layoutFilename);

        % Reject artifactual ICs
        icaCleanTrials = sct_rejectArtifacts(components, cleanTrials, subjectDIR);

        % Recreate CPz channel (post-ICA)
        icaCleanTrials = sct_interpolate(icaCleanTrials, layoutFilename, 'post-ICA');

        % Plot the trials
        sct_plotTrials(cleanTrials, 'Before ICA');
        sct_plotTrials(icaCleanTrials, 'After ICA');

        % Bin the trials based on different conditions
        binnedTrials = sct_defineBins(icaCleanTrials);

        % Compute ERPs - Apply baseline correction
        erp = sct_computeERP(binnedTrials, subjectDIR);
        
        fprintf('\n\n\t********************    End of Processing Subject: %s    ********************\n\n', subjectStr);

    catch ME
        fprintf('\n\n\t!!!!!!!!!!    Error Processing Subject: %s    !!!!!!!!!!\n\n', subjectStr);
        fprintf('\tError Message: %s\n', getReport(ME));
    end

    % Stop logging
    diary off;

end
