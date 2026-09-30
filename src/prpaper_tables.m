function tables=prpaper_tables(DATA,A,destination,opt)
%PRPAPER_TABLES Generate all five main and five SI tables from current DATA.
% Numerical CSV/MAT tables retain unrounded values. Formatted CSV and LaTeX
% apply manuscript display precision without changing the stored values.
if nargin<3,destination='';end
if nargin<4,opt=struct();end %#ok<NASGU>
tables=struct();cfg=DATA.base.config;
tables.Table1=specification(DATA);
summaries=DATA.base.summaries;ref=find_condition(summaries,'J09',3);r={};
for m=1:numel(ref.method)
 q=item(ref.method,m);p=q.blocks.position;f=q.blocks.full;
 r{end+1}=struct('Method',q.label,'Empirical_scatter_m',p.scatter,...
 'Predicted_scatter_m',p.predicted_scatter,'Position_coverage_pct',100*coverage(p),...
 'Full_camera_coverage_pct',100*coverage(f)); %#ok<AGROW>
end
tables.Table2=struct2table([r{:}]);
tables.Table3=A.native.table4;tables.Table4=A.native.table5;
tables.Table5=target_main(A.targets.aggregate);
old=legacy_results(DATA,'J01');r={};
for i=1:numel(old)
 q=item(old,i);
 if isfield(q,'design')
  L=q.L_target;d=q.design;fs=sqrt(trace(L*d.Sigma*L'));ls=sqrt(trace(L*d.N_local_inverse*L'));
  inflation=jog.Core.inflation(d,L);
 else,fs=q.full_scatter;ls=q.local_scatter;inflation=q.inflation;end
 r{end+1}=struct('Estimated_parameters',q.name,...
 'Full_position_scatter_m',fs,'Local_position_scatter_m',ls,...
 'Maximum_directional_variance_ratio',inflation); %#ok<AGROW>
end
tables.TableS1=struct2table([r{:}]);r={};
for i=1:numel(summaries)
 s=item(summaries,i);if ~strcmp(s.suite,'J14'),continue;end
 q=find_method(s.method,'GH_FULL');v=q.variance_components;names=string(v.names);
 traces=zeros(1,numel(names));
 if isfield(v,'covariance')
  for j=1:numel(names),C=item(v.covariance,j);traces(j)=trace(C(1:3,1:3));end
 else,traces=v.position_traces(:)';end
 den=sum(traces);image=sum(traces(names=='image'));xyz=sum(traces(names=='local_XYZ'));
 patch=sum(traces(names=='patch'));globalv=sum(traces(names=='global'));
 r{end+1}=struct('Scenario',s.spec.x,'Image_pct',100*image/den,'Local_XYZ_pct',100*xyz/den,...
 'Patch_pct',100*patch/den,'Global_pct',100*globalv/den,...
 'Shared_total_pct',100*(patch+globalv)/den,'Total_position_variance_m2',den); %#ok<AGROW>
end
tables.TableS2=sortrows(struct2table([r{:}]),'Scenario');tables.TableS3=A.bias.summary;
c=A.chart;N=c.N;
tables.TableS4=table(["Log focal length";"Direct focal length"],...
 [nnz(c.inside_log);nnz(c.inside_direct)],[100*c.coverage.log;100*c.coverage.direct],...
 100*[c.coverage.log_wilson(1);c.coverage.direct_wilson(1)],...
 100*[c.coverage.log_wilson(2);c.coverage.direct_wilson(2)],repmat(N,2,1),...
 'VariableNames',{'Region','Included','Coverage_pct','CI95_low_pct','CI95_high_pct','N'});
tables.TableS5=target_variance(A.targets);
tables.Experiment_crosswalk=table(compose('E%02d',(1:7)'),compose('J%02d',(9:15)'),...
 ["Reference conditions";"Noise-scale comparisons";"Covariance misspecification";...
 "Sampled control geometries";"Shared similarity errors";"Shared-error magnitudes";"Output targets"],...
 'VariableNames',{'Manuscript_experiment','MATLAB_archive_suite','Description'});
