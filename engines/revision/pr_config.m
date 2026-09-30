function opt=pr_config(profile)
% No experiment launches here. paper uses ALL retained maps for postprocessing.
if nargin<1,profile='paper';end
assert(ismember(profile,{'smoke','pilot','paper'}),'Use smoke/pilot/paper');
opt=struct('version','PR-revision-1.0','profile',profile,'max_tasks',Inf,'make_figures',true,'dpi',600);
opt.source_file='';opt.target_condition_ids={}; % empty: reference, shallow, global60
opt.diagnostic_condition_ids={}; % empty: J09 reference/shallow/global, J10, J11 M4
opt.max_source_batches=Inf;opt.methods={'GH_LOCAL','GH_FULL'};
opt.target.depths=[10 20 40];opt.target.tilts_deg=[60 75];opt.target.oblique_depth=20;
opt.target.grid_size=5;opt.target.halfwidth_fraction=.25;opt.target.oblique_halfwidth_fraction=.10;
opt.target.derivative_step_multiplier=1;
opt.gaussian.draws=1000000;opt.gaussian.seed=22092026;opt.gaussian.chunk=50000;
opt.bias.geometry_ids=1:4;opt.bias.scales=[.1 .3 1];opt.bias.steps=[.02 .01 .005];
opt.bias.max_directions=Inf;opt.bias.step_tolerance=1e-10;opt.bias.constraint_tolerance=1e-11;
opt.bias.relative_step_tolerance=.10; % diagnosis flag, not a statistical test
opt.additional.rotation_deg=[.05 .1];opt.additional.points=[13 30 60];
opt.additional.methods={'GH_LOCAL','GH_FULL'};opt.additional.maps=2000;opt.additional.batch_size=25;
opt.additional.noise_model='additive_first_order_similarity';
opt.reparameterization.condition_id=''; % empty: J10 n30, depth .02, epsilon1
opt.reparameterization.max_maps=2000;
switch profile
 case 'smoke'
  opt.max_source_batches=1;opt.gaussian.draws=10000;opt.dpi=120;
  opt.bias.geometry_ids=1;opt.bias.steps=[.02 .01];opt.bias.max_directions=3;
  opt.additional.rotation_deg=.05;opt.additional.points=13;opt.additional.maps=3;opt.additional.batch_size=2;
  opt.reparameterization.max_maps=3;
 case 'pilot'
  opt.max_source_batches=4;opt.gaussian.draws=100000;opt.dpi=300;
  opt.additional.maps=100;opt.additional.batch_size=25;opt.reparameterization.max_maps=100;
end
end
