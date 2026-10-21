function sct_plotTrials(trials, plotTitle)
%SCT_PLOTTRIALS Opens an interactive FieldTrip databrowser for visual trial inspection
%   Displays the given trial data in ft_databrowser's vertical view mode
%   for subjective visual review of the EEG signal (e.g. comparing the
%   signal before vs. after ICA-based artifact rejection), with a title
%   banner overlaid above the plot.
%
%   Input:
%       trials    - FieldTrip data struct to display
%       plotTitle - (string, optional) title banner shown above the plot;
%                   defaults to 'Trials' if omitted
%
%   Output:
%       (none) - opens an interactive ft_databrowser figure
%
%   Example:
%       sct_plotTrials(cleanTrials, 'Before ICA');
%       sct_plotTrials(icaCleanTrials, 'After ICA');
%
%   See also SCT_PIPELINE, FT_DATABROWSER

    if nargin < 2
        plotTitle = 'Trials';
    end

    % Amplitude display range (uV) for the databrowser y-axis
    amplitudeLim = [-8 8];

    % Title banner position: [x y width height], normalized figure units
    titleBoxPosition = [0.35 0.94 0.3 0.05];

    cfg = [];
    cfg.viewmode = 'vertical';
    cfg.ylim = amplitudeLim;
    figsBefore = findall(0, 'Type', 'figure');
    
    ft_databrowser(cfg, trials);

    figsAfter = findall(0, 'Type', 'figure');
    browserFig = setdiff(figsAfter, figsBefore);

    annotation(browserFig(1), 'textbox', titleBoxPosition, ...
        'String', plotTitle, ...
        'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 12, ...
        'FontWeight', 'bold');

end
