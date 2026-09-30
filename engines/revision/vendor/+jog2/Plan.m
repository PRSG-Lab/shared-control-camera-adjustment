classdef Plan
methods(Static)
function cases=make(id,cfg)
 cases={};base=jog2.Noise.spec(cfg,'patch');reg=cfg.j10.regimes;bn=cfg.nonlinear.baseline_points;bd=cfg.nonlinear.baseline_spread;
 switch id
 case 'J09'
  for a=cfg.nonlinear.noise_scales,add(bn,bd,a,'noise_scale',a,0,0,base);end
  for d=cfg.nonlinear.depth_spreads,if d~=bd,add(bn,d,1,'depth_spread',d,0,0,base);end,end
  for n=cfg.nonlinear.point_counts,if n~=bn,add(n,bd,1,'point_count',n,0,0,base);end,end
  b=base;b.kind='global';for n=cfg.nonlinear.point_counts,add(n,bd,1,'global_translation',n,0,0,b);end
 case 'J10'
  for g=1:size(reg,1)
   for a=cfg.j10.scales,add(reg(g,1),reg(g,2),a,'weak_noise',a,g,0,base);end
  end
 case 'J11'
  add(30,.15,1,'M1',1,1,0,base);v={};
  for a=cfg.j11.alpha,b=base;b.alpha=a;v{end+1}=variant('GH_FULL',sprintf('FULL_alpha_%g',a),b);end
  v=[v {variant('GH_LOCAL','GH_LOCAL',base),variant('GH_MARGDIAG','GH_MARGDIAG',base),variant('FIXED3D_WLS','FIXED3D_WLS',base)}];
  cases{end}.variants=v;
  b=base;b.kind='patch_global';add(30,.15,1,'M4',1,1,1,b);
  p=b;p.kind='patch';q=b;q.kind='global';
  cases{end}.variants={variant('GH_FULL','FULL_correct',b),variant('GH_FULL','omit_global',p),...
   variant('GH_FULL','omit_patch',q),variant('GH_LOCAL','GH_LOCAL',b)};
  if ismember('M2',cfg.j11.extensions)
   add(30,.15,1,'M2',1,1,0,base);v={variant('GH_FULL','correct_4',base)};
   for ng=cfg.j11.groups,b=base;b.groups=ng;v{end+1}=variant('GH_FULL',sprintf('groups_%d',ng),b);end
   cases{end}.variants=v;
  end
  if ismember('M3',cfg.j11.extensions)
   add(30,.15,1,'M3',1,1,0,base);v={variant('GH_FULL','correct_patch',base)};
   for f=cfg.j11.length_factors,b=base;b.kind='spatial';b.length_factor=f;v{end+1}=variant('GH_FULL',sprintf('spatial_%g',f),b);end
   cases{end}.variants=v;
  end
  if ismember('M5',cfg.j11.extensions)
   b=base;b.kind='spatial';add(30,.15,1,'M5',1,1,2,b);
   cases{end}.variants={variant('GH_FULL','correct_spatial',b),variant('GH_FULL','assume_patch',base),...
    variant('GH_LOCAL','GH_LOCAL',b),variant('GH_MARGDIAG','GH_MARGDIAG',b)};
  end
 case 'J12'
  for g=1:cfg.j12.geometries
   for a=1:size(cfg.j12.regimes,1)
    rr=cfg.j12.regimes(a,:);add(rr(1),rr(2),1,'geometry_population',a,g,0,base);
    cases{end}.N=cfg.j12.maps;
   end
  end
 case 'J13'
  for d=cfg.j13.rotation_deg
   for n=cfg.j13.points
    b=base;b.kind='similarity';b.rotation_std=d*pi/180;
    b.translation_std=cfg.j13.translation_std;b.scale_std=cfg.j13.scale_std;
    add(n,.15,1,'similarity_rotation',d,1,0,b);
   end
  end
 case 'J14'
  for k=1:size(cfg.j14.scenarios,1)
   v=cfg.j14.scenarios(k,:);b=base;b.kind='patch_global';
   b.xyz_std=v(1);b.patch_std=v(2);b.global_std=v(3);
   add(30,.15,1,'shared_strength',k,1,0,b);
  end
 otherwise,error('jog2:suite','Unsupported camera suite %s',id);
 end
 for i=1:numel(cases),cases{i}.condition_id=i;end
 function add(n,spread,scale,sweep,x,gid,coupling,b)
  b.scale=scale;v=cell(size(cfg.nonlinear.methods));
  for m=1:numel(v),v{m}=variant(cfg.nonlinear.methods{m},cfg.nonlinear.methods{m},b);end
  cases{end+1}=struct('suite',id,'condition_id',0,'n',n,'depth_spread',spread,...
   'noise_scale',scale,'kind',b.kind,'sweep',sweep,'x',x,'geometry_id',gid,...
   'rng_coupling_id',coupling,'N',cfg.mc_nonlinear,'truth_noise',b,'variants',{v});
 end
