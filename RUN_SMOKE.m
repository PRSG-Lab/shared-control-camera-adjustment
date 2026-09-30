function file=RUN_SMOKE(destination,max_batches)
% Small end-to-end development run; never labelled manuscript reproduction.
if nargin<1,destination='';end
if nargin<2,max_batches=Inf;end
opt=prpaper_config('smoke');opt.destination=destination;opt.max_batches=max_batches;
file=prpaper_run('paper',opt);
end
