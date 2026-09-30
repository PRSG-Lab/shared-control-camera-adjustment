function outputFile=run_jog(profile,outputDir)
%RUN_JOG Run all experiments, save output.mat, and export PNG figures.
%   run_jog('smoke')         % Full pathway with very few trials
%   run_jog('pilot')         % Independent pilot seeds
%   run_jog('paper')         % Proposed final counts, separate seeds
%   cfg=jog_config('paper'); cfg.mc_nonlinear=500; run_jog(cfg,'my_run')
%   run_jog('resume','my_run/output.mat')  % Same saved config/code only
%
% The only top-level MAT variable is `output`. It contains configuration,
% source snapshots, all generated data, trial results, full covariances,
% failures, summaries, and figure data. No Statistics/Optimization Toolbox.
if nargin<1,profile='pilot';end
root=fileparts(mfilename('fullpath'));addpath(root);
resuming=ischar(profile)&&strcmp(profile,'resume');
source=snapshot(root);
if resuming
 if nargin<2,error('Pass the existing output.mat path.');end
 outputFile=char(outputDir);loaded=load(outputFile,'output');output=loaded.output;
 cfg=output.config;outputDir=fileparts(outputFile);
 assert(strcmp(output.schema_version,'jog-output-1.0'),'Incompatible schema.');
 assert(isequal(source,output.meta.source_code),'Code has changed: start a new run rather than mixing implementations.');
else
 if isstruct(profile),cfg=profile;else,cfg=jog_config(profile);end
 if nargin<2||isempty(outputDir)
  outputDir=fullfile(pwd,'results',[cfg.profile '_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);
 end
 if ~exist(outputDir,'dir'),mkdir(outputDir);end
 outputFile=fullfile(outputDir,'output.mat');
 assert(~exist(outputFile,'file'),'Output exists. Use resume or a new directory.');
 assert(cfg.mc_linear<10000 && cfg.mc_plane<10000 && cfg.mc_nonlinear<10000,'Seed scheme supports <10000 trials.');
 output=struct('schema_version',cfg.schema_version,'config',cfg,'experiments',struct(),...
  'figure_data',struct(),'figure_manifest',struct([]));
 output.meta=struct('created',datestr(now,30),'completed','','status','initializing',...
  'matlab_version',version,'computer',computer,'toolboxes',ver,'source_code',source,...
  'uncertainty_scale','Absolute covariance, sigma0_squared=1; never residual-rescaled',...
  'parameter_order',{{'gamma_x','gamma_y','gamma_z','alpha_x','alpha_y','alpha_z','log_f_over_scale','kappa','pp_u','pp_v'}},...
  'parameter_units',{{'m','m','m','rad','rad','rad','dimensionless','dimensionless','px','px'}},...
  'rotation_chart','Left SO(3). Native covariance at estimate; moments use truth log-error chart.',...
  'independent_unit','A complete independent map/common-error and local-error realization',...
  'seed_scheme','master + suite*10000000 + condition*10000 + trial',...
  'geometry_seed_scheme','master + 200000000 + n*1000 + round(1000*spread); fixed within condition',...
  'known_limitations',{{'Literature novelty is not evaluated by this code.',...
  'J09 uses GN covariance and a local optimizer; global optimality is not guaranteed.',...
  'L2 uses exact Gaussian sufficient statistics and explicit guards.',...
  'Legacy E1, robust E5, estimated-covariance E7 and real data are outside the J-suite.'}});
 output.progress=struct('completed_ids',{{}},'current_id','','completed_J09_conditions',0);
end
start=tic;
try
 if ~isfield(output,'selftest')
  output.selftest=jog_selftest(cfg);checkpoint();
 end
 for i=1:numel(cfg.enabled)
  id=cfg.enabled{i};if ismember(id,output.progress.completed_ids),continue;end
  output.progress.current_id=id;output.meta.status='running';checkpoint();
  fprintf('\n%s | profile %s\n',id,cfg.profile);
  switch id
   case {'J00','J01','J02','J03','J04','J05','J06'}
    output.experiments.(id)=jog.linear_suite(id,cfg);
   case {'J07','J08'}
    output.experiments.(id)=jog.plane_suite(id,cfg);
   case 'J09'
    prev=[];if isfield(output.experiments,'J09'),prev=output.experiments.J09;end
    output.experiments.J09=jog.nonlinear_suite(cfg,@nonlinearCheckpoint,prev);
   otherwise,error('Unknown experiment %s',id);
  end
  output.progress.completed_ids{end+1}=id;checkpoint();
 end
 output.meta.status='rendering';checkpoint();
 [output.figure_manifest,output.figure_data]=jog_make_figures(output,fullfile(outputDir,'figures'));
 output.meta.status='complete';output.meta.completed=datestr(now,30);
 output.meta.last_session_seconds=toc(start);output.progress.current_id='';checkpoint();
 jog_check_output(outputFile);
 fprintf('\nSaved: %s\nUpload this output.mat for interpretation.\n',outputFile);
catch ME
 output.meta.status='failed';output.meta.last_error=struct('identifier',ME.identifier,'message',ME.message,'stack',ME.stack);
 output.meta.last_session_seconds=toc(start);checkpoint();rethrow(ME);
end
 function nonlinearCheckpoint(partial)
  output.experiments.J09=partial;output.progress.completed_J09_conditions=numel(partial.conditions);checkpoint();
 end
 function checkpoint()
  output.meta.last_checkpoint=datestr(now,30);
  tmp=[outputFile '.partial.mat'];save(tmp,'output','-v7.3');movefile(tmp,outputFile,'f');
 end
end
function s=snapshot(root)
files=[dir(fullfile(root,'*.m'));dir(fullfile(root,'+jog','*.m'))];
s=struct('name',{},'text',{});
for i=1:numel(files)
 fn=fullfile(files(i).folder,files(i).name);rel=fn(numel(root)+2:end);
 s(i).name=rel;s(i).text=fileread(fn);
end
[~,ix]=sort({s.name});s=s(ix);
end
