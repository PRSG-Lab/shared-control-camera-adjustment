function cfg=jog_config_v2(profile)
%JOG_CONFIG_V2 Complete legacy + revision design; never launches paper implicitly.
if nargin==0,profile='smoke';end
cfg=jog_config(profile);
cfg.schema_version='jog-output-2.1';
cfg.enabled=arrayfun(@(j)sprintf('J%02d',j),0:15,'UniformOutput',false);
cfg.revision_seed=3009162026+find(strcmp(profile,{'smoke','pilot','paper'}))-1;
cfg.analysis_seed=3009162029;cfg.rng_type='mrg32k3a';cfg.normal_transform='Inversion';
cfg.batch_size=25;cfg.source_runs={};cfg.analyze=true;cfg.make_figures=true;
cfg.fig_dpi=600;cfg.figure_visible='off';cfg.export_eps=false;
cfg.j10.regimes=[30 .15;30 .05;30 .02;13 .15];
cfg.j10.scales=[.03 .1 .3 1 2];cfg.j10.geometry_source_run='';
cfg.j11.extensions={};cfg.j11.alpha=[.25 .5 1 2 4];
cfg.j11.groups=[2 9 16];cfg.j11.length_factors=[.25 1 4];
cfg.j12.regimes=cfg.j10.regimes;cfg.j12.geometries=20;cfg.j12.maps=200;
cfg.j13.points=[13 30 60];cfg.j13.rotation_deg=[.005 .01];
cfg.j13.translation_std=.02;cfg.j13.scale_std=20e-6;cfg.j13.pivot_shift=[20;0;0];
cfg.j14.scenarios=[.02 .02 0;.005 .02 0;.005 .03 .03];
cfg.j15.grid_size=5;cfg.j15.halfwidth_fraction=.25;cfg.j15.depth=20;
cfg.j15.source_suites={'J09','J10','J11'};
cfg.analysis.bootstrap=2000;cfg.analysis.cluster_distance=[1e-6 1e-5 1e-4];
cfg.analysis.cluster_cost=[1e-8 1e-7 1e-6];
cfg.j16.enabled=false;cfg.j16.modules={'hessian','reparameterization'};
cfg.j16.steps=[.02 .01 .005];cfg.j16.outer_maps=100;cfg.j16.inner_maps=500;
cfg.j16.bootstrap_region='calibrated_wald';
cfg.preflight.max_estimated_gib=Inf;cfg.preflight.min_free_gib=2;
cfg.max_batches_per_session=Inf; % finite for deliberate interruption test
cfg.parallel=false; % deterministic serial reference; parallel extension not required
switch profile
 case 'smoke',cfg.j12.geometries=2;cfg.j12.maps=3;cfg.analysis.bootstrap=100;
  cfg.j16.outer_maps=2;cfg.j16.inner_maps=10;
 case 'pilot',cfg.j12.geometries=5;cfg.j12.maps=50;
 case 'paper'
 otherwise,error('jog2:profile','Use smoke/pilot/paper');
end
end
