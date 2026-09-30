function R=prpaper_reduced(DATA,opt)
%PRPAPER_REDUCED Paired diagnostics added in manuscript v0.17--v0.19.
% Applies limiting and finite first-order operators to the SAME saved draws.
% No observations, camera fits, selected cases, or sample values are replaced.
assert(isfield(DATA,'reduced'),'Missing J07/J08 sufficient-statistic records.');
rows={};checks={};bootrows={};
for suite={'J07','J08'}
 id=suite{1};cs=DATA.reduced.(id);
 for ci=1:numel(cs)
  if iscell(cs),c=cs{ci};else,c=cs(ci);end
  H=c.H_limit;b=c.regional_effect+c.global_effect;
  local=c.mean_local_depth_error+(c.truth(2)./c.lambda.^2).*c.lambda_error;
  lim=H*b;lin=H*(b+local);err=c.errors;delta=err-lin;N=size(err,2);
  Hcheck=(c.M'*(c.Sigma_common\c.M))\(c.M'/c.Sigma_common);
  hd=max(abs(Hcheck-H),[],'all');reconstruction=0;
  for k=find(c.guard_accepted)
   Mh=[ones(numel(c.lambda),1),1./c.lambda_hat(:,k)];
   est=(Mh'*(c.Sigma_common\Mh))\(Mh'*(c.Sigma_common\c.mean_depth_observed(:,k)));
   reconstruction=max(reconstruction,max(abs(est-c.truth-err(:,k))));
  end
  assert(hd<1e-7&&reconstruction<1e-7,'Reduced estimate/operator reconstruction failed.');
  checks{end+1}=struct('Suite',id,'Condition',ci,'N',N,...
   'H_max_difference',hd,'Estimate_max_difference',reconstruction,...
   'Guard_fallbacks',nnz(~c.guard_accepted)); %#ok<AGROW>
  components={'position','focal'};
  for k=1:2
   sdlimit=sqrt(c.floor_covariance(k,k));sdl=std(lim(k,:),0,2);
   stat=(N-1)*(sdl/sdlimit)^2;tail=gammainc(stat/2,(N-1)/2,'lower');
   cc=corrcoef(err(k,:),lin(k,:));
   rows{end+1}=struct('Suite',id,'Condition',ci,'Sweep',c.spec.sweep,...
    'Points_per_plane',c.spec.n,'Plane_STD',c.spec.region_std,'Global_STD',c.spec.global_std,...
    'Component',components{k},'N',N,'Empirical_SD',std(err(k,:),0,2),...
    'Analytical_limit_SD',sdlimit,'Paired_limit_SD',sdl,...
    'Analytical_first_order_SD',sqrt(c.first_order_finite_covariance(k,k)),...
    'Paired_first_order_SD',std(lin(k,:),0,2),...
    'Nonlinear_minus_linear_RMS',sqrt(mean(delta(k,:).^2)),...
    'Nonlinear_linear_correlation',cc(1,2),'Limit_SD_lower_tail_p',tail,...
    'Limit_SD_two_sided_p',2*min(tail,1-tail),'Guard_fallbacks',nnz(~c.guard_accepted)); %#ok<AGROW>
  end
  selected=strcmp(id,'J07')&&strcmp(c.spec.sweep,'points_per_plane')&&...
   c.spec.n==max(DATA.base.config.plane.n)&&c.spec.region_std==DATA.base.config.plane.region_std(1);
  selected=selected||(strcmp(id,'J08')&&ci==numel(cs));
  if selected
   [draws,description]=bootstrap_sd(err,id,DATA,opt);
   for k=1:2
    bootrows{end+1}=struct('Suite',id,'Condition',ci,'Component',components{k},'N',N,...
     'Replicates',size(draws,2),'Empirical_SD',std(err(k,:),0,2),...
     'CI95_low',linear_quantile(draws(k,:),.025),'CI95_high',linear_quantile(draws(k,:),.975),...
     'Monte_Carlo_SE',std(draws(k,:),0,2),'Resampling_plan',description); %#ok<AGROW>
   end
  end
 end
end
R.paired=struct2table([rows{:}]);R.reconstruction=struct2table([checks{:}]);
R.bootstrap=struct2table([bootrows{:}]);
p=R.paired(strcmp(R.paired.Component,'position'),:);
R.summary=struct('conditions',height(p),'below_limit',nnz(p.Paired_limit_SD<p.Analytical_limit_SD),...
 'above_limit',nnz(p.Paired_limit_SD>p.Analytical_limit_SD),...
 'guard_fallbacks',sum(R.reconstruction.Guard_fallbacks),...
 'max_reconstruction_difference',max(R.reconstruction.Estimate_max_difference),...
 'definition','Paired saved perturbations; N-1 sample SD; pointwise intervals; no new observations/fits.');
end

function [s,description]=bootstrap_sd(E,suite,DATA,opt)
N=size(E,2);
if N==3000&&isfield(DATA,'reduced_bootstrap')
 counts=DATA.reduced_bootstrap.(suite);B=size(counts,2);
 assert(size(counts,1)==N&&all(sum(double(counts),1)==N),'Invalid bootstrap weights.');
 s=zeros(2,B);
 % Centre once to prevent subtractive cancellation in weighted variances.
 X=E-mean(E,2);
 for a=1:100:B
  ix=a:min(B,a+99);W=double(counts(:,ix));m=X*W;
  s(:,ix)=sqrt(max(0,((X.^2)*W-m.^2/N)/(N-1)));
 end
 description='Fixed NumPy PCG64 seed 20260925 row-count plan, J07 then J08; no Python runtime needed';
else
 B=opt.bootstrap_replicates;rs=RandStream('mt19937ar','Seed',20260925+str2double(suite(2:end)));
 s=zeros(2,B);for k=1:B,ix=randi(rs,N,1,N);s(:,k)=std(E(:,ix),0,2);end
 description='Reduced-size execution: explicit MATLAB mt19937ar row bootstrap; not paper interval';
end
end
function q=linear_quantile(v,p)
v=sort(v(isfinite(v)));t=1+(numel(v)-1)*p;lo=floor(t);hi=ceil(t);
q=v(lo)+(t-lo)*(v(hi)-v(lo));
end