tables.All_target_pointwise=A.targets.pointwise;tables.All_target_ranges=A.targets.aggregate;
tables.All_target_variance=A.targets.variance;tables.All_native_conditions=A.native.condition_summary;
tables.All_condition_metrics=all_conditions(summaries);
[tables.Fit_accounting_by_condition,tables.Fit_accounting_totals,tables.Invalid_fits_by_method]=prpaper_accounting(tables.All_condition_metrics);
delta=[.30;.15;.05;.02];cv=delta/sqrt(12);
tables.Reduced_depth_ratios=table(delta,cv,1+1./cv.^2,'VariableNames',{'Relative_full_depth_width','Population_depth_CV','Unknown_known_focal_position_variance_ratio'});tables.Fixed_metric_decomposition=fixed_table(c);
tables.Curvature_diagnostics=curvature_table(c);tables.Paired_chart_counts=struct2table(c.paired_counts);
tables.Display_summary=display_table(c);tables.Bias_comparison_by_noise=bias_comparisons(A.bias.details);
tables.Strong_rotation=rotation_table(DATA.revision.rotation);
tables.Reduced_paired_diagnostics=A.reduced.paired;
tables.Reduced_reconstruction_checks=A.reduced.reconstruction;
tables.Reduced_bootstrap_MC=A.reduced.bootstrap;
tables.Reduced_condition_counts=struct2table(rmfield(A.reduced.summary,'definition'));
if ~isempty(destination)
 folder=fullfile(destination,'tables');if ~isfolder(folder),mkdir(folder);end
 names=fieldnames(tables);
 for i=1:numel(names)
  name=names{i};writetable(tables.(name),fullfile(folder,[name '.csv']));
  if startsWith(name,'Table')||strcmp(name,'Experiment_crosswalk')
   [headers,cells]=formatted(name,tables.(name));
   writecell([headers;cells],fullfile(folder,[name '_formatted.csv']));
   latex(fullfile(folder,[name '.tex']),headers,cells,name);
  end
 end
 save(fullfile(folder,'tables.mat'),'tables','-v7.3');
 fid=fopen(fullfile(folder,'TABLE_DEFINITIONS.md'),'w','n','UTF-8');assert(fid>=0);
 cl=onCleanup(@()fclose(fid));fprintf(fid,'%s',table_notes(cfg)); %#ok<NASGU>
end
end

function t=specification(DATA)
c=DATA.base.config;a=c.camera;nl=c.nonlinear;
q=item(DATA.revision.postprocess.target_conditions,1);dep=[];tilt=[];grid=[];
for i=1:numel(q.targets),d=item(q.targets,i);dep(end+1)=d.design.depth;tilt(end+1)=d.design.tilt_deg;grid(end+1)=d.design.grid_size;end
rr=DATA.revision.rotation.conditions;extra=[];for i=1:numel(rr),r=item(rr,i);extra(end+1)=r.spec.x;end
rows={...
 'Camera',sprintf('Image %g x %g px; image scale %g px; f=%g px; principal point %s px; kappa=%g; centre %s m; rotation vector %s rad; mean depth %g m',a.width,a.height,a.scale,a.f,vec(a.pp),a.kappa,vec(a.gamma),vec(a.rotvec),a.mean_depth);...
 'Reference control (E01)',sprintf('n=%g; relative full depth width=%g; local image STD=%g px; local XYZ STD=%g m; patch translation STD=%g m; MC maps=%g',nl.baseline_points,nl.baseline_spread,a.local_image_std,a.local_xyz_std,a.patch_std,c.mc_nonlinear);...
 'Reference variations (E01)',sprintf('Noise STD multipliers %s; depth widths %s; point counts %s; global translation STD=%g m',vec(nl.noise_scales),vec(nl.depth_spreads),vec(nl.point_counts),a.global_std);...
 'Noise and geometry (E02, E04)',sprintf('Regimes [n depth]=%s; STD multipliers %s; population %g geometries per regime and %g maps per geometry',mat2str(c.j10.regimes),vec(c.j10.scales),c.j12.geometries,c.j12.maps);...
 'Misspecification (E03)',sprintf('Shared variance multipliers %s; structural models correct/no-global/no-patch/local-only; patch/global STDs %g/%g m',vec(c.j11.alpha),a.patch_std,a.global_std);...
 'Similarity and sources (E05, E06)',sprintf('Rotation STDs %s deg; extension %s deg; translation STD=%g m; scale STD=%g ppm; [local XYZ patch global] scenarios=%s m',vec(c.j13.rotation_deg),vec(unique(extra)),c.j13.translation_std,c.j13.scale_std*1e6,mat2str(c.j14.scenarios));...
 'Targets and extension (E07)',sprintf('%g x %g grid; plane depths %s m; tilts %s deg; exact object points also projected to image; camera-only uncertainty',grid(1),grid(1),vec(unique(dep)),vec(unique(tilt)))};
