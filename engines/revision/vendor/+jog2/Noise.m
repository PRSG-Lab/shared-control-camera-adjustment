classdef Noise
methods(Static)
function s=spec(cfg,kind)
 x=cfg.camera;s=struct('kind',kind,'image_std',x.local_image_std,...
 'xyz_std',x.local_xyz_std,'anisotropy',x.anisotropy,'patch_std',x.patch_std,...
 'global_std',x.global_std,'scale',1,'alpha',1,'groups',4,'length_factor',1,...
 'image_extent',[x.width;x.height]*x.occupancy/2,'rotation_std',0,'translation_std',0,'scale_std',0,'pivot',[],'Qb_override',[]);
end
function no=build(g,s)
 n=size(g.y_true,2);a=s.anisotropy;
 qx=s.xyz_std^2*diag([3 3 3*a*a]/(2+a*a));
 Ql=kron(eye(n),blkdiag(s.image_std^2*eye(2),qx))*s.scale^2;
 xyz=reshape(1:5*n,5,n);ix=xyz(3:5,:);ix=ix(:);
 G=zeros(5*n,0);qb=zeros(0);labels={};comp={};
 switch s.kind
 case 'none'
 case {'patch','global','patch_global'}
  if any(strcmp(s.kind,{'patch','patch_global'}))
   ids=jog2.Noise.partition(g,s.groups,s.image_extent);ng=max(ids);Gp=zeros(3*n,3*ng);
   for i=1:n,Gp(3*i-2:3*i,3*ids(i)-2:3*ids(i))=eye(3);end
   G0=zeros(5*n,3*ng);G0(ix,:)=Gp;G=[G G0];qb=blkdiag(qb,s.patch_std^2*eye(3*ng));
   labels=[labels arrayfun(@(i)sprintf('patch_%d',i),1:3*ng,'UniformOutput',false)];
   comp{end+1}=struct('name','patch','columns',1:3*ng);
  end
  if any(strcmp(s.kind,{'global','patch_global'}))
   start=size(G,2);G0=zeros(5*n,3);G0(ix,:)=repmat(eye(3),n,1);
   G=[G G0];qb=blkdiag(qb,s.global_std^2*eye(3));labels=[labels {'tx','ty','tz'}];
   comp{end+1}=struct('name','global','columns',start+(1:3));
  end
 case 'similarity'
  G=zeros(5*n,7);
  for i=1:n,v=g.y_true(3:5,i)-s.pivot;G(5*i-2:5*i,:)=[-jog.Camera.skew(v),eye(3),v];end
  qb=blkdiag(s.rotation_std^2*eye(3),s.translation_std^2*eye(3),s.scale_std^2);
  if ~isempty(s.Qb_override),qb=s.Qb_override;end
  labels={'omega_x','omega_y','omega_z','tx','ty','tz','scale'};
  comp={struct('name','similarity','columns',1:7)};
 case 'spatial'
  X=g.y_true(3:5,:);dist=sqrt(max(0,sum(X.^2,1)'+sum(X.^2,1)-2*X'*X));
  dm=jog.Core.quantile(dist(triu(true(n),1)&dist>0),.5);assert(dm>0);
  ell=s.length_factor*dm;K=exp(-dist/ell);
  G=zeros(5*n,3*n);G(ix,:)=eye(3*n);qb=s.patch_std^2*kron(K,eye(3));
  labels=arrayfun(@(i)sprintf('spatial_%d',i),1:3*n,'UniformOutput',false);
  comp={struct('name','spatial','columns',1:3*n)};
 otherwise,error('jog2:noiseKind','Unknown noise kind: %s',s.kind);
 end
 qb=qb*s.scale^2*s.alpha;L=jog2.Util.psdfactor(qb);
 Fl=jog2.Util.psdfactor(Ql);Fc=G*L;Q=Ql+Fc*Fc';
 no=struct('Q_local',Ql,'G_raw',G,'Q_b',qb,'F_local',Fl,'F_common',Fc,...
 'L_b',L,'Q_full',Q,'kind',s.kind,'spec',s,'common_labels',{labels},'components',{comp},...
 'factor_local_columns',1:size(Fl,2),'factor_common_columns',size(Fl,2)+(1:size(Fc,2)),...
 'latent_to_b',L,'observation_order','point-major [u,v,X,Y,Z]');
end
function ids=partition(g,groups,bound)
 uv=g.y_true(1:2,:);
 if groups==4,ids=g.patch_id;
 elseif groups==2,ids=1+(uv(1,:)>=0);
 elseif any(groups==[9 16])
  a=round(sqrt(groups));
  bins=min(a,max(1,floor((uv+bound)./(2*bound)*a)+1));
  ids=bins(1,:)+a*(bins(2,:)-1);
 else,error('jog2:groups','Use 2,4,9,16 groups');end
 [~,~,ids]=unique(ids);ids=ids(:)';
end
function [F,meta]=factor(no,method)
 F=jog.Camera.factor(no,method);
 meta=struct('method',method,'local_columns',[],'common_columns',[],'latent_to_b',[]);
 if strcmp(method,'GH_FULL')
  meta.local_columns=no.factor_local_columns;meta.common_columns=no.factor_common_columns;
  meta.latent_to_b=no.L_b;
 end
end
function r=reference(g,no,F,cfg)
 [~,A,B]=jog.Camera.evaluate(g.y_true,g.truth_camera);S=B*(F*F')*B';L=chol((S+S')/2,'lower');
 [C,~,rank,cond]=jog.Core.normal(L\A,cfg.solver.rank_tolerance);
 W=C*(L\A)'/L*B;actual=W*no.Q_full*W';
 r=struct('A',A,'B',B,'S_assumed',S,'nominal_covariance',C,...
 'actual_sampling_covariance',(actual+actual')/2,'sensitivity',W,...
 'rank',rank,'condition_scaled',cond,'design_is_oracle',true);
end
function d=decompose(g,no,cfg,cols)
 if nargin<4,cols=1:10;end
 [~,A,B]=jog.Camera.evaluate(g.y_true,g.truth_camera);L=chol(B*no.Q_local*B','lower');
 % Use independent positive-support latent coordinates: covariance I.
 U=B*no.G_raw*no.L_b;d=jog.Core.linear(L\A(:,cols),L\U,eye(size(U,2)));
 d.Gamma=d.T;d.support_to_physical=no.L_b;d.parameter_columns=cols;
 d.whitening='local';d.design='truth';d.rank_tolerance=cfg.solver.rank_tolerance;
end
end
end
