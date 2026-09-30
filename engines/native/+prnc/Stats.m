classdef Stats
methods(Static)
function [w,ok]=quadratic(e,C)
 w=NaN;ok=false;
 if any(~isfinite(e))||any(~isfinite(C(:)))||any(diag(C)<=0),return;end
 C=(C+C')/2;sd=sqrt(diag(C));R=C./(sd*sd');
 [L,p]=chol((R+R')/2,'lower');if p~=0,return;end
 z=L\(e./sd);w=sum(z.^2);ok=isfinite(w);
end
function r=batch(b,method_index,truth,opt)
 ids=b.trial_id(:)';N=numel(ids);m=method_index;
 r=struct('trial_ids',ids,'error_log',reshape(b.errors(:,:,m),10,N),...
  'covariance_log',reshape(b.covariance_native(:,:,:,m),10,10,N),...
  'camera_vector',reshape(b.cameras(:,m,:),16,N),...
  'fit_valid',logical(reshape(b.valid(m,:),1,N)),...
  'f_true',truth.scale*exp(truth.phi),'f_hat',nan(1,N),...
  'W_log',nan(1,N),'W_direct',nan(1,N),'covariance_valid',false(1,N),...
  'congruence_discrepancy',nan(1,N));
 for k=1:N
  if ~r.fit_valid(k),continue;end
  e=r.error_log(:,k);C=r.covariance_log(:,:,k);v=r.camera_vector(:,k);
  assert(all(isfinite(v))&&all(isfinite(e)),'Valid source fit has nonfinite parameters');
  fh=truth.scale*exp(v(13));r.f_hat(k)=fh;
  assert(isfinite(fh)&&fh>0,'Valid source fit has invalid focal length');
  assert(abs(e(7)-log(fh/r.f_true))<1e-10,'Focal error and stored camera disagree');
  assert(norm(e(1:3)-(v(1:3)-truth.gamma))<1e-9,'Camera position and error disagree');
  % The negative of e is truth displacement in the estimate-centred left
  % rotation chart. Changing the sign of the WHOLE vector leaves W unchanged.
  [wl,ol]=prnc.Stats.quadratic(e,C);
  if ~ol,continue;end
  scale=ones(10,1);scale(7)=fh;Cf=(scale*scale').*C;
  ef=e;ef(7)=fh-r.f_true;
  [wf,of]=prnc.Stats.quadratic(ef,Cf);
  assert(of,'Positive focal transform unexpectedly invalidated covariance');
  et=e;et(7)=-expm1(-e(7));[wi,oi]=prnc.Stats.quadratic(et,C);
  delta=abs(wi-wf)/max(1,abs(wf));
  assert(oi&&delta<opt.statistic_tolerance,'Native direct-f congruence identity failed');
  r.W_log(k)=wl;r.W_direct(k)=wf;r.covariance_valid(k)=true;r.congruence_discrepancy(k)=delta;
 end
 t=2*gammaincinv(opt.nominal,5);
 r.covered_log=r.covariance_valid&r.W_log<=t;
 r.covered_direct=r.covariance_valid&r.W_direct<=t;
end
function r=combine(parts)
 r=parts{1};fields={'trial_ids','error_log','camera_vector','fit_valid','f_hat','W_log','W_direct',...
  'covariance_valid','congruence_discrepancy','covered_log','covered_direct'};
 for j=2:numel(parts)
  q=parts{j};assert(abs(q.f_true-r.f_true)<1e-10);
  for k=1:numel(fields),f=fields{k};r.(f)=cat(2,r.(f),q.(f));end
  r.covariance_log=cat(3,r.covariance_log,q.covariance_log);
 end
 assert(isequal(r.trial_ids,sort(r.trial_ids))&&numel(unique(r.trial_ids))==numel(r.trial_ids),'Missing, unsorted or repeated trials');
end
function ci=wilson(k,n)
 if n==0,ci=[NaN NaN];return;end
 z=1.959963984540054;p=k/n;den=1+z*z/n;
 mid=(p+z*z/(2*n))/den;h=z*sqrt(p*(1-p)/n+z*z/(4*n*n))/den;
 ci=[mid-h mid+h];
end
function x=quantile(v,p)
 v=sort(v(isfinite(v)));if isempty(v),x=NaN;return;end
 q=1+(numel(v)-1)*p;lo=floor(q);hi=ceil(q);x=v(lo)+(q-lo)*(v(hi)-v(lo));
end
function s=summary(r)
 n=numel(r.trial_ids);nv=nnz(r.covariance_valid);kl=nnz(r.covered_log);kf=nnz(r.covered_direct);
 ci1=prnc.Stats.wilson(kl,nv);ci2=prnc.Stats.wilson(kf,nv);
 s=struct('N',n,'N_fit_valid',nnz(r.fit_valid),'N_covariance_valid',nv,...
  'log_hits',kl,'direct_hits',kf,'log_conditional',kl/max(nv,1),'direct_conditional',kf/max(nv,1),...
  'log_operational',kl/n,'direct_operational',kf/n,'log_wilson',ci1,'direct_wilson',ci2,...
  'delta_conditional_pp',100*(kf-kl)/max(nv,1),'delta_operational_pp',100*(kf-kl)/n,...
  'both',nnz(r.covered_log&r.covered_direct),...
  'log_only',nnz(r.covered_log&~r.covered_direct),...
  'direct_only',nnz(~r.covered_log&r.covered_direct),...
  'neither_valid',nnz(r.covariance_valid&~r.covered_log&~r.covered_direct),...
  'invalid_as_uncovered',n-nv,'max_congruence_discrepancy',max(r.congruence_discrepancy,[],'omitnan'));
 if nv==0,s.log_conditional=NaN;s.direct_conditional=NaN;s.delta_conditional_pp=NaN;end
end
function v=validate_source(r,s,opt)
 [yes,ix]=ismember(r.trial_ids,s.trial_ids);assert(all(yes),'Trial absent from source summary');
 saved=s.blocks.full.nees(ix);mask=isfinite(saved);
 assert(isequal(mask(:),r.covariance_valid(:)),'Native log covariance validity does not reproduce source');
 rel=abs(r.W_log(mask)-reshape(saved(mask),1,[]))./max(1,abs(reshape(saved(mask),1,[])));
 if isempty(rel),err=0;else,err=max(rel);end
 assert(err<opt.statistic_tolerance,'Saved native log NEES not reproduced');
 z=find(abs(s.blocks.full.nominal-opt.nominal)<1e-12);assert(isscalar(z));
 hits=saved<=2*gammaincinv(opt.nominal,5);
 assert(isequal(hits(:),r.covered_log(:)),'Saved log inclusion decisions changed');
 v=struct('max_relative_nees_discrepancy',err,'source_conditional',s.blocks.full.coverage_conditional(z),...
  'source_operational',s.blocks.full.coverage_operational(z),'tested_trial_count',numel(ix),...
  'complete_condition',numel(ix)==numel(s.trial_ids));
 if v.complete_condition
  a=prnc.Stats.summary(r);
  assert(abs(a.log_operational-v.source_operational)<1e-12);
  assert(abs(a.log_conditional-v.source_conditional)<1e-12);
 end
end
end
end