t=cell2table(rows,'VariableNames',{'Setting','Specification'});
end

function t=target_main(a)
rows={};order={'J09c003','J09c005','J09c012'};names={'Reference','Narrow','Global 60'};
for i=1:numel(order)
 full=a(endsWith(string(a.condition),order{i})&strcmp(a.kind,'plane')&strcmp(a.method,'GH_FULL'),:);
 for j=1:height(full)
  f=full(j,:);ix=strcmp(a.condition,f.condition)&strcmp(a.target,f.target)&strcmp(a.kind,'plane')&strcmp(a.method,'GH_LOCAL');
  l=a(ix,:);assert(height(l)==1);
  rows{end+1}=struct('Condition',names{i},'Plane_depth_m',f.depth_m,'Plane_tilt_deg',f.tilt_deg,...
   'GH_full_RMSE_min_m',f.rmse_min,'GH_full_RMSE_max_m',f.rmse_max,...
   'GH_full_coverage_min_pct',100*f.coverage_min,'GH_full_coverage_max_pct',100*f.coverage_max,...
   'GH_local_coverage_min_pct',100*l.coverage_min,'GH_local_coverage_max_pct',100*l.coverage_max); %#ok<AGROW>
 end
end
t=struct2table([rows{:}]);
end

function t=target_variance(targets)
v=targets.variance;p=targets.pointwise;
ix=endsWith(string(v.condition),'J09c012')&strcmp(v.kind,'plane')&strcmp(v.method,'GH_LOCAL')&v.tilt_deg==0;
v=sortrows(v(ix,:),'depth_m');r={};
for i=1:height(v)
 row=v(i,:);sel=strcmp(p.condition,row.condition)&strcmp(p.target,row.target)&strcmp(p.kind,'plane');
 l=sortrows(p(sel&strcmp(p.method,'GH_LOCAL'),:),'point');f=sortrows(p(sel&strcmp(p.method,'GH_FULL'),:),'point');
 assert(isequal(l.point,f.point),'Paired target grid mismatch');
 r{end+1}=struct('Plane_depth_m',row.depth_m,'GH_local_reported_trace_m2',row.median_predicted_trace,...
  'Full_minus_local_trace_m2',median(f.predicted_trace-l.predicted_trace,'omitnan'),...
  'Empirical_local_trace_ratio',row.median_empirical_predicted_trace_ratio,...
  'GH_full_reported_trace_m2',median(f.predicted_trace,'omitnan'),...
  'GH_local_empirical_trace_m2',row.median_empirical_trace,'Points',height(l)); %#ok<AGROW>
end
t=struct2table([r{:}]);
end

function t=all_conditions(summaries)
r={};
for i=1:numel(summaries)
 s=item(summaries,i);
 for m=1:numel(s.method)
  q=item(s.method,m);blocks=fieldnames(q.blocks);
  for j=1:numel(blocks)
   b=q.blocks.(blocks{j});vf=q.variance_factor;
   r{end+1}=struct('Suite',s.suite,'Experiment',experiment(s.suite),'Condition_ID',s.spec.condition_id,...
    'Method',q.label,'Block',blocks{j},'N',q.n_total,'Valid',q.n_valid,...
    'Empirical_scatter',b.scatter,'Predicted_scatter',b.predicted_scatter,'RMSE',b.rmse,...
    'Coverage_conditional_pct',100*coverage(b),'Coverage_operational_pct',100*coverage_operational(b),...
    'Mean_NEES',b.nees_mean,'Variance_factor_mean',vf.mean,'Variance_factor_rejection_pct',100*vf.rejection_rate); %#ok<AGROW>
  end
 end
