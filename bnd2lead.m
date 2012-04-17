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
%  .bnd2lead.mni.warp: warp or use precomputed grid (logical)
%  .bnd2lead.mni.resolution: (if warp) resolution of the grid (5,6,8,10 mm)
%  .bnd2lead.mni.nonlinear: run non-linear mni registration ('yes' or 'no')
%  
%  It only makes sense to warp to mni if your MRI are not already realigned
%  in MNI space. The MNI wrapping creates a MNI-aligned grid in subject-MRI
%  space.
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
ext = '.nii.gz';

mrifile = [mdir mfile '_' cfg.normalize ext];
bndfile = [mdir mfile '_bnd'];
volfile = [mdir mfile '_vol_' cfg.vol.type];
leadfile = [mdir mfile '_lead_' cfg.vol.type];
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
  %-create grid
  cfg4 = [];
  
  if cfg.bnd2lead.mni.warp
    
    mri = ft_read_mri(mrifile);
    cfg.grid.warpmni    = 'yes';
    cfg.grid.resolution = cfg.bnd2lead.mni.resolution;
    cfg.grid.nonlinear  = cfg.bnd2lead.mni.nonlinear;
    cfg.mri             = mri; 
    cfg.mri.coordsys    = 'spm';
    
  else
    
    cfg4.grid.xgrid =  -70:10:70;
    cfg4.grid.ygrid = -110:10:80;
    cfg4.grid.zgrid =  -60:10:90;
    
  end
  
  grid = ft_prepare_sourcemodel(cfg4);
  %-----------------%
  
  %-----------------%
  %-prepare leadfield
  cfg5 = [];
  cfg5.elec = elec;
  cfg5.vol = vol;
  cfg5.grid = grid;
  cfg5.inwardshift = cfg.bnd2lead.inwardshift; % to avoid dipoles on the border of bnd(3), which are very instable
  cfg5.grid.tight = 'no';
  cfg5.feedback = 'none';
  lead = ft_prepare_leadfield(cfg5, []);
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
