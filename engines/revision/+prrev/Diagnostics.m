classdef Diagnostics
methods(Static)
function ix=select(o,opt,kind)
 if strcmp(kind,'target'),names=opt.target_condition_ids;else,names=opt.diagnostic_condition_ids;end
 ix=[];
 for i=1:numel(o.conditions)
  c=o.conditions{i};s=c.spec;key=sprintf('%sc%03d',c.suite,s.condition_id);
  if ~isempty(names),take=ismember(key,names)||ismember(c.prefix,names);
  else
   ref=strcmp(c.suite,'J09')&&strcmp(s.kind,'patch')&&s.n==30&&abs(s.noise_scale-1)<1e-9&&any(abs(s.depth_spread-[.15 .02])<1e-9);
   glob=strcmp(c.suite,'J09')&&strcmp(s.kind,'global')&&s.n==60;
   take=ref||glob;
   if ~strcmp(kind,'target'),take=take||(strcmp(c.suite,'J10')&&any(abs(s.noise_scale-[.1 .3 1])<1e-9))||(strcmp(c.suite,'J11')&&strcmp(s.sweep,'M4'));end
  end
  if take,ix(end+1)=i;end
 end
 assert(~isempty(ix),'No matching source conditions. Set explicit condition IDs in pr_config.');
 if ~isempty(names),assert(numel(ix)==numel(names),'Some requested condition IDs are missing or ambiguous');end
end
function p=gaussian(Ct,C0,opt,job)
 L=chol((C0+C0')/2,'lower');W=L\Ct/L';lambda=eig((W+W')/2);tol=1e-10*max(abs(lambda));assert(min(lambda)>=-tol,'Non-PSD covariance');lambda=max(0,lambda);
 rs=RandStream('mrg32k3a','Seed',opt.seed,'NormalTransform','Inversion');rs.Substream=job;
 N=opt.draws;hit=0;th=jog.Core.chi2(.95,numel(lambda));
 for k=1:opt.chunk:N,n=min(opt.chunk,N-k+1);Z=randn(rs,numel(lambda),n);v=lambda'*(Z.^2);hit=hit+sum(v<=th);end
 p=struct('eigenvalues',lambda,'coverage',hit/N,'wilson',jog.Core.wilson(hit,N),'draws',N,'seed',opt.seed,'substream',job,...
  'definition','Weighted CENTRAL chi-square sum at fixed truth design. Gaussian reference integration by seeded draws; NOT nonlinear camera refitting.');
end
function r=condition(o,c,d,opt,index)
 s=prrev.IO.summary(o,c);r=struct('condition',c.prefix,'spec',c.spec,'methods',{{}},'rows',struct([]));
 for m=1:numel(d.methods)
  a=s.method{m};C0=d.oracle_reference{m}.nominal_covariance;Ct=d.oracle_reference{m}.actual_sampling_covariance;
  q=prrev.Diagnostics.gaussian(Ct,C0,opt.gaussian,100*index+m);
  P=C0(1:3,1:3);B=C0(1:3,4:10);R=C0(4:10,4:10);S=P-B*(R\B');S=(S+S')/2;
  z=find(abs(a.blocks.full.nominal-.95)<1e-10,1);
  rr=struct('label',a.label,'gaussian',q,'reference_reported_covariance',C0,'reference_actual_covariance',Ct,...
   'position_marginal_covariance',P,'position_conditional_covariance',S,...
   'position_precision_trace_ratio',trace(S\eye(3))/trace(P\eye(3)),...
   'saved_generalized',a.generalized,'saved_bias_decomposition',a.bias_decomposition,...
   'full_coverage',a.blocks.full.coverage_conditional(z),'position_coverage',a.blocks.position.coverage_conditional(z),...
   'fixed_nominal_coverage',a.actual_fixed_nominal.coverage_conditional(z),...
   'note','Saved contrasts use the declared metric. Coefficient shares are NOT invariant physical variance contributions; eigenvalue ties make directions unstable.');
  r.methods{m}=rr;
  r.rows=prrev.IO.append(r.rows,struct('condition',c.prefix,'method',a.label,'native_full_coverage',rr.full_coverage,'position_coverage',rr.position_coverage,...
   'fixed_nominal_coverage',rr.fixed_nominal_coverage,'gaussian_reference_coverage',q.coverage,'gaussian_low',q.wilson(1),'gaussian_high',q.wilson(2),...
   'position_precision_trace_ratio',rr.position_precision_trace_ratio));
 end
end
end
end