end
t=struct2table([r{:}]);
end
function t=fixed_table(c)
f=c.fixed_metrics;names={'log','direct'};r={};
for i=1:2
 q=f.(names{i});r{i}=struct('Chart',names{i},'N',c.N,'Mean_NEES',q.mean_nees,...
 'Bias_NEES',q.bias_nees,'Centred_scatter_NEES',q.centered_scatter_nees,...
 'Covariance_trace_check',q.covariance_trace_nees,'Linear_centred_expectation',f.linear_centred_expectation,...
 'Delta_variance_term',f.delta_variance_term,'Twice_cross_term',f.twice_cross_term);
end
t=struct2table([r{:}]);
end
function t=curvature_table(c)
names={'log','direct'};r={};
for i=1:2
 q=c.regressions.(names{i});ci=q.quadratic_coefficient_bootstrap_CI95;
 r{i}=struct('Chart',names{i},'Quadratic_intercept',q.quadratic_coefficients(1),...
 'Quadratic_linear_coefficient',q.quadratic_coefficients(2),'Quadratic_coefficient',q.quadratic_coefficients(3),...
 'Quadratic_coefficient_CI95_low',ci(1),'Quadratic_coefficient_CI95_high',ci(2),...
 'Linear_RMSE',q.linear_rmse,'Quadratic_RMSE',q.quadratic_rmse,'Linear_R2',q.linear_r2,...
 'Quadratic_R2',q.quadratic_r2,'Correlation',q.correlation);
end
t=struct2table([r{:}]);
end
function t=display_table(c)
d=c.display;t=table(d.within_2D_log,d.within_2D_direct,d.failed_10D_inside_2D_log,...
 numel(d.clip_trials_log),numel(d.clip_trials_direct),d.median_absolute_optical_error_m,d.median_absolute_focal_error_px,...
 'VariableNames',{'Within_2D_log','Within_2D_direct','Failed_10D_inside_2D_log','Clipped_log','Clipped_direct','Median_abs_optical_error_m','Median_abs_focal_error_px'});
end
function t=bias_comparisons(details)
r={};for i=1:numel(details)
 q=item(details,i);
 for j=1:numel(q.predicted_bias)
  r{end+1}=struct('Geometry',q.geometry,'Epsilon',q.epsilon,'Parameter',j,...
   'Predicted_bias',q.predicted_bias(j),'Empirical_bias',q.empirical_bias(j),...
   'Component_SE_residual',q.component_SE_residual(j)); %#ok<AGROW>
 end
end
t=struct2table([r{:}]);
end
function t=rotation_table(rot)
r={};for i=1:numel(rot.conditions)
 s=item(rot.conditions,i);
 for j=1:numel(s.method)
  q=item(s.method,j);p=q.position;f=q.full;
  r{end+1}=struct('Rotation_STD_deg',s.spec.x,'N_control',s.spec.n,'Method',char(string(item(s.methods,j))),...
   'Position_scatter_m',sqrt(trace(p.covariance)),'Predicted_position_scatter_m',sqrt(trace(p.mean_predicted_covariance)),...
   'Position_coverage_pct',100*coverage(p),'Full_coverage_pct',100*coverage(f),...
   'Paired_position_RMS_difference_m',norm(s.paired_estimator_difference.rms_by_parameter(1:3))); %#ok<AGROW>
 end
end
t=struct2table([r{:}]);
end

