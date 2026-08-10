function neighbours = sct_computeNeighbours(elec)
%SCT_COMPUTENEIGHBOURS Finds channel neighbours for spatial interpolation
%
%   neighbours = SCT_COMPUTENEIGHBOURS(elec) computes, for each channel
%   in elec, the set of neighbouring channels within a fixed distance,
%   using FieldTrip's distance-based method. Used to interpolate bad/
%   missing channels (e.g. CPz).
%
%   Input:
%       elec - FieldTrip electrode structure, as returned by
%              sct_createLayout
%
%   Output:
%       neighbours - FieldTrip neighbour structure, one entry per
%                    channel listing its neighbouring channels
%
%   Example:
%       neighbours = sct_computeNeighbours(elec);
%
%   See also SCT_INTERPOLATE, SCT_CREATELAYOUT


    %% Find the channel neighbours for interpolation of bad/missing channel(s)
    % neighbourDist chosen empirically, following FieldTrip's own tutorial
    % guidance to tune cfg.neighbourdist by inspection until neighbour
    % assignments look sensible.
    neighbourDist = 50;  % mm, max distance to count as a neighbour

    cfg = [];
    cfg.method = 'distance';
    cfg.neighbourdist = neighbourDist;
    cfg.elec = elec;
    cfg.feedback = 'no';
    neighbours = ft_prepare_neighbours(cfg);
      
end