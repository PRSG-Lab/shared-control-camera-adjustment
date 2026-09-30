function report=jog_selftest(cfg)
%JOG_SELFTEST Fast prerequisites: algebra, Jacobians, guard and initializer.
if nargin==0,cfg=jog_config('smoke');end
rng(cfg.master_seed,'twister');g=jog.Camera.geometry(cfg,30,.3,cfg.master_seed);
c=g.truth_camera;y=g.y_true;[psi,A,B,ok]=jog.Camera.evaluate(y,c);
assert(ok && norm(psi,inf)<1e-12,'Noiseless projection failed.');
An=zeros(size(A));Bn=zeros(size(B));
for j=1:10
 h=1e-5;if j==7||j==8||ismember(j,4:6),h=1e-6;end
 dx=zeros(10,1);dx(j)=h;
 pp=jog.Camera.evaluate(y,jog.Camera.step(c,dx));pm=jog.Camera.evaluate(y,jog.Camera.step(c,-dx));
 An(:,j)=-(pp-pm)/(2*h);
end
for j=1:numel(y)
 h=1e-5;if mod(j-1,5)<2,h=1e-4;end
 yp=y;ym=y;yp(j)=yp(j)+h;ym(j)=ym(j)-h;
 Bn(:,j)=(jog.Camera.evaluate(yp,c)-jog.Camera.evaluate(ym,c))/(2*h);
end
errA=max(abs(A(:)-An(:)));errB=max(abs(B(:)-Bn(:)));
assert(errA<1e-7 && errB<1e-7,'Camera Jacobian check failed.');
no=jog.Camera.noiseModel(cfg,g,1,'global');L=chol(B*no.Q_local*B','lower');
d=jog.Core.linear(L\A,L\(B*no.G_raw),no.Q_b);
assert(jog.Core.relative(d.Sigma,d.Sigma_direct)<1e-7);
assert(jog.Core.relative(d.W,d.W_direct)<1e-7);
% Local truth-initialized zero-noise run checks adjustment, not practical initialization.
fit=jog.solve_camera(y,jog.Camera.factor(no,'GH_FULL'),{c},cfg);
assert(fit.success && norm(jog.Camera.error(fit.camera,c))<1e-8,'Noiseless GHM failed.');
pool=jog.Camera.initialize(y,cfg);assert(~isempty(pool),'Observed DLT produced no initializer.');
practical=jog.solve_camera(y,jog.Camera.factor(no,'GH_FULL'),pool,cfg);
assert(practical.success,'Observed DLT + noiseless adjustment failed.');
assert(norm(jog.Camera.error(practical.camera,c))<1e-4,'Noiseless parameter recovery failed.');
% Force the plane guard to fail: finite fallback moments, no spurious coverage.
probe=cfg;probe.mc_plane=2;probe.plane.global_stds=0;probe.plane.guard_lambda=[.01 .1];
guardTest=jog.plane_suite('J08',probe);gs=guardTest.conditions{1};
assert(~any(gs.guard_accepted) && gs.summary_all_including_fallback.n_valid==2);
assert(gs.summary_all_including_fallback.n_covariance_valid==0);
assert(all(gs.summary_all_including_fallback.coverage_operational==0));
assert(gs.summary_known_f.n_covariance_valid==0,'Fallback issued a confidence region.');
report=struct('passed',true,'guard_failure_bookkeeping_passed',true,'max_A_difference',errA,'max_B_difference',errB,...
 'GLS_covariance_relative_difference',jog.Core.relative(d.Sigma,d.Sigma_direct),...
 'observed_initializer_count',numel(pool),'noiseless_parameter_error',norm(jog.Camera.error(practical.camera,c)),...
 'note','Deterministic prerequisites only; production Monte Carlo is separate.');
disp(report);
end
