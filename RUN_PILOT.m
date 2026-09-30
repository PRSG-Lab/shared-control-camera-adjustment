function file=RUN_PILOT(destination,max_batches)
% Reduced pilot run with its prescribed pilot seeds.
if nargin<1,destination='';end
if nargin<2,max_batches=Inf;end
opt=prpaper_config('pilot');opt.destination=destination;opt.max_batches=max_batches;
file=prpaper_run('paper',opt);
end
