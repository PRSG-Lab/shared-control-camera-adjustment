function cfg = jog_config(profile)
%JOG_CONFIG Reproducible simulation settings; base MATLAB only.
% Profiles have different seeds. Paper is a proposed final configuration,
% not an assertion that the results are ready for publication.
if nargin==0, profile='pilot'; end
cfg.schema_version='jog-output-1.0';
cfg.profile=char(profile); cfg.enabled={'J00','J01','J02','J03','J04','J05','J06','J07','J08','J09'};
cfg.master_seed=1009162026;
cfg.mc_linear=1000; cfg.mc_plane=1000; cfg.mc_nonlinear=100;
cfg.identity_cases=50;
cfg.nominal=[.50 .80 .90 .95 .99];
cfg.fig_dpi=300; cfg.figure_visible='off';
cfg.save_candidate_history=true;
cfg.linear.s=[10 30 100 300 1000 3000 10000];
cfg.linear.rho=[0 .3 .6 .9]; cfg.linear.tau=[0 .1 .3 1 3 10];
cfg.linear.rates=[.25 .5 .75];
cfg.plane.f=3500; cfg.plane.gamma_z=1.5; cfg.plane.depths=[10 15 20 25];
cfg.plane.n=[4 10 30 100 300 1000];
cfg.plane.region_std=[.02 .10]; cfg.plane.image_std=.5;
cfg.plane.local_depth_std=.02; cfg.plane.horizontal_radius=1.5;
cfg.plane.group_counts=[2 4 8 16];
cfg.plane.depth_spreads=[.02 .05 .10 .20 .40 .60];
cfg.plane.global_stds=[0 .01 .03 .06 .10];
cfg.plane.guard_lambda=[1 10000]; cfg.plane.guard_min_information=1e-8;
cfg.plane.fallback=[0;3000];
cfg.camera.width=6000; cfg.camera.height=4000; cfg.camera.scale=3000;
cfg.camera.gamma=[2;-1;1.5]; cfg.camera.rotvec=[.15;-.10;.05];
cfg.camera.f=3500; cfg.camera.pp=[25;-15]; cfg.camera.kappa=-.08;
cfg.camera.mean_depth=20; cfg.camera.occupancy=.75;
cfg.camera.local_image_std=.5; cfg.camera.local_xyz_std=.02;
cfg.camera.patch_std=.02; cfg.camera.global_std=.05;
cfg.camera.anisotropy=1;
cfg.nonlinear.noise_scales=[.1 .3 1 2];
cfg.nonlinear.depth_spreads=[.02 .05 .15 .30];
cfg.nonlinear.point_counts=[13 30 60];
cfg.nonlinear.baseline_points=30; cfg.nonlinear.baseline_spread=.15;
cfg.nonlinear.methods={'FIXED3D_WLS','GH_LOCAL','GH_MARGDIAG','GH_FULL'};
cfg.nonlinear.initialization='observed_DLT_multistart';
% The separate oracle diagnostic mode may be selected explicitly. It is
% labeled in output and is never mixed with practical end-to-end results.
cfg.nonlinear.kappa_initial=[-.15 0 .15];
cfg.solver.max_iterations=100; cfg.solver.max_linesearch=18;
cfg.solver.step_tolerance=2e-8; cfg.solver.constraint_tolerance=2e-9;
cfg.solver.rank_tolerance=1e-10;
cfg.solver.focal_range=[300 30000]; cfg.solver.kappa_range=[-.8 .8];
cfg.solver.principal_point_absmax=6000;
cfg.solver.parameter_scale=[20;20;20;1;1;1;1;1;3000;3000];
switch lower(cfg.profile)
 case 'smoke'
  cfg.master_seed=9162026; cfg.mc_linear=80; cfg.mc_plane=80; cfg.mc_nonlinear=3;
  cfg.identity_cases=10;
 case 'pilot'
  % Defaults above. Final seeds differ from pilot seeds.
 case 'paper'
  cfg.master_seed=2009162026; cfg.mc_linear=5000; cfg.mc_plane=3000;
  cfg.mc_nonlinear=2000; cfg.identity_cases=200;
 otherwise, error('jog:profile','Use smoke, pilot, or paper.');
end
end
