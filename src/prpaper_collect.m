function DATA=prpaper_collect(input)
%PRPAPER_COLLECT Normalise compact reference and fresh engine output schemas.
% A path means the explicit reference directory; a struct supplies raw paths.
% No fallback to bundled reference results exists for fresh simulations.
prpaper_setup();
if ischar(input)||isstring(input)
 file=fullfile(char(input),'reference_data.mat');assert(isfile(file),'Missing reference_data.mat');
 a=load(file,'DATA');assert(isfield(a,'DATA'),'Reference file must contain DATA');DATA=a.DATA;
 if isfield(DATA,'provenance')&&isfield(DATA.provenance,'reference_parts')
  parts=DATA.provenance.reference_parts;if ~iscell(parts),parts=cellstr(parts);end
  assert(isequal(sort(parts(:)),sort({'reference_base_summaries.mat';'reference_base_figure_data.mat'})),...
   'Unexpected reference component manifest.');
  for k=1:numel(parts)
   part=fullfile(char(input),parts{k});assert(isfile(part),'Missing required reference component: %s',part);
   switch parts{k}
    case 'reference_base_summaries.mat',q=load(part,'summaries');assert(isfield(q,'summaries'));DATA.base.summaries=q.summaries;
    case 'reference_base_figure_data.mat',q=load(part,'figure_data');assert(isfield(q,'figure_data'));DATA.base.figure_data=q.figure_data;
   end
  end
 end
 q=load(fullfile(char(input),'reference_reduced_draws.mat'),'reduced');DATA.reduced=q.reduced;
 DATA=add_resampling(DATA);validate_data(DATA);return;
end
paths=input;required={'base','postprocess','rotation','bias','reparameterization','native'};
assert(all(isfield(paths,required)),'Supply all raw stage paths.');
for k=1:numel(required),assert(isfile(paths.(required{k})),'Missing complete stage %s',required{k});end
DATA=struct('schema_version','prpaper-data-1.0','base',jog2.Store.metadata(paths.base),'revision',struct());
assert(DATA.base.meta.complete&&DATA.base.meta.analysis_complete,'Original simulation/analysis is incomplete.');
assert(~isempty(fieldnames(DATA.base.figure_data)),...
 'Run base_figures before collection; numeric legacy figure data are required.');
for name={'postprocess','rotation','bias','reparameterization'}
 stage=name{1};a=load(paths.(stage),'output');o=a.output;
 assert(o.complete&&strcmp(o.source_run,DATA.base.meta.run_id),'Incomplete or mismatched %s output',stage);
 DATA.revision.(stage)=o.results;
 DATA.revision_metadata.(stage)=struct('schema_version',o.schema_version,'stage',o.stage,...
  'source_run',o.source_run,'token',o.token,'options',o.options);
end
a=load(paths.native,'output');DATA.native=a.output;
assert(DATA.native.complete&&strcmp(DATA.native.provenance.source_run,DATA.base.meta.run_id),...
 'Native results incomplete or from another source run.');
DATA.legacy=struct();
if isfield(DATA.base.legacy,'J01'),DATA.legacy.J01=jog2.Store.read(paths.base,DATA.base.legacy.J01);end
DATA.reduced=struct;
for suite={'J07','J08'}
 r=jog2.Store.read(paths.base,DATA.base.legacy.(suite{1}));DATA.reduced.(suite{1})=r.conditions;
end
DATA=add_resampling(DATA);
DATA.focal=collect_focal(paths,DATA);
DATA.boundaries=struct(); % prpaper_analyze recomputes all display boundaries.
DATA.provenance=struct('kind','fresh_stage_outputs','source_run',DATA.base.meta.run_id,...
 'raw_data_embedded',false,'payload_verification','Each consumed focal payload verified by archived SHA-256.');
validate_data(DATA);
end

