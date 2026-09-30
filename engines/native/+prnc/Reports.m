classdef Reports
methods(Static)
function t=condition_table(records)
 rows={};
 for i=1:numel(records)
  r=records{i};s=r.summary;rows{i}=struct('condition',r.condition,'role',r.role,'method',r.method,...
   'regime',r.regime,'geometry_id',r.geometry_id,'n_control',r.spec.n,'depth_spread',r.spec.depth_spread,...
   'N',s.N,'N_fit_valid',s.N_fit_valid,'N_covariance_valid',s.N_covariance_valid,...
   'log_hits',s.log_hits,'direct_hits',s.direct_hits,...
   'log_conditional_pct',100*s.log_conditional,'direct_conditional_pct',100*s.direct_conditional,...
   'log_operational_pct',100*s.log_operational,'direct_operational_pct',100*s.direct_operational,...
   'delta_conditional_pp',s.delta_conditional_pp,'delta_operational_pp',s.delta_operational_pp,...
   'log_conditional_Wilson_low_pct',100*s.log_wilson(1),'log_conditional_Wilson_high_pct',100*s.log_wilson(2),...
   'direct_conditional_Wilson_low_pct',100*s.direct_wilson(1),'direct_conditional_Wilson_high_pct',100*s.direct_wilson(2),...
   'both',s.both,'log_only',s.log_only,'direct_only',s.direct_only,...
   'neither_valid',s.neither_valid,'invalid_as_uncovered',s.invalid_as_uncovered,...
   'log_NEES_reproduction_error',r.source_check.max_relative_nees_discrepancy,...
   'direct_congruence_error',s.max_congruence_discrepancy); %#ok<AGROW>
 end
 t=struct2table([rows{:}]);
end
function t=table4(records,pr)
 labels={'Reference / local','Reference / full','Narrow reference / full',...
  'Narrow noise sweep / full','Global 60 / local','Omitted global'};
 roles={'Reference','Reference','Narrow reference','Narrow noise sweep','Global 60','Omitted global'};
 methods={'GH_LOCAL','GH_FULL','GH_FULL','GH_FULL','GH_LOCAL','omit_global'};
 rows={};
 for i=1:numel(labels)
  ix=find(cellfun(@(r)strcmp(r.role,roles{i})&&strcmp(r.method,methods{i}),records));assert(isscalar(ix));
  r=records{ix};s=r.summary;
  dx=find(cellfun(@(d)strcmp(d.condition,r.condition),pr.results.diagnostics));assert(isscalar(dx),'PR diagnostic is missing');
  d=pr.results.diagnostics{dx};mx=find(cellfun(@(a)strcmp(a.label,r.method),d.methods));assert(isscalar(mx));a=d.methods{mx};
  if r.source_check.complete_condition,assert(abs(a.full_coverage-s.log_conditional)<1e-12,'PR and raw log coverage differ');end
  rows{i}=struct('Condition',labels{i},'Source_condition',r.condition,'Method',r.method,...
   'Gaussian_log_reference_pct',100*a.gaussian.coverage,...
   'Fixed_log_reference_pct',100*a.fixed_nominal_coverage,...
   'Fitted_log_native_pct',100*s.log_conditional,'Fitted_direct_native_pct',100*s.direct_conditional,...
   'Paired_change_pp',s.delta_conditional_pp,'Position_precision_ratio',a.position_precision_trace_ratio,...
   'N',s.N,'N_covariance_valid',s.N_covariance_valid,...
   'Log_low_pct',100*s.log_wilson(1),'Log_high_pct',100*s.log_wilson(2),...
   'Direct_low_pct',100*s.direct_wilson(1),'Direct_high_pct',100*s.direct_wilson(2),...
   'Both',s.both,'Log_only',s.log_only,'Direct_only',s.direct_only,'Neither_valid',s.neither_valid); %#ok<AGROW>
 end
 t=struct2table([rows{:}]);
