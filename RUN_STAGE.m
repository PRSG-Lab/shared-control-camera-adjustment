function file=RUN_STAGE(stage,destination,opt)
% Run one stage only. Prerequisites must already exist or be explicit inputs.
% Stages: base, base_analysis, base_figures, postprocess, rotation, bias,
% reparameterization, native, collect, analyze, tables, figures.
if nargin<3,opt=prpaper_config('paper');end
opt.destination=destination;opt.stages=cellstr(stage);
if isempty(opt.source_file),mode='paper';else,mode='existing';end
file=prpaper_run(mode,opt);
end
