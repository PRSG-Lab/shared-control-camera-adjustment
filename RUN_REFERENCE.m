function file=RUN_REFERENCE(destination)
% Regenerate manuscript tables and figures from bundled numerical reference.
if nargin<1,destination='';end
opt=prpaper_config('paper');opt.destination=destination;
file=prpaper_run('reference',opt);
end