end
function [t,pop]=population(records,o,opt)
 rows={};pop=cell(1,4);
 for regime=1:4
  ii=find(cellfun(@(r)r.regime==regime,records));g=numel(ii);assert(g>0);
  ids=cellfun(@(r)r.geometry_id,records(ii));[ids,ord]=sort(ids);ii=ii(ord);
  logp=cellfun(@(r)r.summary.log_operational,records(ii))';
  dirp=cellfun(@(r)r.summary.direct_operational,records(ii))';
  delta=dirp-logp;B=o.config.analysis.bootstrap;idx=zeros(B,g);boot=zeros(B,3);
  rs=RandStream('mrg32k3a','Seed',o.config.analysis_seed,'NormalTransform','Inversion');rs.Substream=1+regime*10000;
  for b=1:B
   draw=randi(rs,g,1,g);idx(b,:)=draw;
   boot(b,:)=[mean(logp(draw)),mean(dirp(draw)),mean(delta(draw))];
  end
  ci=zeros(2,3);
  for k=1:3,ci(:,k)=[prnc.Stats.quantile(boot(:,k),.025);prnc.Stats.quantile(boot(:,k),.975)];end
  % Preserve the original geometry-cluster resampling, not a pooled-binomial CI.
  if strcmp(opt.profile,'paper')
   old=o.diagnostics.geometry_population.conditions{regime};m=find(strcmp(old.methods,'GH_FULL'));assert(isscalar(m));
   [found,order]=ismember(ids,old.geometry_ids);assert(all(found));
   assert(max(abs(logp-old.coverage(order,m)))<1e-12,'Population source coverage differs');
   assert(max(abs(boot(:,1)-old.cluster_bootstrap_means(:,m)))<1e-12,'Original cluster bootstrap not reproduced');
   assert(max(abs(ci(:,1)-old.cluster_ci(:,m)))<1e-12,'Original Table 5 interval not reproduced');
  end
  r=records{ii(1)};total=sum(cellfun(@(x)x.summary.N,records(ii)));
  rows{regime}=struct('Regime',regime,'N_control',r.spec.n,'Depth_spread',r.spec.depth_spread,...
   'Geometries',g,'Total_trials',total,'Log_mean_pct',100*mean(logp),'Log_cluster_low_pct',100*ci(1,1),...
   'Log_cluster_high_pct',100*ci(2,1),'Log_geometry_min_pct',100*min(logp),'Log_geometry_max_pct',100*max(logp),...
   'Direct_mean_pct',100*mean(dirp),'Direct_cluster_low_pct',100*ci(1,2),'Direct_cluster_high_pct',100*ci(2,2),...
   'Direct_geometry_min_pct',100*min(dirp),'Direct_geometry_max_pct',100*max(dirp),...
   'Paired_change_pp',100*mean(delta),'Change_cluster_low_pp',100*ci(1,3),'Change_cluster_high_pp',100*ci(2,3),...
   'Geometries_increased',nnz(delta>0),'Geometries_equal',nnz(delta==0),'Geometries_decreased',nnz(delta<0)); %#ok<AGROW>
  pop{regime}=struct('regime',regime,'geometry_ids',ids,'record_indices',ii,...
   'log_operational',logp,'direct_operational',dirp,'paired_change',delta,...
   'bootstrap_indices',idx,'bootstrap_means',boot,'cluster_ci',ci,...
   'seed',o.config.analysis_seed,'substream',1+regime*10000,...
   'interpretation','Equal weight per geometry; paired whole-geometry resampling. Pointwise 95% intervals, not simultaneous.');
 end
 t=struct2table([rows{:}]);
