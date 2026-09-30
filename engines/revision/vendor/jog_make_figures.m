function [manifest,figureData]=jog_make_figures(input,destination)
%JOG_MAKE_FIGURES Regenerate every PNG from saved output.mat, without rerunning.
% [manifest,data]=jog_make_figures('path/output.mat','path/new_figures');
if ischar(input)||isstring(input),s=load(input,'output');o=s.output;else,o=input;end
if nargin<2,destination=fullfile(pwd,'figures');end
if ~exist(destination,'dir'),mkdir(destination);end
cfg=o.config;E=o.experiments;manifest=struct('id',{},'file',{},'caption',{},'profile',{});figureData=struct();
colors=[0 .45 .7;.85 .33 .10;.0 .6 .5;.55 .25 .65];fig=[];
if isfield(E,'J01')
 g=E.J01.geometry;fig=newFigure();tiledlayout(1,2,'TileSpacing','compact');
 nexttile;scatter3(g.y_true(3,:),g.y_true(4,:),g.y_true(5,:),30,g.patch_id,'filled');hold on;
 scatter3(g.truth_camera.gamma(1),g.truth_camera.gamma(2),g.truth_camera.gamma(3),80,'k','^','filled');
 axis equal;grid on;xlabel('X (m)');ylabel('Y (m)');zlabel('Z (m)');title('Synthetic control and camera');
 nexttile;scatter(g.y_true(1,:),g.y_true(2,:),30,g.patch_id,'filled');axis equal;grid on;set(gca,'YDir','reverse');
 xlabel('Centered image u (px)');ylabel('Centered image v (px)');title('Image coverage and shared-error groups');
 finish('JF00_geometry','Fixed synthetic geometry. Colors identify regional common-effect groups.',struct('geometry',g));
end
if isfield(E,'J00')&&isfield(E,'J03')
 fig=newFigure();tiledlayout(1,2,'TileSpacing','compact');
 nexttile;semilogy(max(E.J00.errors,eps),'LineWidth',1);grid on;xlabel('Random matrix case');ylabel('Numerical discrepancy');
 legend(E.J00.error_names,'Location','best','Interpreter','none');title('J00: independent algebra checks');
 nexttile;semilogy(max(E.J03.errors,eps),'LineWidth',1);grid on;xlabel('Coordinate-change case');ylabel('Numerical discrepancy');
 legend({'Learning spectrum','Common-effect coordinates','Target coordinates'},'Location','best');title('J03: invariance checks');
 finish('JF01_algebra','Numerical identity checks; values at plotting precision are clipped to eps for log display.',...
  struct('J00_errors',E.J00.errors,'J03_errors',E.J03.errors,'case_condition',E.J00.condition));
end
if isfield(E,'J01')
 cs=E.J01.conditions;mu=zeros(numel(cs),numel(cs{1}.design.learning_spectrum));infl=zeros(1,numel(cs));ranks=infl;names=cell(size(cs));
 for k=1:numel(cs)
  mu(k,:)=cs{k}.design.learning_spectrum;infl(k)=cs{k}.position_variance_inflation;names{k}=cs{k}.name;
  ss=svd(cs{k}.design.V);ranks(k)=sum(ss>1e-9*max(1,ss(1)));
 end
 fig=newFigure();tiledlayout(1,2,'TileSpacing','compact');nexttile;
 imagesc(log10(1+mu));colorbar;xlabel('Common-mode eigenvalue (descending)');yticks(1:numel(cs));yticklabels(names);
 title('J01: log10(1 + residual learning eigenvalue)');
 nexttile;bar(ranks,'FaceColor',colors(1,:));xticks(1:4);xticklabels(names);xtickangle(20);ylabel('Residual loading rank');grid on;
 finish('JF02_IOP_information','IOP columns are added under identical local whitening and shared-error loading.',struct('eigenvalues',mu,'names',{names},'rank',ranks));
 fig=newFigure();tiledlayout(1,1);nexttile;semilogy(1:numel(infl),infl,'o-','Color',colors(2,:),'LineWidth',1.4);
 yline(1,'k:');ylim([.9,max(infl)*1.2]);grid on;xticks(1:4);xticklabels(names);xtickangle(15);
 ylabel('Maximum position variance inflation');title('J01: target-specific uncertainty relative to no common error');
 finish('JF04_target_inflation','Largest generalized position-variance ratio against the local-only world; not a same-marginal diagonal ablation.',struct('variance_inflation',infl,'names',{names}));
