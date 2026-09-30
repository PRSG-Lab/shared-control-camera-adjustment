function report=pr_selftest(source,destination)
% Bounded runtime tests; uses only 1 retained batch per selected condition,
% 3 additional-camera maps, 12 Hessian local fits, and 3 direct-focal fits.
pr_setup();
for cl={'IO','Targets','Diagnostics','Additional','Reports'},assert(~isempty(meta.class.fromName(['prrev.' cl{1}])));end
for fn={'pr_run_postprocess','pr_run_additional','pr_run_bias','pr_run_reparameterization'},nargin(fn{1});end
if nargin<1,source=prrev.IO.source('');end
if nargin<2,destination=fullfile(tempdir,['pr_revision_test_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);end
assert(~isfolder(destination),'Use a NEW selftest destination');mkdir(destination);
before=dir(source);opt=pr_config('smoke');opt.target_condition_ids={'J09c003','J09c005','J09c012'};opt.diagnostic_condition_ids={'J11c002'};
% Analytical reference distribution test: C_true=C_reported must be chi-square.
a=opt.gaussian;a.draws=50000;q=prrev.Diagnostics.gaussian(eye(10),eye(10),a,1);
assert(all(abs(q.eigenvalues-1)<1e-12)&&abs(q.coverage-.95)<.005,'Gaussian reference distribution failed');
% Deterministic directional trace identity on a quadratic vector function.
G=[2 .2;0 1];H=[3 .7;.7 2];h=.01;v=0;
for i=1:2,fun=@(x).5*x'*H*x;v=v+(fun(h*G(:,i))+fun(-h*G(:,i))-2*fun(zeros(2,1)))/h^2;end
assert(abs(.5*v-.5*trace(H*(G*G')))<1e-10,'Hessian contraction identity failed');
% Raw read, target Jacobian, and native chart consistency at exact truth.
o=jog2.Store.metadata(source);ii=prrev.Diagnostics.select(o,opt,'target');d=jog2.Store.design(source,o.conditions{ii(1)});ts=prrev.Targets.design(d.geometry,o.config,opt.target);
for j=1:numel(ts)
 assert(all(ts{j}.truth_valid),'Default target ray does not intersect plane physically');
 [y,J]=jog2.Target.values(d.geometry.truth_camera,ts{j},'plane',1);[~,J2]=jog2.Target.values(d.geometry.truth_camera,ts{j},'plane',2);
 assert(max(abs(y-ts{j}.plane_truth),[],'all')<1e-9&&norm(J(:)-J2(:))/norm(J(:))<1e-5,'Target/Jacobian check failed');
end
% Cache resume must skip completed work; immutable source, relocatable output.
folder=fullfile(destination,'post');opt.max_tasks=1;f=pr_run_postprocess(source,folder,opt);assert(endsWith(f,'checkpoint.mat'));
p=fullfile(folder,'checkpoints','target_003_batch_0001.mat');old=dir(p);assert(~isempty(old));
opt.max_tasks=Inf;f=pr_run_postprocess(source,folder,opt);now=dir(p);assert(old.datenum==now.datenum,'Completed task was recomputed');
r=load(f,'output');assert(r.output.complete&&numel(r.output.results.target_conditions)==3);
for i=1:3,ss=r.output.results.target_conditions{i};assert(ss.n_total==25&&~ss.complete_source);end
alone=fullfile(destination,'standalone.mat');copyfile(f,alone);x=pr_read_payload(alone,r.output.data_index{1}.prefix);assert(~isempty(x));
% Checkpoint identity guard on changed computation settings.
bad=opt;bad.target.depths=[10 20 50];caught=false;
try,pr_run_postprocess(source,folder,bad);catch ME,caught=strcmp(ME.identifier,'PR:ResumeMismatch');end
assert(caught,'Changed config incorrectly reused checkpoint');
% Additional case resumption; does not run J09-J12.
folder=fullfile(destination,'rotation');opt.max_tasks=1;f=pr_run_additional(source,folder,opt);assert(endsWith(f,'checkpoint.mat'));
opt.max_tasks=Inf;f=pr_run_additional(source,folder,opt);a=load(f,'output');assert(numel(a.output.results.conditions)==1);assert(a.output.results.conditions{1}.spec.N==3);
% Incomplete Hessian trace MUST NOT yield a paper-level predicted bias.
f=pr_run_bias(source,fullfile(destination,'bias'),opt);a=load(f,'output');g=a.output.results.geometries{1};assert(~any(g.complete_trace)&&all(isnan(g.b2(:))));
f=pr_run_reparameterization(source,fullfile(destination,'direct_focal'),opt);a=load(f,'output');assert(numel(a.output.results.rows)==3);
after=dir(source);assert(before.bytes==after.bytes&&before.datenum==after.datenum,'Source file changed');
report=struct('status','passed','matlab',version,'source',source,'source_bytes_unchanged',true,'source_timestamp_unchanged',true,...
 'gaussian_equal_covariance_coverage',q.coverage,'hessian_trace_identity',true,'target_jacobian',true,...
 'postprocess_resume',true,'rotation_resume',true,'cache_identity_guard',true,'self_contained_output',true,'incomplete_bias_rejected',true,...
 'scope','Bounded smoke validation only; full paper simulations and complete Hessian trace not executed','result_folder',destination);
fid=fopen(fullfile(destination,'test_report.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);disp(report);
end
