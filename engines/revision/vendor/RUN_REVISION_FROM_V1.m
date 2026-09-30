% Convert your existing output.mat, preserve raw data, run only new suites.
[file,folder]=uigetfile('*.mat','Select the existing v1 output.mat');
if isequal(file,0),return;end
destination=fullfile(pwd,'results',['import_' datestr(now,'yyyymmdd_HHMMSS')]);
old=jog_import_v1(fullfile(folder,file),destination);
jog_analyze_v2(old.output_file,{'D01','D02','D03','D04','J15'});
cfg=jog_config_v2('paper');
cfg.enabled={'J10','J11','J12','J13','J14','J15'};
cfg.source_runs={old.output_file};cfg.j10.geometry_source_run=old.output_file;
run_jog_v2(cfg);