end
function d=prepare(sp,cfg)
 j=str2double(sp.suite(2:end));
 if j==9
  g=jog2.Geometry.legacy(cfg,sp.n,sp.depth_spread);
 elseif j==10
  [g,found]=jog2.Geometry.sourceGeometry(cfg.j10.geometry_source_run,sp.n,sp.depth_spread);
  if ~found,g=jog2.Geometry.paired(cfg,sp.n,sp.depth_spread,j,sp.geometry_id);end
 else,g=jog2.Geometry.paired(cfg,sp.n,sp.depth_spread,j,sp.geometry_id);end
 if strcmp(sp.truth_noise.kind,'similarity')
  sp.truth_noise.pivot=mean(g.master_xyz,2);
  for m=1:numel(sp.variants),sp.variants{m}.noise.pivot=sp.truth_noise.pivot;end
 end
 no=jog2.Noise.build(g,sp.truth_noise);vs=sp.variants;
 assumed=cell(size(vs));factors=assumed;refs=assumed;fm=assumed;
 for m=1:numel(vs)
  assumed{m}=jog2.Noise.build(g,vs{m}.noise);
  [factors{m},fm{m}]=jog2.Noise.factor(assumed{m},vs{m}.method);
  refs{m}=jog2.Noise.reference(g,no,factors{m},cfg);
 end
 d=struct('spec',sp,'geometry',g,'noise_model',no,'variants',{vs},...
  'assumed_models',{assumed},'covariance_factors',{factors},'factor_metadata',{fm},...
  'oracle_reference',{refs},'methods',{cellfun(@(v)v.label,vs,'UniformOutput',false)});
 d.decomposition=jog2.Noise.decompose(g,no,cfg);
 d.nested_diagnostics={};
 for cols={1:6,1:7,1:8,1:10}
  dd=jog2.Noise.decompose(g,no,cfg,cols{1});L=[eye(3),zeros(3,numel(cols{1})-3)];
  [dd.position_inflation,dd.position_spectrum]=jog.Core.inflation(dd,L);
  d.nested_diagnostics{end+1}=dd;
 end
 if strcmp(no.kind,'similarity')
  o=sp.truth_noise.pivot;r=g.truth_camera.gamma-o;
  T=zeros(10,7);T(1:3,:)=[-jog.Camera.skew(r),eye(3),r];T(4:6,1:3)=-g.truth_camera.R;
  shift=cfg.j13.pivot_shift;M=eye(7);M(4:6,1:3)=-jog.Camera.skew(shift);M(4:6,7)=shift;
  s=sp.truth_noise;s.pivot=o+shift;s.Qb_override=M*no.Q_b*M';
  transformed=jog2.Noise.build(g,s);
  d.similarity=struct('Gamma',T,'shared_covariance',T*no.Q_b*T',...
   'absorption_error',jog.Core.relative(refs{1}.A*T,refs{1}.B*no.G_raw),...
   'pivot_transform',M,'pivot_loading_error',jog.Core.relative(transformed.G_raw*M,no.G_raw),...
   'pivot_covariance_error',jog.Core.relative(transformed.Q_full,no.Q_full));
 end
end
end
end
function v=variant(method,label,noise)
v=struct('method',method,'label',label,'noise',noise);
end
