function report=jog_selftest_v2(cfg)
if nargin==0,cfg=jog_config_v2('smoke');end
report.legacy=jog_selftest(cfg);
g=jog2.Geometry.paired(cfg,30,.15,13,1);
s=jog2.Noise.spec(cfg,'similarity');s.pivot=mean(g.master_xyz,2);
s.rotation_std=.005*pi/180;s.translation_std=.02;s.scale_std=20e-6;
no=jog2.Noise.build(g,s);[~,A,B]=jog.Camera.evaluate(g.y_true,g.truth_camera);
rr=g.truth_camera.gamma-s.pivot;T=zeros(10,7);T(1:3,:)=[-jog.Camera.skew(rr),eye(3),rr];T(4:6,1:3)=-g.truth_camera.R;
report.similarity_loading=jog.Core.relative(A*T,B*no.G_raw);
shift=[20;0;0];M=eye(7);M(4:6,1:3)=-jog.Camera.skew(shift);M(4:6,7)=shift;
s.pivot=s.pivot+shift;s.Qb_override=M*no.Q_b*M';no2=jog2.Noise.build(g,s);
report.pivot=jog.Core.relative(no.Q_full,no2.Q_full);
F=jog.Camera.factor(no,'GH_FULL');ref=jog2.Noise.reference(g,no,F,cfg);
report.nominal_sandwich=jog.Core.relative(ref.nominal_covariance,ref.actual_sampling_covariance);
s=jog2.Noise.spec(cfg,'patch');tr=jog2.Noise.build(g,s);s.alpha=4;as=jog2.Noise.build(g,s);
ref=jog2.Noise.reference(g,tr,jog.Camera.factor(as,'GH_FULL'),cfg);
e=eig((ref.nominal_covariance-ref.actual_sampling_covariance+ref.nominal_covariance'-ref.actual_sampling_covariance')/2);
report.inflation_min_eigenvalue=min(e);
s=jog2.Noise.spec(cfg,'patch_global');s.patch_std=0;s.global_std=0;no=jog2.Noise.build(g,s);
report.zero_psd_factor=size(no.L_b,2);assert(isempty(no.L_b));
[r,a]=jog2.Util.stream(cfg,12,1,0,1,1);v=randn(r,20,1);
[r,b]=jog2.Util.stream(cfg,12,1,0,1,1);assert(isequal(v,randn(r,20,1))&&a==b);
assert(report.similarity_loading<1e-9&&report.pivot<1e-10&&report.nominal_sandwich<1e-8);
assert(report.inflation_min_eigenvalue>-1e-7);
t=jog2.Target.design(g,cfg);report.target_step_halving=struct();
for kind={'plane','image'}
 [~,J1]=jog2.Target.values(g.truth_camera,t,kind{1},1);[~,J2]=jog2.Target.values(g.truth_camera,t,kind{1},.5);
 discrepancy=jog.Core.relative(J1(:),J2(:));report.target_step_halving.(kind{1})=discrepancy;
 assert(discrepancy<1e-5,'Target numerical derivative failed step-halving');
end
report.passed=true;
end
