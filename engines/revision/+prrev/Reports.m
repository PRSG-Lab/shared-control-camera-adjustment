classdef Reports
methods(Static)
function post(r,folder,opt)
 rows=struct([]);diagrows=struct([]);
 for i=1:numel(r.target_conditions),rows=prrev.IO.append(rows,r.target_conditions{i}.rows);end
 for i=1:numel(r.diagnostics),diagrows=prrev.IO.append(diagrows,r.diagnostics{i}.rows);end
 writetable(struct2table(rows),fullfile(folder,'tables','target_pointwise.csv'));
 writetable(struct2table(diagrows),fullfile(folder,'tables','joint_diagnostics.csv'));
 if ~opt.make_figures,return;end
 for i=1:numel(r.target_conditions)
  s=r.target_conditions{i};nt=numel(s.targets);nm=numel(s.methods);
  for kinds={'plane','image'}
   kind=kinds{1};allrmse=[];for tt=1:nt,aa=s.targets{tt}.(kind);allrmse=[allrmse;aa.rmse(:)];end;clim=max(allrmse(isfinite(allrmse)));if isempty(clim)||clim<=0,clim=1;end;if strcmp(kind,'plane'),clim=100*clim;end;f=prrev.Reports.figure(1100,max(440,280*nm));tl=tiledlayout(f,nm,2,'TileSpacing','compact');
   labs=cellfun(@(x)sprintf('%gm / %g deg',x.design.depth,x.design.tilt_deg),s.targets,'UniformOutput',false);
   for m=1:nm
    A=[];B=[];
    for t=1:nt,a=s.targets{t}.(kind);A=[A a.rmse(:,m)];B=[B a.coverage(:,m)];end
    ax=nexttile(tl);if strcmp(kind,'plane'),A=100*A;unit='RMSE (cm)';else,unit='RMSE (pixels)';end
    imagesc(ax,A,[0 clim]);colorbar(ax);xticks(ax,1:nt);xticklabels(ax,labs);xtickangle(ax,25);ylabel(ax,'Target index');title(ax,[s.methods{m} ': ' unit],'Interpreter','none');
    ax=nexttile(tl);imagesc(ax,100*B,[0 100]);colorbar(ax);xticks(ax,1:nt);xticklabels(ax,labs);xtickangle(ax,25);ylabel(ax,'Target index');title(ax,[s.methods{m} ': pointwise coverage (%)'],'Interpreter','none');
   end
   title(tl,sprintf('%s: %d maps (partial=%d)',s.condition,s.n_total,~s.complete_source),'Interpreter','none');
   prrev.Reports.save(f,folder,sprintf('PR_T%02d_%s_targets',i,kind),opt);
  end
 end
 % Full diagnostics CSV is authoritative; figure selects principal failure cases.
 selected=[];
 for i=1:numel(diagrows)
  x=diagrows(i);
  if (contains(x.condition,'J09')&&ismember(x.method,{'GH_LOCAL','GH_FULL'}))||(contains(x.condition,'J11')&&ismember(x.method,{'FULL_correct','omit_global'})),selected(end+1)=i;end
 end
 if isempty(selected),selected=1:min(12,numel(diagrows));end
 q=diagrows(selected);labs=arrayfun(@(x)prrev.Reports.tickLabel(x),q,'UniformOutput',false);
 f=prrev.Reports.figure(1350,760);tl=tiledlayout(f,2,1);
 ax=nexttile(tl);bar(ax,100*[[q.position_coverage]' [q.native_full_coverage]']);yline(ax,95,':');ylim(ax,[0 105]);xticks(ax,1:numel(q));xticklabels(ax,labs);xtickangle(ax,25);ylabel(ax,'Coverage (%)');legend(ax,{'Position (3D)','Full camera (10D)'},'Location','eastoutside');
 ax=nexttile(tl);bar(ax,100*[[q.gaussian_reference_coverage]' [q.fixed_nominal_coverage]' [q.native_full_coverage]']);yline(ax,95,':');ylim(ax,[0 105]);xticks(ax,1:numel(q));xticklabels(ax,labs);xtickangle(ax,25);ylabel(ax,'Full coverage (%)');legend(ax,{'Gaussian fixed design','Nonlinear / fixed covariance','Nonlinear / fitted covariance'},'Location','eastoutside');
 prrev.Reports.save(f,folder,'PR_D01_joint_and_reference_coverage',opt);
 for i=1:numel(r.diagnostics)
  rr=r.diagnostics{i};if ~strcmp(rr.spec.suite,'J11')||~strcmp(rr.spec.sweep,'M4'),continue;end
  for m=1:numel(rr.methods)
   z=rr.methods{m};if ~strcmp(z.label,'omit_global'),continue;end
   g=z.saved_generalized;if isempty(fieldnames(g)),continue;end
   f=prrev.Reports.figure(950,420);tl=tiledlayout(f,1,2);ax=nexttile(tl);bar(ax,g.covariance_eigenvalues);yline(ax,1,':');ylabel(ax,'Empirical / predicted variance ratio');xlabel(ax,'Generalised mode');
   ax=nexttile(tl);imagesc(ax,g.block_coefficient_shares,[0 1]);yticks(ax,1:5);yticklabels(ax,{'Position','Rotation','Log focal','Distortion','Principal point'});xlabel(ax,'Generalised mode');colorbar(ax);title(ax,'Metric-dependent coefficient shares');
   prrev.Reports.save(f,folder,'PR_D02_omitted_global_modes',opt);
  end
 end
end
function bias(r,folder,opt)
 writetable(struct2table(r.rows),fullfile(folder,'tables','second_order_bias.csv'));if ~opt.make_figures,return;end
 for k=1:numel(r.geometries)
  g=r.geometries{k};
  if ~any(g.complete_trace)
   f=prrev.Reports.figure(1000,350);ax=axes(f);axis(ax,'off');text(ax,.5,.55,sprintf('G%d: full second-order bias is unavailable\n%d of %d directions evaluated; no complete valid trace',g.geometry_id,g.directions_used,g.directions_total),'HorizontalAlignment','center','FontSize',15);prrev.Reports.save(f,folder,sprintf('PR_B%02d_second_order_bias',g.geometry_id),opt);continue;
  end
  f=prrev.Reports.figure(1100,420);tl=tiledlayout(f,1,2);ax=nexttile(tl);
  plot(ax,g.steps,sqrt(sum((g.b2./g.metric).^2,1)),'o-');set(ax,'XScale','log');xlabel(ax,'Directional step');ylabel(ax,'Norm of b_2 / declared parameter scale');title(ax,sprintf('G%d: complete trace %d/%d steps',g.geometry_id,nnz(g.complete_trace),numel(g.steps)));grid(ax,'on');
  % Standard-error scaling avoids mixing metres, radians and pixels in comparison.
  ax=nexttile(tl);hold(ax,'on');labs={};
  for i=1:numel(g.comparison)
   c=g.comparison{i};scale=max(c.standard_error,eps);v=(c.predicted_bias(:,end)-c.empirical_bias)./scale;
   plot(ax,1:10,v,'o-');labs{end+1}=sprintf('epsilon=%g',c.epsilon);
  end
  yline(ax,1.96,':');yline(ax,-1.96,':');xlabel(ax,'Parameter index');ylabel(ax,'(Predicted bias - empirical bias) / SE');legend(ax,labs,'Location','best');title(ax,'Diagnostic residual; not a simultaneous test');grid(ax,'on');
  prrev.Reports.save(f,folder,sprintf('PR_B%02d_second_order_bias',g.geometry_id),opt);
 end
end
function additional(r,folder,opt)
 writetable(struct2table(r.rows),fullfile(folder,'tables','strong_rotation.csv'));if ~opt.make_figures,return;end
 angles=unique([r.rows.rotation_deg]);methods=unique({r.rows.method},'stable');f=prrev.Reports.figure(1100,420*numel(angles));tl=tiledlayout(f,numel(angles),2);
 for a=angles
  ax=nexttile(tl);hold(ax,'on');labs={};
  for m=1:numel(methods)
   q=r.rows([r.rows.rotation_deg]==a&strcmp({r.rows.method},methods{m}));[~,ix]=sort([q.points]);q=q(ix);
   colors=lines(numel(methods));plot(ax,[q.points],[q.position_scatter],'o-','Color',colors(m,:));plot(ax,[q.points],[q.predicted_position_scatter],'s--','Color',colors(m,:));labs=[labs {[methods{m} ' empirical'],[methods{m} ' predicted']}];
  end
  plot(ax,[q.points],[q.shared_only_position_scatter],':kd');labs{end+1}='Shared analytical';legend(ax,labs,'Interpreter','none','Location','northoutside','NumColumns',2,'FontSize',9);xticks(ax,unique([q.points]));xlabel(ax,'Control point count');ylabel(ax,'Position scatter (m)');title(ax,sprintf('Rotation STD %g deg',a));grid(ax,'on');
  ax=nexttile(tl);hold(ax,'on');
  for m=1:numel(methods)
   q=r.rows([r.rows.rotation_deg]==a&strcmp({r.rows.method},methods{m}));[~,ix]=sort([q.points]);q=q(ix);
   errorbar(ax,[q.points],100*[q.full_coverage],100*([q.full_coverage]-[q.full_low]),100*([q.full_high]-[q.full_coverage]),'o-');
  end
  yline(ax,95,':');ylim(ax,[0 105]);xticks(ax,unique([q.points]));xlabel(ax,'Control point count');ylabel(ax,'Full-camera coverage (%)');legend(ax,methods,'Interpreter','none','Location','best');grid(ax,'on');
 end
 prrev.Reports.save(f,folder,'PR_R01_stronger_rotations',opt);
end
function f=figure(w,h)
 f=figure('Visible','off','Color','w','Position',[50 50 w h]);set(f,'DefaultAxesFontSize',11,'DefaultAxesFontName','Arial','DefaultAxesTickLabelInterpreter','none');
end
function save(f,folder,name,opt)
 exportgraphics(f,fullfile(folder,'figures',[name '.png']),'Resolution',opt.dpi);exportgraphics(f,fullfile(folder,'figures',[name '.pdf']),'ContentType','vector');close(f);
end
function label=tickLabel(x)
 id=regexprep(prrev.Reports.short(x.condition),'J(\d+)c(\d+)','$1.$2');
 method=x.method;
 switch method
  case 'GH_LOCAL',method='Local';
  case {'GH_FULL','FULL_correct'},method='Full';
  case 'omit_global',method='No global';
 end
 label=[id ' ' method];
end
function key=short(x)
 key=regexp(x,'J\d+c\d+','match','once');if isempty(key),key=x;end
end
end
end