function [headers,cells]=formatted(name,t)
headers=t.Properties.VariableNames;cells=table2cell(t);
switch name
 case 'Table2'
  headers={'Method','Empirical scatter (m)','Predicted scatter (m)','Position coverage (%)','Full-camera coverage (%)'};
  cells(:,2:3)=numfmt(t{:,2:3},5);cells(:,4:5)=numfmt(t{:,4:5},1);
 case 'Table3'
  headers={'Condition / method','Gaussian (%)','Fixed (%)','Fitted log (%)','Fitted direct (%)','Precision ratio'};
  cells=[cellstr(string(t.Condition)) numfmt(t{:,{'Gaussian_log_reference_pct','Fixed_log_reference_pct','Fitted_log_native_pct','Fitted_direct_native_pct','Position_precision_ratio'}},1)];
 case 'Table4'
  headers={'n','Depth width','Log mean [95% interval] (%)','Direct mean [95% interval] (%)','Log range (%)','Direct range (%)'};
  cells=cell(height(t),6);
  for i=1:height(t)
   cells(i,:)={t.N_control(i),fmt(t.Depth_spread(i),2),interval(t.Log_mean_pct(i),t.Log_cluster_low_pct(i),t.Log_cluster_high_pct(i),2),...
    interval(t.Direct_mean_pct(i),t.Direct_cluster_low_pct(i),t.Direct_cluster_high_pct(i),2),...
    range(t.Log_geometry_min_pct(i),t.Log_geometry_max_pct(i),1),range(t.Direct_geometry_min_pct(i),t.Direct_geometry_max_pct(i),1)};
  end
 case 'Table5'
  headers={'Condition / plane','GH-full RMSE (m)','GH-full coverage (%)','GH-local coverage (%)'};cells=cell(height(t),4);
  for i=1:height(t)
   plane=sprintf('%g m',t.Plane_depth_m(i));if t.Plane_tilt_deg(i)~=0,plane=sprintf('%g deg',t.Plane_tilt_deg(i));end
   cells(i,:)={sprintf('%s / %s',string(t.Condition(i)),plane),range(t.GH_full_RMSE_min_m(i),t.GH_full_RMSE_max_m(i),3),...
    range(t.GH_full_coverage_min_pct(i),t.GH_full_coverage_max_pct(i),1),range(t.GH_local_coverage_min_pct(i),t.GH_local_coverage_max_pct(i),1)};
  end
 case 'TableS1'
  headers={'Estimated parameters','Full position scatter (m)','Local-only position scatter (m)','Maximum directional variance ratio'};
  cells(:,2:3)=numfmt(t{:,2:3},5);cells(:,4)=numfmt(t{:,4},3);
 case 'TableS2'
  headers={'Scenario','Image (%)','Local XYZ (%)','Patch (%)','Global (%)','Shared total (%)'};
  cells=[cellstr(compose('S%g',t.Scenario)) numfmt(t{:,2:6},2)];
 case 'TableS3'
  headers={'Geometry','Directions','Finest relative change','Predicted squared norm','Empirical squared norm','Max SE ratio'};
  cells=[cellstr(compose('G%g',t.Geometry)) num2cell(t.Directions) cellstr(compose('%.2e',t.Finest_relative_change)) ...
   numfmt([t.Predicted_squared_norm t.Empirical_squared_norm],3) numfmt(t.Max_component_SE_residual,2)];
 case 'TableS4'
  headers={'Region','Included','Coverage (%)','95% interval (%)'};cells=cell(height(t),4);
  for i=1:height(t),cells(i,:)={t.Region(i),t.Included(i),fmt(t.Coverage_pct(i),1),range(t.CI95_low_pct(i),t.CI95_high_pct(i),1)};end
 case 'TableS5'
  headers={'Plane depth (m)','GH-local reported trace (m2)','Full minus local trace (m2)','Empirical/local trace ratio'};
  cells=[num2cell(t.Plane_depth_m) numfmt([t.GH_local_reported_trace_m2 t.Full_minus_local_trace_m2],8) numfmt(t.Empirical_local_trace_ratio,4)];
end
end
function latex(path,headers,cells,name)
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cl=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%% %s generated from current numerical inputs; see matching CSV for full precision.\n',name);
fprintf(fid,'\\begin{tabular}{%s}\n\\hline\n',repmat('l',1,numel(headers)));
ending=[char(32) char(92) char(92) newline];
fprintf(fid,'%s%s\\hline\n',strjoin(cellfun(@escape,headers,'UniformOutput',false),' & '),ending);
for i=1:size(cells,1)
 line=cellfun(@(x)escape(char(string(x))),cells(i,:),'UniformOutput',false);
 fprintf(fid,'%s%s',strjoin(line,' & '),ending);