end
if isfield(E,'J02')
 cs=E.J02.conditions;fig=newFigure();tiledlayout(1,2,'TileSpacing','compact');data=struct('rho',{},'s',{},'empirical_std',{},'predicted_std',{},'floor_std',{});
 nexttile;hold on;
 for ir=1:numel(cfg.linear.rho)
  sel=cellfun(@(r)r.rho==cfg.linear.rho(ir),cs);a=cs(sel);x=cellfun(@(r)r.s,a);
  empirical=cellfun(@(r)r.summary.std(1),a);pred=cellfun(@(r)sqrt(r.design.Sigma(1,1)),a);floorv=sqrt(a{1}.target_floor);
  semilogx(x,pred,'-','Color',colors(ir,:),'LineWidth',1.5,'DisplayName',sprintf('rho=%.1f theory',cfg.linear.rho(ir)));
  semilogx(x,empirical,'o','Color',colors(ir,:),'HandleVisibility','off');
  semilogx(x,floorv*ones(size(x)),':','Color',colors(ir,:),'HandleVisibility','off');
  candidateCurve=struct('rho',cfg.linear.rho(ir),'s',x,'empirical_std',empirical,'predicted_std',pred,'floor_std',floorv);
  data(ir)=candidateCurve;
 end
 set(gca,'XScale','log');grid on;xlabel('Repetition information index s');ylabel('Target standard deviation');legend('Location','best');
 title('J02: conditional uncertainty floor');
 nexttile;hold on;
 emp=zeros(1,numel(cfg.linear.rho));pr=emp;fl=emp;
 for ir=1:numel(cfg.linear.rho)
  a=cs{find(cellfun(@(r)r.rho==cfg.linear.rho(ir)&&r.s==max(cfg.linear.s),cs),1)};
  emp(ir)=sqrt(a.prediction_covariance(1,1));pr(ir)=sqrt(a.design.Q_b_given_r(1,1));fl(ir)=sqrt(a.target_floor);
 end
 plot(cfg.linear.rho,pr,'-','LineWidth',1.5,'Color',colors(1,:));plot(cfg.linear.rho,emp,'o','Color',colors(2,:));plot(cfg.linear.rho,fl,':k','LineWidth',1.3);
 xlabel('Correlation between hidden and observed effects');ylabel('Hidden-effect prediction-error std');grid on;legend({'Theory at largest s','Empirical','Conditional limit'},'Location','best');
 finish('JF03_conditional_floor','Markers: empirical standard deviation across independent maps. Lines: finite-design theory. Dotted: conditional limiting floor.',struct('curves',data,'hidden_empirical',emp,'hidden_theory',pr,'hidden_floor',fl));
end
if isfield(E,'J04')
 cs=E.J04.conditions;tau=cellfun(@(r)r.tau,cs);emp=cellfun(@(r)r.summary.covariance(1,1),cs);
 pred=cellfun(@(r)r.design.Sigma(1,1),cs);res=cellfun(@(r)mean(r.residual_energy),cs);
 discrepancy=cellfun(@(r)jog.Core.relative(r.design.W,cs{1}.design.W),cs);
 fig=newFigure();tiledlayout(1,2);nexttile;plot(tau,res,'o-','LineWidth',1.4);grid on;xlabel('Added hidden-mode variance tau');ylabel('Mean residual squared norm');title('J04: paired residuals');
 nexttile;plot(tau,pred,'-','LineWidth',1.5);hold on;plot(tau,emp,'o');grid on;xlabel('Added hidden-mode variance tau');ylabel('Target variance');legend({'GLS covariance','Empirical covariance'},'Location','best');
 finish('JF05_residual_invisible_variance','Paired draws give identical residuals across tau; the estimator matrix stays fixed while absolute parameter variance increases.',struct('tau',tau,'residual_energy_mean',res,'empirical_variance',emp,'theory_variance',pred,'GLS_matrix_difference',discrepancy));
