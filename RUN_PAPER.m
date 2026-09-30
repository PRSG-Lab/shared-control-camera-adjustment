function file=RUN_PAPER(destination,max_batches)
% Full fresh manuscript experiment. Expensive; reference mode needs no fits.
if nargin<1,destination='';end
if nargin<2,max_batches=Inf;end
opt=prpaper_config('paper');opt.destination=destination;opt.max_batches=max_batches;
file=prpaper_run('paper',opt);
end