end
function write(out,folder,opt)
 for name={'tables','figures'},if ~isfolder(fullfile(folder,name{1})),mkdir(fullfile(folder,name{1}));end,end
 prefix='';if ~out.paper_ready,prefix='SMOKE_NOT_FOR_PAPER_';end
 target=@(n)fullfile(folder,'tables',[prefix n]);
 writetable(out.condition_summary,target('condition_summary.csv'));
 writetable(out.condition_summary(out.condition_summary.regime>0,:),target('population_by_geometry.csv'));
 writetable(out.table4,target('Table4_native_chart.csv'));writetable(out.table5,target('Table5_native_chart.csv'));
 % One row per retained fit, including invalid fits as operational non-inclusions.
 pieces=cell(size(out.records));
 for i=1:numel(out.records)
  r=out.records{i};n=numel(r.trial_ids);
  pieces{i}=table(repmat(string(r.condition),n,1),repmat(string(r.method),n,1),...
   r.trial_ids',r.f_hat',repmat(r.f_true,n,1),r.fit_valid',r.covariance_valid',...
   r.W_log',r.W_direct',r.covered_log',r.covered_direct',...
   'VariableNames',{'condition','method','trial_id','f_hat','f_true','fit_valid','covariance_valid',...
   'W_log','W_direct','covered_log','covered_direct'});
 end
 writetable(vertcat(pieces{:}),target('trial_statistics.csv'));
 prnc.Reports.latex(out,target('Table4_native_chart.tex'),target('Table5_native_chart.tex'));
 v=struct('schema',out.schema_version,'profile',out.profile,'paper_ready',out.paper_ready,...
  'new_camera_fits',0,'condition_methods',numel(out.records),'validation',out.validation,...
  'table4',table2struct(out.table4),'table5',table2struct(out.table5));
 prnc.Reports.textfile(fullfile(folder,'summary.json'),jsonencode(v,PrettyPrint=true));
 lines={'Native focal-coordinate postprocessing','',...
  'These results compare two different Wald ellipsoids around the SAME saved physical estimates.',...
  'Only the focal chart changes. Full cross-covariances and the same estimate-centred left rotation chart are retained.',...
  'Table 4 uses conditional coverage. Its Gaussian/fixed reference columns remain the original LOG-focal diagnostics.',...
  'Table 5 uses operational coverage, counts failed fits as uncovered, and weights geometries equally.',...
  'Table 5 intervals resample whole geometries, using the same draws for both charts and their difference.',...
  'A chart difference is not a formal intrinsic/parameter-effects curvature decomposition.',...
  'A nonsignificant difference does not establish chart equivalence; 95% intervals are pointwise.',...
  'output.mat contains every selected error vector, native covariance, fitted camera vector, trial statistic, summary, and bootstrap draw.',...
  'No manuscript file has been edited automatically.'};
 if ~out.paper_ready,lines=[{'SMOKE ONLY: partial data, not publishable.'} lines];end
 prnc.Reports.textfile(fullfile(folder,'RESULT_NOTES.txt'),strjoin(lines,newline));
 if opt.make_figures,prnc.Reports.figures(out,folder,opt,prefix);end
end
function textfile(file,text)
 f=fopen(file,'w','n','UTF-8');assert(f>=0);cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);
