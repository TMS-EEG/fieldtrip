function test_ft_clusterplot

% MEM 10gb
% WALLTIME 00:20:00
% DEPENDENCY ft_clusterplot ft_statistics_montecarlo ft_timelockstatistics clusterstat findcluster
% DATA public

cd(dccnpath('/project/3031000.02/external/download/tutorial/eventrelatedstatistics'));

% use the tutorial on http://www.fieldtriptoolbox.org/tutorial/eventrelatedstatistics

load ERF_orig
load GA_ERF_orig

cfg = [];
cfg.method      = 'template';
cfg.template    = 'ctf151_neighb.mat';               % specify type of template
cfg.layout      = 'CTF151.lay';                      % specify layout of sensors*
cfg.feedback    = 'yes';                             % show a neighbour plot
neighbours      = ft_prepare_neighbours(cfg, GA_FC); % define neighbouring channels

cfg = [];
cfg.channel     = 'MEG';
cfg.neighbours  = neighbours; % defined as above
cfg.latency     = [-0.25 1];
cfg.avgovertime = 'no';
cfg.parameter   = 'avg';
cfg.method      = 'montecarlo';
cfg.statistic   = 'ft_statfun_depsamplesT';
cfg.alpha       = 0.05;
cfg.correctm    = 'cluster';
cfg.correcttail = 'prob';
cfg.numrandomization = 'all';
cfg.minnbchan        = 2; % minimal neighbouring channels
Nsub = 10;
cfg.design(1,1:2*Nsub)  = [ones(1,Nsub) 2*ones(1,Nsub)];
cfg.design(2,1:2*Nsub)  = [1:Nsub 1:Nsub];
cfg.ivar                = 1; % the 1st row in cfg.design contains the independent variable
cfg.uvar                = 2; % the 2nd row in cfg.design contains the subject number
stat = ft_timelockstatistics(cfg,allsubjFIC{:},allsubjFC{:});

%% chan_time, this is the original one
cfg = [];
cfg.highlightsymbolseries = ['*','*','.','.','.'];
cfg.layout = 'CTF151.lay';
cfg.contournum = 0;
cfg.markersymbol = '.';
cfg.alpha = 0.05;
cfg.parameter='stat';
cfg.zlim = [-5 5];
cfg.toi  = [-0.1:0.1:0.9];
ft_clusterplot(cfg,stat);

%% chan_freq
stat.freq = 1:376;
cfg.toi = [20:20:200];
stat = rmfield(stat, 'time');
stat.dimord = 'chan_freq';

ft_clusterplot(cfg,stat);

%% chan_freq_time with singleton time
stat.time = 1;
stat.dimord = 'chan_freq_time';
cfg.toi = [20:20:200];

ft_clusterplot(cfg,stat);

%% chan_freq_time with singleton freq
stat.time = 1:376;
stat.freq = 1;
stat.dimord = 'chan_freq_time';

% insert the singleton dimension in the data
stat.posclusterslabelmat = reshape(stat.posclusterslabelmat, [151 1 376]);
stat.negclusterslabelmat = reshape(stat.negclusterslabelmat, [151 1 376]);
stat.prob     = reshape(stat.prob,    [151 1 376]);
stat.cirange  = reshape(stat.cirange, [151 1 376]);
stat.mask     = reshape(stat.mask,    [151 1 376]);
stat.stat     = reshape(stat.stat,    [151 1 376]);
stat.ref      = reshape(stat.ref,     [151 1 376]);
                    
cfg.toi = [20:20:200];

ft_clusterplot(cfg,stat);

