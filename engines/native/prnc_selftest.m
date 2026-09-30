function report=prnc_selftest()
% Exact invariance for a linear Jacobian displacement, and non-invariance for
% the correct finite focal displacement; preserve cross-covariances.
assert(prnc.Reports.display_round(59.45-2*eps(59.45),1)==59.5);
assert(prnc.Reports.display_round(1.475-2*eps(1.475),2)==1.48);
root=fileparts(mfilename('fullpath'));addpath(root);opt=prnc_config('smoke');
rs=RandStream('mt19937ar','Seed',2392026);A=randn(rs,10);C=A*A'+eye(10);
e=randn(rs,10,1);e(7)=.7;fh=7000;f0=fh*exp(-e(7));D=eye(10);D(7,7)=fh;
[w0,ok]=prnc.Stats.quadratic(e,C);assert(ok);
[wlin,ok]=prnc.Stats.quadratic(D*e,D*C*D');assert(ok&&abs(wlin-w0)<1e-10);
ef=e;ef(7)=fh-f0;[wf,ok]=prnc.Stats.quadratic(ef,D*C*D');assert(ok);
et=e;et(7)=-expm1(-e(7));[we,ok]=prnc.Stats.quadratic(et,C);
assert(ok&&abs(wf-we)<1e-10&&abs(wf-w0)>1e-4);
[wd,~]=prnc.Stats.quadratic(ef,diag(diag(D*C*D')));assert(abs(wd-wf)>1e-3);
[w,ok]=prnc.Stats.quadratic(e,zeros(10));assert(~ok&&isnan(w));
truth=struct('gamma',zeros(3,1),'phi',0,'scale',3500);
b=struct('trial_id',1:3,'errors',zeros(10,3,1),'covariance_native',repmat(eye(10),1,1,3),...
 'cameras',repmat([zeros(3,1);reshape(eye(3),9,1);0;0;0;0],1,1,3),'valid',[true false true]);
b.covariance_native(:,:,3)=zeros(10);
r=prnc.Stats.batch(b,1,truth,opt);s=prnc.Stats.summary(r);
assert(s.N==3&&s.N_fit_valid==2&&s.N_covariance_valid==1&&s.log_conditional==1&&s.log_operational==1/3);
assert(s.direct_conditional==1&&s.direct_operational==1/3&&s.invalid_as_uncovered==2);
fixture=fullfile(root,'validation','native_chart_reference.mat');
a=load(fixture);N=size(a.error_log,2);W=nan(N,2);
for k=1:N
 E=a.error_log(:,k);Q=a.covariance_log(:,:,k);S=eye(10);S(7,7)=a.f_hat(k);
 F=E;F(7)=a.f_hat(k)-a.f_true;
 [W(k,1),o1]=prnc.Stats.quadratic(E,Q);[W(k,2),o2]=prnc.Stats.quadratic(F,S*Q*S');assert(o1&&o2);
end
hits=W<=a.threshold;assert(isequal(sum(hits),[988 1661]));
assert(nnz(hits(:,1)&hits(:,2))==984&&nnz(~hits(:,1)&hits(:,2))==677);
report=struct('linear_transform_identity',true,'finite_chart_difference',true,...
 'cross_covariance_effect',true,'failed_fit_denominators',true,...
 'reference_trials',N,'reference_log_hits',988,'reference_direct_hits',1661,'status','passed');
disp(report);
end