function F=collect_focal(paths,DATA)
% Same accepted direct-focal fits as the original paired chart experiment.
% errors are truth-minus-estimate; rotations retain the saved convention.
a=load(paths.reparameterization,'output');rp=a.output;
source_condition=rp.results.source_condition;
ix=find(cellfun(@(c)strcmp(c.prefix,source_condition),DATA.base.conditions));
assert(numel(ix)==1,'Focal source condition missing from original metadata.');
d=jog2.Store.design(paths.base,DATA.base.conditions{ix});truth=d.geometry.truth_camera;
entries=rp.data_index;take=cellfun(@(e)startsWith(e.prefix,'direct_focal_trial'),entries);entries=entries(take);
[~,order]=sort(cellfun(@(e)e.prefix,entries,'UniformOutput',false));entries=entries(order);
N=numel(entries);assert(N>=1,'Reparameterization results have no retained trial payloads.');
E=nan(N,10);FocalError=nan(N,1);C=nan(N,10,10);Cd=C;fh=nan(N,1);wl=nan(N,1);wd=nan(N,1);ids=nan(N,1);valid=false(N,1);
f0=truth.scale*exp(truth.phi);
for k=1:N
 % Extract directly rather than reloading complete stage metadata each time.
 [tmp,cleanup]=jog2.Archive.extract(paths.reparameterization,entries{k});s=load(tmp,'record');v=s.record.value;clear cleanup
 ids(k)=v.trial_id;
 if ~(v.fit.success&&v.original_valid),continue;end
 e=-v.error_common_truth(:);cc=v.fit.covariance;f=v.fit.camera.scale*exp(v.fit.camera.phi);
 assert(abs(e(7)-log(f0/f))<1e-10,'Focal log-error convention mismatch.');
 ef=e;ef(7)=f0-f;scale=ones(10,1);scale(7)=f;cf=(scale*scale').*cc;
 E(k,:)=e';FocalError(k)=ef(7);C(k,:,:)=reshape(cc,1,10,10);Cd(k,:,:)=reshape(cf,1,10,10);fh(k)=f;
 wl(k)=wald(e,cc);wd(k)=wald(ef,cf);valid(k)=true;
 equivalent=e;equivalent(7)=expm1(e(7));weq=wald(equivalent,cc);
 assert(abs(wd(k)-weq)<=1e-7*max(1,wd(k)),'Direct focal congruence check failed.');
 assert(abs(wl(k)-v.full_nees)<=1e-7*max(1,wl(k)),'Saved log-focal NEES check failed.');
end
assert(numel(unique(ids))==N,'Duplicate focal trial identifiers.');
% Invalid fits are recorded, not replaced. The illustrative scatter and paired
% inclusion comparison condition on valid paired covariance estimates.
allids=ids;rejected=ids(~valid);E=E(valid,:);C=C(valid,:,:);Cd=Cd(valid,:,:);fh=fh(valid);wl=wl(valid);wd=wd(valid);ids=ids(valid);FocalError=FocalError(valid);
assert(~isempty(ids),'No valid paired focal fits; the chosen profile cannot generate this diagnostic.');
Ed=E;Ed(:,7)=FocalError;R=truth.R;optical=R'*[0;0;1];distance=E(:,1:3)*optical;
T=eye(10);T(1:3,1:3)=R;Cbar=zeros(10);
for k=1:numel(ids),Cbar=Cbar+T*squeeze(C(k,:,:))*T';end
Cbar=Cbar/numel(ids);J=[3 7];K=setdiff(1:10,J);M=Cbar(J,J);
S=M-Cbar(J,K)*(Cbar(K,K)\Cbar(K,J));S=(S+S')/2;
diags=DATA.revision.postprocess.diagnostics;Cref=[];
for k=1:numel(diags)
 z=at(diags,k);if ~strcmp(z.condition,source_condition),continue;end
 for j=1:numel(z.methods),m=at(z.methods,j);if strcmp(m.label,'GH_FULL'),Cref=m.reference_reported_covariance;end,end
end
assert(~isempty(Cref),'Missing fixed truth-reference covariance for focal condition.');
q10=2*gammaincinv(.95,5);q2=2*gammaincinv(.95,1);
F=struct('error_log_truth_minus_fit',E,'covariance_log',C,...
 'error_direct_truth_minus_fit',Ed,'covariance_direct',Cd,'f_hat',fh,'f_true',f0,...
 'R_true',R,'optical_axis_world',optical,'optical_position_error',distance,...
 'inside_log',wl<=q10,'inside_direct',wd<=q10,'W_log',wl,'W_direct',wd,...
 'chi2_10_95',q10,'chi2_2_95',q2,'Cbar_rotated',Cbar,...
 'marginal_plane_covariance',M,'conditional_plane_covariance',S,'C_reference',Cref,...
 'trial_ids',ids,'attempted_trial_ids',allids,'invalid_paired_trial_ids',rejected,...
 'source_condition',source_condition,'error_convention','truth minus estimate; saved rotation convention unchanged');
end
function q=wald(e,C)
s=sqrt(diag(C));assert(all(isfinite(s)&s>0),'Invalid covariance diagonal.');
A=C./(s*s');[L,p]=chol((A+A')/2,'lower');assert(p==0,'Covariance not positive definite.');
z=L\(e./s);q=sum(z.^2);
end
function v=at(x,k),if iscell(x),v=x{k};else,v=x(k);end,end
function validate_data(D)
assert(all(isfield(D,{'base','revision','native','focal'})),'Unified DATA schema missing required fields.');
assert(isfield(D.base,'figure_data'),'Missing original figure data.');
assert(all(isfield(D.revision,{'postprocess','rotation','bias','reparameterization'})),'Missing PR revision stage data.');
assert(size(D.focal.error_log_truth_minus_fit,2)==10,'Expected N-by-10 focal errors.');
assert(size(D.focal.covariance_log,2)==10&&size(D.focal.covariance_log,3)==10,'Expected N-by-10-by-10 focal covariance.');
end

function DATA=add_resampling(DATA)
root=prpaper_setup();
a=load(fullfile(root,'data','resampling','reduced_bootstrap_counts.mat'),'counts');
DATA.reduced_bootstrap=a.counts;
end