end
fprintf(fid,'\\hline\n\\end{tabular}\n');
end
function s=escape(s)
s=strrep(s,'\','\textbackslash{}');s=strrep(s,'_','\_');s=strrep(s,'%','\%');s=strrep(s,'&','\&');
end
function t=table_notes(cfg)
t=sprintf(['# Generated table definitions\n\n'...
 'Table numbers match manuscript v0.19: Main Tables 1–5 and Supporting Information Tables S1–S5.\n\n'...
 '- Table 1: actual configuration; E means Experiment; archive J identifiers remain stable.\n'...
 '- Table 2: fixed reference control geometry; empirical scatter is sqrt(trace(sample covariance)); predicted scatter is sqrt(trace(mean reported covariance)).\n'...
 '- Table 3: trial-specific native Wald coverage; conditional on covariance-valid fits. Gaussian and fixed columns retain the log-focal metric.\n'...
 '- Table 4: equal-geometry operational coverage; failures are misses; paired whole-geometry bootstrap, seed %.0f, %d replicates.\n'...
 '- Table 5: minimum–maximum over target grid points, camera-only uncertainty and exact planes/checkpoints.\n'...
 '- Table S1: fixed-geometry analytical covariance under nested parameter sets, legacy verification J01.\n'...
 '- Table S2: position covariance trace shares under the same GH-full estimator, not efficiency differences between estimators.\n'...
 '- Table S3: squared bias norms in fixed reference covariance; finest finite-difference step; maximum descriptive component SE residual over paired noise levels.\n'...
 '- Table S4: paired narrow-noise native coverage with Wilson intervals.\n'...
 '- Table S5: Global 60 perpendicular planes; median over target points of reported trace, pointwise full-minus-local trace, and empirical/local trace ratio. Ratios are medians of ratios, not ratios of medians.\n'...
 '- All numerical CSV values are unrounded. Formatted CSV/LaTeX use manuscript precision and decimal half-up rounding.\n'...
 '- Curvature bootstrap uses MATLAB mt19937ar, not the historical NumPy descriptive bootstrap generator.\n'...
 '- Plot reference outlines never classify individual trials; full per-trial covariance determines native coverage.\n'],cfg.analysis_seed,cfg.analysis.bootstrap);
end
function a=find_condition(summaries,suite,id)
a=[];for i=1:numel(summaries),q=item(summaries,i);if strcmp(q.suite,suite)&&q.spec.condition_id==id,a=q;return;end,end
assert(~isempty(a),'Missing %s condition %d',suite,id);
end
function a=find_method(methods,label)
a=[];for i=1:numel(methods),q=item(methods,i);if strcmp(q.label,label),a=q;return;end,end
assert(~isempty(a),'Missing method %s',label);
end
function a=legacy_results(DATA,key)
if isfield(DATA,'legacy'),L=DATA.legacy;elseif isfield(DATA.base,'legacy'),L=DATA.base.legacy;elseif isfield(DATA.base,'experiments'),L=DATA.base.experiments;else,error('Missing legacy analytical results');end
if isfield(L,'experiments'),L=L.experiments;end
a=L.(key);if isstruct(a)&&isscalar(a)&&isfield(a,'results'),a=a.results;end
if isstruct(a)&&isscalar(a)&&isfield(a,'conditions'),a=a.conditions;end
end
function q=coverage(b)
if isfield(b,'coverage_conditional'),ix=find(abs(b.nominal-.95)<1e-12,1);q=b.coverage_conditional(ix);else,q=b.coverage95;end
end
function q=coverage_operational(b)
if isfield(b,'coverage_operational'),ix=find(abs(b.nominal-.95)<1e-12,1);q=b.coverage_operational(ix);else,q=b.operational95;end
end
function a=item(v,i)
if iscell(v),a=v{i};else,a=v(i);end
end
function s=experiment(j)
v=str2double(j(2:end));if v>=9&&v<=15,s=sprintf('E%02d',v-8);else,s='verification';end
end
function s=vec(v)
s=mat2str(v(:)',8);
end
function c=numfmt(v,n)
c=arrayfun(@(x)fmt(x,n),v,'UniformOutput',false);
end
function s=fmt(x,n)
y=sign(x)*floor(abs(x)*10^n+.5+1e-9)/10^n;s=sprintf('%.*f',n,y);
end
function s=range(a,b,n)
s=[fmt(a,n) '–' fmt(b,n)];
end
function s=interval(m,a,b,n)
s=[fmt(m,n) ' [' fmt(a,n) '–' fmt(b,n) ']'];
end