end
if isfield(E,'J05')
 cs=E.J05.conditions;dat=struct('rate',{},'s',{},'EAR',{},'theory_variance',{},'empirical_variance',{},'limit',{});
 for k=1:numel(cfg.linear.rates)
  a=cs(cellfun(@(r)r.rate==cfg.linear.rates(k),cs));dat(k)=struct('rate',cfg.linear.rates(k),...
   's',cellfun(@(r)r.s,a),'EAR',cellfun(@(r)r.EAR,a),'theory_variance',cellfun(@(r)r.design.Sigma(1,1),a),...
   'empirical_variance',cellfun(@(r)r.summary.covariance(1,1),a),'limit',a{1}.limit);
 end
 fig=newFigure();tiledlayout(1,1);nexttile;hold on;
 for k=1:numel(dat),semilogx(dat(k).s,dat(k).EAR,'-o','Color',colors(k,:),'LineWidth',1.4,'DisplayName',sprintf('a=%.2f',dat(k).rate));end
 set(gca,'XScale','log');grid on;xlabel('Repetition information index s');ylabel('Error absorption ratio');legend('Location','best');title('J05: similar limiting absorption ratios');
 finish('JF06_EAR','EAR approaches one in all three cases; its limit alone does not specify the uncertainty limit.',struct('curves',dat));
 fig=newFigure();tiledlayout(1,1);nexttile;hold on;
 for k=1:numel(dat)
  d=dat(k);loglog(d.s,d.theory_variance,'-','Color',colors(k,:),'LineWidth',1.5,'DisplayName',sprintf('a=%.2f theory',d.rate));
  loglog(d.s,d.empirical_variance,'o','Color',colors(k,:),'HandleVisibility','off');
  if d.limit>0,loglog(d.s,d.limit*ones(size(d.s)),':','Color',colors(k,:),'HandleVisibility','off');end
 end
 set(gca,'XScale','log','YScale','log');grid on;xlabel('Repetition information index s');ylabel('Target variance');legend('Location','best');title('J05: distinct weak-identification regimes');
 finish('JF07_weak_identification','Lines: exact finite-design covariance. Markers: empirical covariance. Dotted: nonzero theoretical limits.',struct('curves',dat));
end
if isfield(E,'J06')
 cs=E.J06.conditions;x=cellfun(@(r)r.spread,cs);jk=cellfun(@(r)r.known_f.J,cs);jf=cellfun(@(r)r.free_f.J,cs);
 sk=cellfun(@(r)sqrt(r.known_f.Sigma(1,1)),cs);sf=cellfun(@(r)sqrt(r.free_f.Sigma(1,1)),cs);
 fig=newFigure();tiledlayout(1,2);nexttile;loglog(x,jk,'-o','LineWidth',1.4);hold on;loglog(x,max(jf,1e-24),'--s','LineWidth',1.2);grid on;
 xlabel('Relative full depth range');ylabel('Residual common-mode information J');legend({'Known focal length','Free focal: theoretically zero'},'Location','best');
 nexttile;loglog(x,sk,'-o',x,sf,'-s','LineWidth',1.4);grid on;xlabel('Relative full depth range');ylabel('Position standard deviation (m)');legend({'Known focal length','Free focal length'},'Location','best');
 finish('JF08_focal_freedom','Directional depth scaling. The free-focal residual information is zero analytically; small numerical values are shown at a 1e-24 plotting floor.',struct('spread',x,'J_known',jk,'J_free',jf,'std_known',sk,'std_free',sf));
