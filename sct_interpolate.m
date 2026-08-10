function interpolated = sct_interpolate(preprocessed, layoutFilename, flag)
%SCT_INTERPOLATE Recreates the CPz reference channel via spatial interpolation
%
%   interpolated = SCT_INTERPOLATE(preprocessed, layoutFilename, flag)
%   recreates (interpolates) the CPz channel — the online reference
%   channel during recording, which therefore contains no signal — using
%   spatial interpolation from neighbouring electrodes.
%
%   Input:
%       preprocessed   - FieldTrip data structure
%       layoutFilename - (string) full path to the electrode positions file
%       flag           - (string) processing stage at which this function
%                        is called; either 'pre-ICA' or 'post-ICA'. When
%                        'pre-ICA', the original dataset name is
%                        reattached to the output (lost during
%                        interpolation); when 'post-ICA', it is not.
%
%   Output:
%       interpolated - FieldTrip data structure with CPz recreated
%
%   Example:
%       interpolated = sct_interpolate(preprocessed, ...
%           '/data/sub-001_electrodes.tsv', 'pre-ICA');
%
%   See also SCT_PIPELINE, SCT_CREATELAYOUT, SCT_COMPUTENEIGHBOURS

    %% Validate flag
    if ~(strcmp(flag, 'pre-ICA') || strcmp(flag, 'post-ICA'))
        error('sct_interpolate:invalidFlag', ...
            'flag must be either ''pre-ICA'' or ''post-ICA'' (got ''%s'').', flag);
    end

    %% Load electrode positions and compute neighbours
    fprintf('\n\t--> Loading electrode layout and computing neighbours...\n');
    
    [elec, layout] = sct_createLayout(layoutFilename);
    neighbours = sct_computeNeighbours(elec);

    %% Interpolate CPz
    channels = {'CPz'};

    cfg = [];
    cfg.elec = elec;
    cfg.layout = layout;
    cfg.method = 'spline';
    cfg.badchannel = channels;
    cfg.neighbours = neighbours;
    interpolated = ft_channelrepair(cfg, preprocessed);

    % Preserve dataset name (only needed before ICA re-labels the data)
    if strcmp(flag, 'pre-ICA')
        interpolated.cfg.dataset = preprocessed.cfg.dataset;
    end

end