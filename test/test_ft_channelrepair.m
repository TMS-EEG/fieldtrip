function test_ft_channelrepair

% MEM 1gb
% WALLTIME 00:10:00
% DEPENDENCY ft_channelrepair ft_datatype_sens fixsens ft_prepare_neighbours
% DATA private

datainfo = ref_datasets;

% get an MEG and an EEG set (hard-coded
eeginfo = datainfo(3);
meginfo = datainfo(7);

% do the MEG processing
fname = fullfile(meginfo.origdir,'latest', 'raw',meginfo.type,['preproc_' meginfo.datatype]);
load(fname);

cfg = [];
cfg.method = 'triangulation';
neighbours = ft_prepare_neighbours(cfg, data);

cfg = [];
cfg.badchannel = data.label(100);
cfg.neighbours = neighbours;
newdata = ft_channelrepair(cfg, data);

% now, also check whether an absent sensor array description works, as per
% issue 1774 it doesn't
try
  newdata = ft_channelrepair(cfg, removefields(data, {'elec', 'grad'}));
catch
  fprintf('running a ''weighted'' interpolation without sensor info does not work\n');
end
cfg.method = 'average';
newdata = ft_channelrepair(cfg, removefields(data, {'elec', 'grad'}));

% rumour has it, that this should work: it indeed did at some point, but
% shouldn't work. This has been changed by an explicit call to
% ft_checkconfig
% cfg.method = 'weighted';
% cfg.layout = '4D248_helmet.mat';
% newdata   = ft_channelrepair(cfg, removefields(data, {'elec', 'grad'}));

% % do the EEG processing: this does not work, because there's no example EEG data
% with sensor positions 
% fname = [eeginfo.origdir,'raw/',eeginfo.type,'preproc_',eeginfo.datatype];
% load(fname);
% 
% cfg = [];
% cfg.method = 'template';
% cfg.template = 'EEG1010_neighb.mat';
% neighbours = ft_prepare_neighbours(cfg);
% 
% cfg = [];
% cfg.badchannel = data.label(10);
% cfg.neighbours = neighbours;
% newdata = ft_channelrepair(cfg, data);


%% part 2 - missing channels and EEG data
% make use of bug941 data
% load data
load(dccnpath('/project/3031000.02/test/bug941.mat'));

% treat as a bad channel
data_eeg_clean.elec = elec_new;

cfg = [];
cfg.badchannel = {'25'};
cfg.neighbours = neighbours;
data_eeg_repaired = ft_channelrepair(cfg,data_eeg_clean);

cfg = [];
cfg.channel = {'19','20','24','25','26'};
ft_databrowser(cfg, data_eeg_repaired);

% treat as a missing channel
data_eeg_miss = data_eeg_clean;
data_eeg_miss.label(25) = []; % remove channel 25

for i=1:numel(data_eeg_miss.trial) 
  data_eeg_miss.trial{i}(25, :) = []; % remove data from channel 25
end

cfg = [];
cfg.missingchannel = {'25'};
cfg.neighbours = neighbours;
data_eeg_interp = ft_channelrepair(cfg,data_eeg_miss);

cfg = [];
cfg.channel = {'19','20','24','25','26'};
ft_databrowser(cfg, data_eeg_interp);

% check for each trial whether the value for channel 25 is in between its 
% neighbours (it's now the last channel), and equals data_eeg_repaired
cfg.neighbours = [19 20 24 26];
for tr=1:numel(data_eeg_interp.trial)
  tmp = repmat(data_eeg_interp.trial{tr}(end, :), 4, 1);
  if all(tmp < data_eeg_interp.trial{tr}(cfg.neighbours, :)) | ...
      all(tmp > data_eeg_interp.trial{tr}(cfg.neighbours, :))
    error(['The average is not in between its channel neighbours at for trial ' num2str(tr)]);
  elseif ~all(data_eeg_interp.trial{tr}(end, :) == data_eeg_repaired.trial{tr}(25, :))
    error('The reconstruction of the same channel differs when being treated as a missing channel compared to a bad channel');
  else
    fprintf('trial %i is fine\n', tr);
  end
end

%% part 3 - spherical spline interpolation
% again make use of bug941 data
% load data

% treat as a bad channelcfg = [];
cfg.badchannel = {'25'};
cfg.neighbours = neighbours;
cfg.method     = 'spline';
% juggle around the channel labels & data 
data_eeg_juggled = data_eeg_clean;
chanidx = randperm(numel(data_eeg_juggled.label));
data_eeg_juggled.label = data_eeg_clean.label(chanidx);

for i=1:numel(data_eeg_miss.trial) 
  data_eeg_juggled.trial{i} = data_eeg_clean.trial{i}(chanidx, :); 
end
data_eeg_repaired_spline = ft_channelrepair(cfg,data_eeg_juggled);

cfg = [];
cfg.channel = {'19','20','24','25','26'};
cfg.continuous = 'no';
ft_databrowser(cfg, data_eeg_repaired_spline);

% treat as a missing channel
data_eeg_miss = data_eeg_clean;
chan_idx = ismember(data_eeg_miss.label, '25');
data_eeg_miss.label(chan_idx) = []; % remove channel 25

for i=1:numel(data_eeg_miss.trial) 
  data_eeg_miss.trial{i}(chan_idx, :) = []; % remove data from channel 25
end

cfg = [];
cfg.missingchannel = {'25'};
cfg.neighbours = neighbours;
cfg.method     = 'spline';
data_eeg_interp_spline = ft_channelrepair(cfg,data_eeg_miss);

cfg = [];
cfg.channel = {'19','20','24','25','26'};
ft_databrowser(cfg, data_eeg_interp_spline);

% check for each trial whether the value for channel 25 is in between its 
% neighbours (it's now the last channel), and equals data_eeg_repaired
cfg.neighbours = [19 20 24 26];
for tr=1:numel(data_eeg_interp_spline.trial)
  %
  % spline interpolation does not yield to an average of all channels!
  %
  
  %tmp = repmat(data_eeg_interp.trial{tr}(end, :), 4, 1);  
  %if all(tmp < data_eeg_interp.trial{tr}(cfg.neighbours, :)) | ...
  %    all(tmp > data_eeg_interp.trial{tr}(cfg.neighbours, :))
  %  error(['The average is not in between its channel neighbours at for trial ' num2str(tr)]);
  %else
  %meandiff = min(median(abs(data_eeg_interp_spline.trial{tr}(25:end, :) - data_eeg_repaired_spline.trial{tr}(25:end, :))));
  idx = ismember(data_eeg_interp_spline.label, '25');
  if find(idx)~=numel(data_eeg_interp_spline.label)
      error('missing channel was not concatenated to the labels');
  end
  a = data_eeg_interp_spline.trial{tr}(idx, :);
  idx = ismember(data_eeg_repaired_spline.label, '25');
  b = data_eeg_repaired_spline.trial{tr}(idx, :);
  if ~isalmostequal(a, b, 'reltol', 0.001) % 0.1% i.e. nearly ==0
    disp(['relative difference is: ' num2str(max(abs(a-b)./(0.5*(a+b))))]); 
    error('The reconstruction of the same channel differs when being treated as a missing channel compared to a bad channel');
  else
    fprintf('trial %i is fine\n', tr);
  end
end

%% use the new 'average' method
% load data
load(dccnpath('/project/3031000.02/test/bug941.mat'));

% treat as a bad channel
data_eeg_clean.elec = elec_new;
cfg = [];
cfg.badchannel = {'25'};
cfg.neighbours = neighbours;
cfg.method = 'average';
data_eeg_repaired = ft_channelrepair(cfg,data_eeg_clean);

cfg = [];
cfg.channel = {'19','20','24','25','26'};
ft_databrowser(cfg, data_eeg_repaired);

% treat as a missing channel
data_eeg_miss = data_eeg_clean;
data_eeg_miss.label(25) = []; % remove channel 25

for i=1:numel(data_eeg_miss.trial) 
  data_eeg_miss.trial{i}(25, :) = []; % remove data from channel 25
end

cfg = [];
cfg.missingchannel = {'25'};
cfg.neighbours = neighbours;
cfg.method = 'average';
data_eeg_interp = ft_channelrepair(cfg,data_eeg_miss);

cfg = [];
cfg.channel = {'19','20','24','25','26'};
ft_databrowser(cfg, data_eeg_interp);

% check for each trial whether the value for channel 25 is in between its 
% neighbours (it's now the last channel), and equals data_eeg_repaired
cfg.neighbours = [19 20 24 26];
for tr=1:numel(data_eeg_interp.trial)
  tmp = repmat(data_eeg_interp.trial{tr}(end, :), 4, 1);
  if all(tmp < data_eeg_interp.trial{tr}(cfg.neighbours, :)) | ...
      all(tmp > data_eeg_interp.trial{tr}(cfg.neighbours, :))
    error(['The average is not in between its channel neighbours at for trial ' num2str(tr)]);
  elseif ~all(data_eeg_interp.trial{tr}(end, :) == data_eeg_repaired.trial{tr}(25, :))
    error('The reconstruction of the same channel differs when being treated as a missing channel compared to a bad channel');
  else
    fprintf('trial %i is fine\n', tr);
  end
end

%% part 4 - deal with bad channels that are neighbours of each other

data_bad = [];
data_bad.label = {'1', '2', '3', '4'};
data_bad.trial{1} = zeros(4,1000);
data_bad.trial{1}(1,:) = 1;
data_bad.trial{1}(2,:) = nan;  % bad channel
data_bad.trial{1}(3,:) = nan;  % bad channel
data_bad.trial{1}(4,:) = 4;
data_bad.time{1} = (1:1000)/1000;

cfg = [];
cfg.trials = 1;
cfg.badchannel = []; % the nans will be auto-detected as bad
cfg.method = 'average';

cfg.neighbours(1).label = '1';
cfg.neighbours(1).neighblabel = {'1', '2', '3', '4'};
cfg.neighbours(2).label = '2';
cfg.neighbours(2).neighblabel = {'1', '2', '3', '4'};
cfg.neighbours(3).label = '3';
cfg.neighbours(3).neighblabel = {'1', '2', '3', '4'};
cfg.neighbours(4).label = '4';
cfg.neighbours(4).neighblabel = {'1', '2', '3', '4'};

data_repaired = ft_channelrepair(cfg, data_bad);

% this is how it was before, the result is not what you would expect because the bad channels are neighbours of each other
%
% data_repaired.trial{1}(:,1)
% ans =
%      1
%      0
%      0
%      4

% this is how it is after updating the code such that bad channels are removed from the neighbours
%
% data_repaired.trial{1}(:,1)
% ans =
%     1.0000
%     2.5000
%     2.5000
%     4.0000

assert(data_repaired.trial{1}(1)==1)
assert(data_repaired.trial{1}(2)==2.5)
assert(data_repaired.trial{1}(3)==2.5)
assert(data_repaired.trial{1}(4)==4)

