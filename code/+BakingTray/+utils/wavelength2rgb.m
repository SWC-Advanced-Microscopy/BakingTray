function rgb = wavelength2rgb(lambda,demo)
	% Return an RGB color code that corresponds reasonably to a wavelength in nm
	%
	% Inputs
	% lambda - wavelength in nm
	% demo - optional. if true, plots a range wavelengths and shows where the 
	%		chosen on sits on the scale.
	%
	% Outputs
	% rgb - Structure of three color wavelength codes containing regular, light, 
	%		and dark versions of the color
	%
	% 


	if nargin<2
		demo = false;
	end



	if lambda<400
		lambda = 400;
	end

	if lambda>688
		lambda = 688;
	end



	ind = round(lambda - 399);


	c = turbo(290);
	cLight = brighten(c,0.85);
	cDark = brighten(c,-0.95);

	rgb.regular = c(ind,:);
	rgb.light = cLight(ind,:);
	rgb.dark = cDark(ind,:);




	if ~demo
		return
	end


	clf
	subplot(3,1,[1:2])
	imagesc(repmat(1:300,10,1))
	colormap(c)

	set(gca,'YTick',[],'XTick',[1,150,300],'XTickLabel',[0,150,300]+400)
	xlabel('Wavelength (nm)')

	hold on

	plot([ind,ind],ylim,'--w')

	hold off


	subplot(3,1,3)
	data = rand(1,110);
	plot(data,'-','color',rgb.dark,'LineWidth',8)
	hold on
	plot(data,'-','color',rgb.light,'LineWidth',6)
	xlim([5,105])
	set(gca,'Xtick',[],'YTick',[])


	title('Example data trace with this color')