end
function latex(out,file4,file5)
 % Minimal snippets, using graphicx only for width-limited tables.
 nl=newline;b=char(92);ending=[b b nl];
 h4=['% Table 4: fitted native-chart extension. All coverage values in percent.' nl ...
  b 'begin{table}[tbp]' nl b 'centering' nl b 'caption{Joint coverage by focal coordinate. Gaussian and fixed columns retain the log-focal reference; fitted columns compare native regions.}' nl ...
  b 'resizebox{' b 'textwidth}{!}{%' nl b 'begin{tabular}{lrrrrrr}' nl b 'hline' nl ...
  'Condition & Gaussian & Fixed & Fitted log & Fitted direct & Change (pp) & Precision ratio ' ending b 'hline' nl];
 t=out.table4;
 for i=1:height(t)
  h4=[h4 sprintf('%s & %.1f & %.1f & %.1f & %.1f & %+.2f & %.1f ',t.Condition{i},...
   prnc.Reports.display_round(t.Gaussian_log_reference_pct(i),1),prnc.Reports.display_round(t.Fixed_log_reference_pct(i),1),prnc.Reports.display_round(t.Fitted_log_native_pct(i),1),...
   prnc.Reports.display_round(t.Fitted_direct_native_pct(i),1),prnc.Reports.display_round(t.Paired_change_pp(i),2),prnc.Reports.display_round(t.Position_precision_ratio(i),1)) ending]; %#ok<AGROW>
 end
 h4=[h4 b 'hline' nl b 'end{tabular}}' nl b 'end{table}' nl];
 h5=['% Table 5: equal-geometry means; operational coverage; whole-geometry bootstrap.' nl ...
  b 'begin{table}[tbp]' nl b 'centering' nl b 'caption{Population coverage in the native focal charts. Mean coverages have pointwise 95' b '% geometry-cluster intervals; ranges span all sampled geometries.}' nl ...
  b 'resizebox{' b 'textwidth}{!}{%' nl b 'begin{tabular}{rrlllll}' nl b 'hline' nl ...
  '$n$ & Depth width & Log mean [CI] & Direct mean [CI] & Change [CI], pp & Log range & Direct range ' ending b 'hline' nl];
 t=out.table5;
 for i=1:height(t)
  h5=[h5 sprintf('%d & %.2f & %.1f [%.1f, %.1f] & %.1f [%.1f, %.1f] & %+.2f [%+.2f, %+.2f] & %.1f--%.1f & %.1f--%.1f ',...
   t.N_control(i),t.Depth_spread(i),prnc.Reports.display_round(t.Log_mean_pct(i),1),prnc.Reports.display_round(t.Log_cluster_low_pct(i),1),prnc.Reports.display_round(t.Log_cluster_high_pct(i),1),...
   prnc.Reports.display_round(t.Direct_mean_pct(i),1),prnc.Reports.display_round(t.Direct_cluster_low_pct(i),1),prnc.Reports.display_round(t.Direct_cluster_high_pct(i),1),...
   prnc.Reports.display_round(t.Paired_change_pp(i),2),prnc.Reports.display_round(t.Change_cluster_low_pp(i),2),prnc.Reports.display_round(t.Change_cluster_high_pp(i),2),...
   prnc.Reports.display_round(t.Log_geometry_min_pct(i),1),prnc.Reports.display_round(t.Log_geometry_max_pct(i),1),prnc.Reports.display_round(t.Direct_geometry_min_pct(i),1),prnc.Reports.display_round(t.Direct_geometry_max_pct(i),1)) ending]; %#ok<AGROW>
 end
 h5=[h5 b 'hline' nl b 'end{tabular}}' nl b 'end{table}' nl];
 if ~out.paper_ready,h4=['% SMOKE: DO NOT USE IN PAPER' nl h4];h5=['% SMOKE: DO NOT USE IN PAPER' nl h5];end
 prnc.Reports.textfile(file4,h4);prnc.Reports.textfile(file5,h5);
