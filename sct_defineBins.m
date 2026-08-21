function icaCleanTrials = sct_defineBins(icaCleanTrials)
%SCT_DEFINEBINS Labels trials into congruency x feedback bins
%   Classifies each trial by stimulus congruency (congruent / incongruent)
%   and feedback type (reward / punishment), then combines the two into a
%   single bin code stored in a new trialinfo column. Trials missing a
%   recognized stimulus or feedback event code (e.g. error/no-response
%   trials, marked with 'STATUS' events S6/S7 - see sct_defineTrials) are
%   left unbinned with a bin code of 0.
%
%   Bin codes (stimType*10 + fbType):
%       11 - congruent,   rewarded
%       12 - congruent,   punished
%       21 - incongruent, rewarded
%       22 - incongruent, punished
%        0 - unbinned (missing stimulus and/or feedback event code)
%
%   Input:
%       icaCleanTrials - FieldTrip data struct (post-ICA cleaned
%                        trials) with a trialinfo matrix of the form:
%                        [trial type (train=1/test=2), stimulus event
%                        code, response event code, feedback event code]
%
%   Output:
%       icaCleanTrials - same struct with a 5th trialinfo column added,
%                        containing the bin code for each trial
%
%   Example:
%       icaCleanTrials = sct_defineBins(icaCleanTrials);
%
%   See also SCT_DEFINETRIALS, SCT_REJECTARTIFACTS

    % trialinfo column indices
    colStim = 2;   % stimulus event code
    colFb   = 4;   % feedback event code
    colBin  = 5;   % bin code (added by this function)

    % Stimulus congruency event codes
    congruentStimCodes   = [111, 112, 113, 114, 211, 212, 213, 214];
    incongruentStimCodes = [121, 122, 123, 124, 221, 222, 223, 224];

    % Feedback event codes ('FB' events - see sct_defineTrials)
    fbRewardCode = 8;
    fbPunishCode = 9;

    % Stimulus/feedback type labels used to build the bin code
    stimCongruent   = 1;
    stimIncongruent = 2;
    fbReward        = 1;
    fbPunish        = 2;

    nTrials = size(icaCleanTrials.trial, 2);

    % Initialize the bin code column; trials that don't match a
    % recognized stimulus/feedback code keep the default value of 0
    icaCleanTrials.trialinfo(:, colBin) = 0;

    for trialIdx = 1:nTrials

        % Classify stimulus congruency
        stimType = 0;
        if ismember(icaCleanTrials.trialinfo(trialIdx, colStim), congruentStimCodes)
            stimType = stimCongruent;
        elseif ismember(icaCleanTrials.trialinfo(trialIdx, colStim), incongruentStimCodes)
            stimType = stimIncongruent;
        end

        % Classify feedback type
        fbType = 0;
        if icaCleanTrials.trialinfo(trialIdx, colFb) == fbRewardCode
            fbType = fbReward;
        elseif icaCleanTrials.trialinfo(trialIdx, colFb) == fbPunishCode
            fbType = fbPunish;
        end

        % Combine into a single bin code; a valid bin requires both a
        % recognized stimulus and feedback code (trials otherwise stay
        % unbinned with a code of 0)
        if (stimType > 0) && (fbType > 0)
            icaCleanTrials.trialinfo(trialIdx, colBin) = stimType*10 + fbType;
        end

    end

end
