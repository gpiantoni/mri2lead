function vol2lead(cfg, subj)
%VOL2LEAD create leadfield, based on volume

% load /data1/toolbox/elecloc/easycap_61_FT.mat elec 
% sens = [];
% sens.elecpos = [elec.pnt; 0 0 0; 0 0 0; 0 0 0];
% sens.chanpos = [elec.pnt; 0 0 0; 0 0 0; 0 0 0];
% sens.label = elec.label;
% sens.unit = 'mm';
%   
% cfg = [];
% cfg.template.vol = vol;
% cfg.individual.elec = sens;
% [cfg] = ft_interactiverealign(cfg)

mversion = 10;
%10 12/02/14 renamed, cleaned up
%09 12/02/05 copied from gosd/source_mri2lead, but don't do extrasmoothing
%08 12/02/03 prepare leadfield again, it does depend on n of elec, but we can remove extra electrodes
%07 12/01/12 include name of the volume
%06 11/11/30 don't prepare lead field, do it on the fly (depends on n of elec)
%05 11/11/17 very liberal threshold and smoothing, some subjects are pretty bad [5 8 12 13 15]
%04 11/11/16 use normalized images (spm or flirt)
%03 11/11/16 lower threshold for scalp 0.05
%02 11/11/11 mesh new
%01 11/11/10 created

%-----------------%
%-input
if nargin == 1
  subj = cfg.subj;
end
%-----------------%

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s (v%02.f) started at %s on %s\n', ...
  subj, mfilename,  mversion, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
ddir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.mod, cfg.cond); % data

dfile = sprintf('%s_%s_%04.f_%s_%s', cfg.proj, cfg.rec, subj, cfg.mod, cfg.cond); % data

volfile = [ddir dfile '_vol' cfg.mri2vol.method(4:end)];
leadfile = [ddir dfile '_lead' cfg.mri2vol.method(4:end)];
elecfile = [ddir dfile '_elec'];
%---------------------------%

%-------------------------------------%
%-load vol
load(volfile, 'vol')
%-------------------------------------%

%-------------------------------------%
%-electrodes and leadfield
if isfield(vol, 'mat')
  
  %-----------------%
  %-elec
  load /data1/toolbox/elecloc/easycap_61_FT.mat elec
  sens = [];
  sens.elecpos = [elec.pnt; 0 0 0; 0 0 0; 0 0 0];
  sens.chanpos = [elec.pnt; 0 0 0; 0 0 0; 0 0 0];
  sens.label = elec.label;
  sens.unit = 'mm';
  elec = sens;
  
  %-------%
  %-simple transformation (based on visual realignment)
  elec.chanpos = warp_apply(cfg.mri2lead.elecM, elec.chanpos);
  elec.elecpos = warp_apply(cfg.mri2lead.elecM, elec.elecpos);
  %-------%
  
  [vol, elec] = ft_prepare_vol_sens(vol, elec);
  save(elecfile, 'elec')
  %-----------------%
  
  %-----------------%
  %-prepare leadfield
  cfg4 = [];
  cfg4.elec = elec;
  cfg4.vol = vol;
  cfg4.grid.xgrid =  -70:10:70;
  cfg4.grid.ygrid = -110:10:80;
  cfg4.grid.zgrid =  -60:10:90;
  cfg4.inwardshift = 1; % to avoid dipoles on the border of bnd(3), which are very instable
  cfg4.grid.tight = 'no';
  cfg4.feedback = 'none';
  lead = ft_prepare_leadfield(cfg4, []);
  save(leadfile, 'lead')
  %-----------------%
  
else
  
  %-----------------%
  output = sprintf('%sft_prepare_headmodel could not create a head model!\n', output);
  %-----------------%
  
end
%-------------------------------------%

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('(p%02.f) %s (v%02.f) ended at %s on %s after %s\n\n', ...
  subj, mfilename, mversion, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%