end
if isfield(E,'J07')
 cs=E.J07.conditions;fig=newFigure();tiledlayout(1,2);dat=struct('region_std',{},'n',{},'position_std',{},'relative_focal_std',{},'position_floor',{},'relative_focal_floor',{},'guard_rate',{},'known_f_position_std',{});
 for is=1:numel(cfg.plane.region_std)
  a=cs(cellfun(@(r)strcmp(r.spec.sweep,'points_per_plane')&&r.spec.region_std==cfg.plane.region_std(is),cs));
  x=cellfun(@(r)r.spec.n,a);p=cellfun(@(r)r.summary_all_including_fallback.std(1),a);
  f=cellfun(@(r)r.summary_all_including_fallback.std(2)/r.truth(2),a);
  lp=sqrt(a{1}.floor_covariance(1,1));lf=sqrt(a{1}.floor_covariance(2,2))/a{1}.truth(2);
  dat(is)=struct('region_std',cfg.plane.region_std(is),'n',x,'position_std',p,'relative_focal_std',f,...
   'position_floor',lp,'relative_focal_floor',lf,'guard_rate',cellfun(@(r)r.guard_rate,a),...
   'known_f_position_std',cellfun(@(r)r.summary_known_f.std(1),a));
  nexttile(1);hold on;loglog(x,p,'o-','Color',colors(is,:),'DisplayName',sprintf('region std %.2f m',cfg.plane.region_std(is)));
  loglog(x,lp*ones(size(x)),':','Color',colors(is,:),'HandleVisibility','off');
  nexttile(2);hold on;loglog(x,f,'o-','Color',colors(is,:),'DisplayName',sprintf('region std %.2f m',cfg.plane.region_std(is)));
  loglog(x,lf*ones(size(x)),':','Color',colors(is,:),'HandleVisibility','off');
 end
 nexttile(1);set(gca,'XScale','log','YScale','log');grid on;xlabel('Points per plane');ylabel('Position standard deviation (m)');legend('Location','best');
 nexttile(2);set(gca,'XScale','log','YScale','log');grid on;xlabel('Points per plane');ylabel('Relative focal standard deviation');legend('Location','best');
 finish('JF09_depth_plane_floor','Independent Gaussian sufficient-statistic trials. All guard fallback estimates are included; dotted lines are limiting GLS standard deviations.',struct('curves',dat));
 fig=newFigure();tiledlayout(2,2);dd=struct();
 for sweep=1:2
  if sweep==1,key='independent_planes';xlab='Independent planes';else,key='relative_depth_spread';xlab='Relative full depth range';end
  a=cs(cellfun(@(r)strcmp(r.spec.sweep,key),cs));x=cellfun(@(r)r.spec.x,a);
  pos=cellfun(@(r)r.summary_all_including_fallback.std(1),a);foc=cellfun(@(r)r.summary_all_including_fallback.std(2)/r.truth(2),a);
  pp=cellfun(@(r)sqrt(r.floor_covariance(1,1)),a);ff=cellfun(@(r)sqrt(r.floor_covariance(2,2))/r.truth(2),a);
  nexttile(sweep);plot(x,pp,'-','LineWidth',1.4);hold on;plot(x,pos,'o');grid on;xlabel(xlab);ylabel('Position std (m)');legend({'Limit','Empirical'},'Location','best');
  nexttile(sweep+2);plot(x,ff,'-','LineWidth',1.4);hold on;plot(x,foc,'o');grid on;xlabel(xlab);ylabel('Relative focal std');
  dd.(key)=struct('x',x,'position_std',pos,'relative_focal_std',foc,'position_floor',pp,'relative_focal_floor',ff,...
   'known_f_floor',cellfun(@(r)sqrt(r.floor_known_f),a),'inflation',cellfun(@(r)r.variance_inflation_free_f,a));
 end
 finish('JF10_independent_information','Changing the number of independent planes and depth diversity changes the limiting experiment; within-plane point count is fixed at the configured maximum.',dd);
