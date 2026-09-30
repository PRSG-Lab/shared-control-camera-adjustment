function opt = prnc_config(profile)
% Postprocessing only: no optimiser, generated observations, or camera fits.
if nargin==0, profile='paper'; end
assert(ismember(profile,{'paper','smoke'}),'Use paper or smoke');
opt=struct('version','pr-native-chart-1.0','profile',profile,...
    'original_file','','max_new_batches',Inf,'make_figures',true,'dpi',600,...
    'nominal',.95,'statistic_tolerance',1e-7);
% Paper covers ALL 20 geometries in each of R1--R4. No outcome selection.
opt.population_regimes=1:4;
opt.max_geometries=Inf; opt.max_batches_per_condition=Inf;
if strcmp(profile,'smoke')
    opt.max_geometries=1; opt.max_batches_per_condition=1; opt.dpi=120;
end
end