end
function figures(out,folder,opt,prefix)
 blue=[0 .447 .698];orange=[.835 .369 0];
 t=out.table4;n=height(t);f=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 18 11]);
 cl=onCleanup(@()close(f));ax=axes(f);hold(ax,'on');y=(1:n)';
 h1=errorbar(ax,t.Fitted_log_native_pct,y-.10,t.Fitted_log_native_pct-t.Log_low_pct,...
  t.Log_high_pct-t.Fitted_log_native_pct,'horizontal','o','Color',blue,'MarkerFaceColor',blue,'LineWidth',1);
 h2=errorbar(ax,t.Fitted_direct_native_pct,y+.10,t.Fitted_direct_native_pct-t.Direct_low_pct,...
  t.Direct_high_pct-t.Fitted_direct_native_pct,'horizontal','s','Color',orange,'MarkerFaceColor',orange,'LineWidth',1);
 xline(ax,95,':','95%','LabelVerticalAlignment','bottom');set(ax,'YTick',y,'YTickLabel',t.Condition,'YDir','reverse','FontName','Arial','FontSize',9);
 xlim(ax,[0 100]);ylim(ax,[.5 n+.5]);grid(ax,'on');xlabel(ax,'Conditional coverage (%)');
 legend(ax,[h1 h2],{'Native log focal','Native direct focal'},'Location','southoutside','Orientation','horizontal');
 prnc.Reports.export(f,folder,[prefix 'NC01_condition_coverage'],opt);clear cl
 f=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 18 14]);cl=onCleanup(@()close(f));
 lay=tiledlayout(f,2,2,'TileSpacing','compact','Padding','loose');
 for k=1:4
  p=out.population{k};ax=nexttile(lay);hold(ax,'on');plot(ax,p.geometry_ids,100*p.log_operational,'o-','Color',blue,'MarkerSize',3);
  plot(ax,p.geometry_ids,100*p.direct_operational,'s-','Color',orange,'MarkerSize',3);yline(ax,95,':');
  title(ax,sprintf('R%d: n=%d, depth width %.2f',k,out.table5.N_control(k),out.table5.Depth_spread(k)));
  xlabel(ax,'Prespecified geometry ID');ylabel(ax,'Operational coverage (%)');ylim(ax,[0 100]);xlim(ax,[.5 max(2,max(p.geometry_ids))+.5]);grid(ax,'on');
  set(ax,'FontName','Arial','FontSize',9);if k==1,legend(ax,{'Log focal','Direct focal'},'Location','southwest');end
 end
 prnc.Reports.export(f,folder,[prefix 'NC02_all_population_geometries'],opt);clear cl
 f=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 18 9]);cl=onCleanup(@()close(f));
 lay=tiledlayout(f,1,2,'TileSpacing','compact','Padding','loose');t=out.table5;x=(1:4)';
 ax=nexttile(lay);hold(ax,'on');
 h1=errorbar(ax,x-.07,t.Log_mean_pct,t.Log_mean_pct-t.Log_cluster_low_pct,t.Log_cluster_high_pct-t.Log_mean_pct,'o-','Color',blue,'LineWidth',1);
 h2=errorbar(ax,x+.07,t.Direct_mean_pct,t.Direct_mean_pct-t.Direct_cluster_low_pct,t.Direct_cluster_high_pct-t.Direct_mean_pct,'s-','Color',orange,'LineWidth',1);
 yline(ax,95,':');ylabel(ax,'Mean operational coverage (%)');ylim(ax,[0 100]);xlim(ax,[.5 4.5]);grid(ax,'on');
 set(ax,'XTick',x,'XTickLabel',{'R1','R2','R3','R4'},'FontName','Arial','FontSize',9);title(ax,'(a) Whole-geometry 95% intervals');
 legend(ax,[h1 h2],{'Log focal','Direct focal'},'Location','southwest');
 ax=nexttile(lay);hold(ax,'on');errorbar(ax,x,t.Paired_change_pp,t.Paired_change_pp-t.Change_cluster_low_pp,t.Change_cluster_high_pp-t.Paired_change_pp,'ko','LineWidth',1);
 yline(ax,0,':');ylabel(ax,'Direct minus log coverage (pp)');xlim(ax,[.5 4.5]);grid(ax,'on');title(ax,'(b) Paired change');
 set(ax,'XTick',x,'XTickLabel',{'R1','R2','R3','R4'},'FontName','Arial','FontSize',9);
 prnc.Reports.export(f,folder,[prefix 'NC03_population_summary'],opt);clear cl
end
function y=display_round(x,d)
 % Display only: protect exact decimal half-ties against floating-point sums.
 % Unrounded MAT/CSV values are retained.
 a=abs(x)*10^d;y=sign(x).*floor(a+.5+8*eps(a))/10^d;
end
function export(f,folder,name,opt)
 exportgraphics(f,fullfile(folder,'figures',[name '.png']),'Resolution',opt.dpi);
 exportgraphics(f,fullfile(folder,'figures',[name '.pdf']),'ContentType','vector');
end
end
end