end
if isfield(E,'J08')
 cs=E.J08.conditions;x=cellfun(@(r)r.spec.global_std,cs);p=cellfun(@(r)r.summary_all_including_fallback.std(1),cs);
 t=cellfun(@(r)sqrt(r.floor_covariance(1,1)),cs);f=cellfun(@(r)r.summary_all_including_fallback.std(2)/r.truth(2),cs);
 tf=cellfun(@(r)sqrt(r.floor_covariance(2,2))/r.truth(2),cs);
 fig=newFigure();tiledlayout(1,2);nexttile;plot(x,t,'-',x,p,'o','LineWidth',1.4);grid on;xlabel('Global datum std (m)');ylabel('Position std (m)');legend({'Limit','Empirical'},'Location','best');
 nexttile;plot(x,tf,'-',x,f,'o','LineWidth',1.4);grid on;xlabel('Global datum std (m)');ylabel('Relative focal std');legend({'Limit','Empirical'},'Location','best');
 finish('JF11_global_datum','Independent global offset adds position variance and leaves the limiting focal variance unchanged.',struct('global_std',x,'position_std',p,'position_floor',t,'relative_focal_std',f,'relative_focal_floor',tf));
end
if isfield(E,'J09') && ~isempty(E.J09.conditions)
 cs=E.J09.conditions;methods=cfg.nonlinear.methods;nm=numel(methods);ni=find(abs(cfg.nominal-.95)<1e-8,1);
 a=select(cs,'noise_scale',false);x=cellfun(@(r)r.spec.x,a);dat=nonlinearData(a,ni);
 fig=newFigure();tiledlayout(2,2,'TileSpacing','compact');
 for m=1:nm
  nexttile(1);hold on;loglog(x,dat.position_empirical_sd(:,m),'-o','Color',colors(m,:),'DisplayName',methods{m});
  loglog(x,dat.position_predicted_sd(:,m),'--','Color',colors(m,:),'HandleVisibility','off');
  nexttile(2);hold on;errorbar(x,dat.coverage(:,m),dat.coverage(:,m)-dat.coverage_lo(:,m),dat.coverage_hi(:,m)-dat.coverage(:,m),'o-','Color',colors(m,:),'DisplayName',methods{m});
  plot(x,dat.operational_coverage(:,m),':','Color',colors(m,:),'HandleVisibility','off');
  nexttile(3);hold on;plot(x,100*dat.failure(:,m),'o-','Color',colors(m,:),'DisplayName',methods{m});
  nexttile(4);hold on;plot(x,dat.maxaxis(:,m),'o-','Color',colors(m,:),'DisplayName',methods{m});
 end
 nexttile(1);set(gca,'XScale','log','YScale','log');grid on;xlabel('Noise multiplier');ylabel('Position scatter (m)');title('sqrt(trace covariance): empirical / predicted');legend('Location','best','Interpreter','none');
 nexttile(2);yline(.95,'k--','HandleVisibility','off');ylim([0 1.03]);grid on;xlabel('Noise multiplier');ylabel('95% position coverage');title('Solid: conditional + Wilson CI; dotted: all trials');
 nexttile(3);grid on;ylim([0 100]);xlabel('Noise multiplier');ylabel('Failure rate (%)');
 nexttile(4);grid on;xlabel('Noise multiplier');ylabel('Median 95% maximum semi-axis (m)');
 finish('JF12_nonlinear_calibration','Independent maps. Empirical/predicted scatter, coverage, failures and region size must be interpreted together. GN covariance; practical initialization mode is recorded in output.',struct('x',x,'data',dat,'methods',{methods},'initialization',cfg.nonlinear.initialization));
 fig=newFigure();tiledlayout(2,2,'TileSpacing','compact');geo=struct();
 for ss=1:2
  if ss==1,key='depth_spread';xlab='Relative full depth range';else,key='point_count';xlab='Control-point count';end
  a=select(cs,key,true);[x,ord]=sort(cellfun(@(r)conditionalX(r,key),a));a=a(ord);d=nonlinearData(a,ni);geo.(key)=struct('x',x,'data',d);
  for m=1:nm
   nexttile(ss);hold on;plot(x,d.coverage(:,m),'o-','Color',colors(m,:),'DisplayName',methods{m});
   nexttile(ss+2);hold on;plot(x,100*d.failure(:,m),'o-','Color',colors(m,:),'DisplayName',methods{m});
  end
  nexttile(ss);grid on;yline(.95,'k--','HandleVisibility','off');ylim([0 1.03]);xlabel(xlab);ylabel('Conditional 95% position coverage');
  if ss==1,legend('Location','best','Interpreter','none');end
  nexttile(ss+2);grid on;ylim([0 100]);xlabel(xlab);ylabel('Failure rate (%)');
 end
 finish('JF13_nonlinear_geometry','No interpolation across unexecuted geometries. Baseline points are shared with the noise-scale experiment.',geo);
 fig=newFigure();tiledlayout(1,2);scatterData=cell(1,2);
 for panel=1:2
  if panel==1,ii=find(cellfun(@(r)strcmp(r.spec.sweep,'noise_scale')&&r.spec.noise_scale==1,cs),1);name='Regional common offsets';
  else,ii=find(cellfun(@(r)strcmp(r.spec.sweep,'global_translation')&&r.spec.n==cfg.nonlinear.baseline_points,cs),1);name='Global common translation';end
  if isempty(ii),continue;end
  r=cs{ii};nexttile;hold on;vcount=zeros(1,nm);datp=cell(1,nm);
  for m=1:nm
   s=r.summary{m};valid=r.valid(m,:);vcount(m)=sum(valid);xx=s.raw_reprojection_coordinate_rmse;yy=s.position_error_norm;
   scatter(xx(valid),yy(valid),18,colors(m,:),'filled','DisplayName',methods{m});
   bad=~valid & isfinite(xx) & isfinite(yy);scatter(xx(bad),yy(bad),25,colors(m,:),'x','HandleVisibility','off');
   datp{m}=struct('reprojection',xx,'position_error',yy,'valid',valid);
  end
  grid on;xlabel('Raw coordinate-wise reprojection RMSE (px)');ylabel('Absolute position error (m)');title({name,sprintf('Valid/total: %s / %d',num2str(vcount),cfg.mc_nonlinear)});
  if panel==1,legend('Location','best','Interpreter','none');end
  scatterData{panel}=struct('condition_index',ii,'values',{datp});
 end
 finish('JF14_residual_vs_absolute_error','Markers are complete map trials. Crosses show finite-valued failed solutions. Nonfinite failures remain in output counts.',struct('panels',{scatterData}));
 a=select(cs,'global_translation',false);[x,ord]=sort(cellfun(@(r)r.spec.n,a));a=a(ord);
 diff=zeros(size(x));emp=zeros(numel(x),2);pre=emp;counts=zeros(size(x));
 il=find(strcmp(methods,'GH_LOCAL'));ifull=find(strcmp(methods,'GH_FULL'));
 for j=1:numel(a)
  r=a{j};v=r.valid(il,:)&r.valid(ifull,:);counts(j)=sum(v);
  delta=r.errors(:,:,il)-r.errors(:,:,ifull);diff(j)=jog.Core.quantile(sqrt(sum(delta(1:3,v).^2,1)),.5);
  emp(j,:)=[sqrt(trace(r.summary{il}.position.covariance)),sqrt(trace(r.summary{ifull}.position.covariance))];
  pre(j,:)=[sqrt(trace(r.oracle_reference{il}.nominal_covariance(1:3,1:3))),sqrt(trace(r.oracle_reference{ifull}.nominal_covariance(1:3,1:3)))];
 end
 fig=newFigure();tiledlayout(1,2);nexttile;semilogy(x,max(diff,eps),'o-','LineWidth',1.4);grid on;xlabel('Control-point count');ylabel('Median paired position estimate difference (m)');title('GH FULL versus GH LOCAL');
 nexttile;plot(x,emp(:,1),'o',x,emp(:,2),'s',x,pre(:,1),'--',x,pre(:,2),'-','LineWidth',1.4);grid on;
 xlabel('Control-point count');ylabel('Position scatter (m)');legend({'LOCAL empirical','FULL empirical','LOCAL nominal','FULL nominal'},'Location','best');
 finish('JF15_global_translation_check','Paired successful solutions quantify estimator invariance; covariance changes despite nearly identical point estimates. Pair counts are retained.',struct('n',x,'paired_count',counts,'median_position_difference',diff,'empirical_scatter',emp,'nominal_scatter',pre));
