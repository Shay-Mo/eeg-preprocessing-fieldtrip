function preprocessed = sct_preprocess(eegData)
%SCT_PREPROCESS Removes line noise and applies bandpass filtering
%
%   preprocessed = SCT_PREPROCESS(eegData) removes line noise from eegData 
%   using Zapline-Plus, then applies a high-pass filter at 0.5 Hz and a 
%   low-pass filter at 60 Hz using FieldTrip.
%
%   Input:
%       eegData  - FieldTrip raw data structure (single trial), as
%                  returned by sct_loadRawData
%
%   Output:
%       preprocessed - FieldTrip data structure containing the
%                      line-noise-removed, filtered signal
%
%   Example:
%       preprocessed = sct_preprocess(eegData);
%
%   See also SCT_LOADRAWDATA, SCT_PIPELINE, SCT_INTERPOLATE, SCT_SAVERESULT

    %% Filter settings
    hpFreq = 0.5;   % Hz, high-pass cutoff
    lpFreq = 60;    % Hz, low-pass cutoff

    %% Remove line noise using Zapline-Plus
    fprintf('\n\t--> Removing line noise with Zapline-Plus...\n');
    zaplineData = eegData; 
    try
        zaplineData.trial{1} = clean_data_with_zapline_plus(eegData.trial{1}, ...
            eegData.fsample, 'noisefreqs', 'line', 'plotResults', 0);
    catch ME
        error('sct_preprocess:zaplineFailed', ...
            'Zapline-Plus failed — check it is on the MATLAB path.\nOriginal error: %s', ...
            ME.message);
    end
    
    %% Apply High-pass and Low-pass Filters
    fprintf('\n\t--> Applying %.1f-%d Hz bandpass filter...\n', hpFreq, lpFreq);
    cfg = [];
    cfg.hpfilter = 'yes';   
    cfg.hpfreq   = hpFreq;
    cfg.lpfilter = 'yes';   
    cfg.lpfreq   = lpFreq;  
    preprocessed = ft_preprocessing(cfg, zaplineData); 
    
    % Preserve dataset name  (lost during filtering)
    preprocessed.cfg.dataset = eegData.cfg.dataset;
    

end