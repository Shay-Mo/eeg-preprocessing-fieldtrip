function [elec, layout] = sct_createLayout(layoutFilename)
%SCT_CREATELAYOUT Builds electrode positions and a 2D layout for plotting/interpolation
%
%   [elec, layout] = SCT_CREATELAYOUT(layoutFilename) reads electrode
%   positions from a BIDS-style electrodes TSV file, removes the EOG
%   channel, adds the CPz channel (missing from the recording since it
%   was the online reference), and computes a 2D layout for plotting/interpolating.
%
%   Input:
%       layoutFilename - (string) full path to the electrode positions
%                        (BIDS electrodes.tsv) file
%
%   Output:
%       elec   - FieldTrip electrode structure (EOG removed, CPz added)
%       layout - FieldTrip 2D layout structure, for plotting/interpolating
%
%   Example:
%       [elec, layout] = sct_createLayout('/data/sub-001_electrodes.tsv');
%
%   See also SCT_INTERPOLATE, SCT_INSPECTICA, SCT_PLOTERPS


    %% Read electrode positions from the custom TSV file
    elec = ft_read_sens(layoutFilename, 'senstype', 'eeg', 'readbids', 'yes');

    %% Remove the EOG row
    eogIdx = strcmpi(elec.label, 'EOG');
    elec.label(eogIdx) = [];
    elec.chanpos(eogIdx, :) = [];
    elec.elecpos(eogIdx, :) = [];
    elec.chantype(eogIdx) = [];
    elec.chanunit(eogIdx) = [];

    %% Add CPz manually if not already present
    % CPz is missing from the recording (it was the online reference channel). 
    % Its coordinates are estimated as the midpoint between Cz and Pz, 
    % since electrode positions are fixed across subjects in this montage.
    if ~any(strcmpi(elec.label, 'CPz'))
        czIdx = strcmpi(elec.label, 'Cz');
        pzIdx = strcmpi(elec.label, 'Pz');
        cpzCoord = (elec.chanpos(czIdx, :) + elec.chanpos(pzIdx, :)) / 2;

        elec.label{end+1} = 'CPz';
        elec.chanpos(end+1, :) = cpzCoord;
        elec.elecpos(end+1, :) = cpzCoord;
        elec.chantype{end+1} = 'eeg';
        elec.chanunit{end+1} = 'V';
    end
   
    %% Create a layout from the elec structure
    cfg = [];
    cfg.elec = elec;
    cfg.projection = 'polar';
    cfg.rotate = 90;  
    cfg.feedback = 'no';
    layout = ft_prepare_layout(cfg);

end