end
 function createdFigureHandle=newFigure()
  createdFigureHandle=figure('Visible',cfg.figure_visible,'Color','w','Units','centimeters','Position',[2 2 25 15]);
 end
 function finish(id,caption,payloadForFigure)
  sgtitle(sprintf('%s | %s | L1=%d, L2=%d, L3=%d trials/condition',strrep(id,'_',' '),upper(cfg.profile),cfg.mc_linear,cfg.mc_plane,cfg.mc_nonlinear),...
   'Interpreter','none','FontSize',10,'FontWeight','normal');
  ax=findall(fig,'Type','axes');set(ax,'FontName','Arial','FontSize',9,'LineWidth',.8,'Box','on');
  file=fullfile(destination,[id '.png']);exportgraphics(fig,file,'Resolution',cfg.fig_dpi,'BackgroundColor','white');close(fig);
  manifest(end+1)=struct('id',id,'file',file,'caption',caption,'profile',cfg.profile);
  figureData.(id)=payloadForFigure;
 end
end
function a=select(cs,key,includeBaseline)
sel=cellfun(@(r)strcmp(r.spec.sweep,key),cs);
if includeBaseline,sel=sel|cellfun(@(r)strcmp(r.spec.sweep,'noise_scale')&&r.spec.noise_scale==1,cs);end
a=cs(sel);
end
function x=conditionalX(r,key)
if strcmp(key,'depth_spread'),x=r.spec.depth_spread;else,x=r.spec.n;end
end
function d=nonlinearData(cs,ni)
n=numel(cs);m=numel(cs{1}.methods);z=nan(n,m);
d=struct('position_empirical_sd',z,'position_predicted_sd',z,'position_rmse',z,'position_bias',z,...
 'coverage',z,'coverage_lo',z,'coverage_hi',z,'operational_coverage',z,'failure',z,'maxaxis',z,'valid_counts',z);
for i=1:n
 for j=1:m
  s=cs{i}.summary{j};p=s.position;
  d.position_empirical_sd(i,j)=sqrt(trace(p.covariance));d.position_predicted_sd(i,j)=sqrt(trace(p.mean_predicted_covariance));
  d.position_rmse(i,j)=p.rmse;d.position_bias(i,j)=norm(p.bias);
  d.coverage(i,j)=p.coverage_conditional(ni);d.coverage_lo(i,j)=p.coverage_wilson(ni,1);d.coverage_hi(i,j)=p.coverage_wilson(ni,2);
  d.operational_coverage(i,j)=p.coverage_operational(ni);d.failure(i,j)=s.failure_rate;
  d.maxaxis(i,j)=s.median_maxaxis95;d.valid_counts(i,j)=s.n_valid;
 end
end
end
