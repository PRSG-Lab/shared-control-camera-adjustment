function prnc_replot(file)
% Rebuild figures/tables using this package's compact output.mat alone.
a=load(file,'output');assert(a.output.complete);
opt=a.output.options;opt.make_figures=true;
prnc.Reports.write(a.output,fileparts(file),opt);
end
