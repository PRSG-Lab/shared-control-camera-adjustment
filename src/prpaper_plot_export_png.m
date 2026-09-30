function prpaper_plot_export_png(fig,filename,dpi)
%PRPAPER_PLOT_EXPORT_PNG Export native PNG pixels with a safe raster canvas.
% Some R2026a graphics builds clip individual glyphs on large raster canvases
% (also with PRINT); vector PDF is unaffected. See the related report:
% https://www.mathworks.com/matlabcentral/answers/2184406
% Rasterise a temporary COPY with both canvas dimensions below 3900 pixels.
% Fonts retain their point sizes and pixel data are NEVER resampled. At the
% default 600 DPI the temporary canvas is at most 165.1 mm in either dimension.
% The original figure is never resized, so PDF/FIG retain paper dimensions.
if nargin<3,dpi=600;end
originalUnits=fig.Units;fig.Units='centimeters';originalSize=fig.Position(3:4);fig.Units=originalUnits;
raster=copyobj(fig,groot);raster.WindowStyle='normal';cleaner=onCleanup(@()delete_if_valid(raster));
raster.Visible='off';raster.Units='centimeters';position=raster.Position;
scale=min(1,3900/(max(position(3:4))/2.54*dpi));
axes_=findall(raster,'Type','axes');names={'XLimMode','YLimMode','ZLimMode','XTickMode','YTickMode','ZTickMode'};
for i=1:numel(axes_),for k=1:numel(names),axes_(i).(names{k})='manual';end,end
raster.Position=[position(1:2) position(3:4)*scale];drawnow;
exportgraphics(raster,filename,'Resolution',dpi,'BackgroundColor','white');
sourceUnits=fig.Units;fig.Units='centimeters';sourceSize=fig.Position(3:4);fig.Units=sourceUnits;
pixelTolerance=2.54/get(groot,'ScreenPixelsPerInch')+1e-9;
assert(max(abs(sourceSize-originalSize))<=pixelTolerance, ...
 'prpaper:FigureRestore','PNG rasterisation changed source dimensions: expected %.5g x %.5g cm; got %.5g x %.5g cm.', ...
 originalSize(1),originalSize(2),sourceSize(1),sourceSize(2));
delete_if_valid(raster);clear cleaner
end

function delete_if_valid(fig)
if isgraphics(fig),delete(fig);end
end
