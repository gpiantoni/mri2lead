function bnd2lead(cfg, subj)
%VOL2LEAD create leadfield, based on volume
%
% CFG
%  .data: name of projects/PROJNAME/subjects/
%  .rec: name of the recordings (part of the structrual filename)
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%
%  .sens.file: file with EEG sensors. It can be sfp or mat.
%
%  .vol.type: method for head model ('bem_dipoli' 'bem_openmeeg' 'bemcp')
%  .bnd2lead.conductivity: conductivity of tissues ([0.3300 0.0042 0.3300])
%
% Part of MRI2LEAD
% see also CPMRI, MRI2BND, BND2LEAD

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

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s started at %s on %s\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
mdir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.vol.mod, cfg.vol.cond); % mridata dir
mfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.vol.mod, cfg.vol.cond); % mridata

bndfile = [mdir mfile '_bnd'];
volfile = [mdir mfile '_vol' cfg.mri2bnd.method(4:end)];
leamfile = [mdir mfile '_lead' cfg.mri2vol.method(4:end)];
elecfile = [mdir mfile '_elec'];
%---------------------------%

%-------------------------------------%
%-load vol
load(bndfile, 'bnd')

%-----------------%
%-headmodel
cfg3  = [];
cfg3.method = cfg.vol.type;
cfg3.conductivity = cfg.bnd2lead.conductivity;
vol = ft_prepare_headmodel(cfg3, bnd);
save(volfile, 'vol')
%-----------------%
%-------------------------------------%

%-------------------------------------%
%-electrodes and leadfield
if isfield(vol, 'mat')
  
  %-----------------%
  %-elec
  elec = ft_read_sens(cfg.sens.file);
  elec.label = upper(elec.label);
  elec = ft_convert_units(elec, 'mm');
  
  %-------%
  %-simple transformation (based on visual realignment)
  elec.chanpos = warp_apply(cfg.bnd2lead.elecM, elec.chanpos);
  elec.elecpos = warp_apply(cfg.bnd2lead.elecM, elec.elecpos);
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
  cfg4.inwardshift = cfg.bnd2lead.inwardshift; % to avoid dipoles on the border of bnd(3), which are very instable
  cfg4.grid.tight = 'no';
  cfg4.feedback = 'none';
  lead = ft_prepare_leadfield(cfg4, []);
  save(leamfile, 'lead')
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
outtmp = sprintf('(p%02.f) %s ended at %s on %s after %s\n\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%